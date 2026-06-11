import 'package:flutter/material.dart';
import 'package:gp_app/features/parking/domain/entities/parking_session.dart';
import 'package:gp_app/features/parking/domain/entities/zone.dart';
import 'package:gp_app/features/parking/domain/entities/zone_config.dart';
import 'package:gp_app/features/parking/domain/entities/garage_settings.dart';
import 'package:gp_app/features/parking/domain/repositories/parking_repository.dart';

class ParkingState {
  final List<ParkingSession> activeSessions;
  final List<ParkingSession> completedSessions;
  final List<Zone> zones;
  final GarageSettings garageSettings;
  final bool isLoading;
  final String? error;

  const ParkingState({
    this.activeSessions = const [],
    this.completedSessions = const [],
    this.zones = const [],
    this.garageSettings = const GarageSettings(),
    this.isLoading = false,
    this.error,
  });

  ParkingState copyWith({
    List<ParkingSession>? activeSessions,
    List<ParkingSession>? completedSessions,
    List<Zone>? zones,
    GarageSettings? garageSettings,
    bool? isLoading,
    String? error,
  }) {
    return ParkingState(
      activeSessions: activeSessions ?? this.activeSessions,
      completedSessions: completedSessions ?? this.completedSessions,
      zones: zones ?? this.zones,
      garageSettings: garageSettings ?? this.garageSettings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ParkingProvider extends ChangeNotifier {
  final ParkingRepository _repository;
  ParkingState _state = const ParkingState();

  ParkingProvider(this._repository);

  ParkingState get state => _state;

  Future<void> loadActiveSessions() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    try {
      final sessions = await _repository.getActiveSessions();
      _state = _state.copyWith(activeSessions: sessions, isLoading: false, error: null);
    } catch (e) {
      debugPrint('ParkingProvider.loadActiveSessions failed: $e');
      _state = _state.copyWith(isLoading: false, error: e.toString());
    }
    notifyListeners();
  }

  Future<void> loadCompletedSessions() async {
    try {
      final sessions = await _repository.getCompletedSessions();
      _state = _state.copyWith(completedSessions: sessions);
      notifyListeners();
    } catch (e) {
      debugPrint('ParkingProvider.loadCompletedSessions failed: $e');
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  Future<void> loadZones() async {
    try {
      final zones = await _repository.getZones();
      _state = _state.copyWith(zones: zones);
      notifyListeners();
    } catch (e) {
      debugPrint('ParkingProvider.loadZones failed: $e');
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  Future<void> loadGarageSettings() async {
    try {
      final settings = await _repository.getGarageSettings();
      _state = _state.copyWith(garageSettings: settings);
      notifyListeners();
    } catch (e) {
      debugPrint('ParkingProvider.loadGarageSettings failed: $e');
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  Future<void> loadInitialData() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.getActiveSessions(),
        _repository.getZones(),
        _repository.getGarageSettings(),
        _repository.getCompletedSessions(),
      ]);
      _state = _state.copyWith(
        activeSessions: results[0] as List<ParkingSession>,
        zones: results[1] as List<Zone>,
        garageSettings: results[2] as GarageSettings,
        completedSessions: results[3] as List<ParkingSession>,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      debugPrint('ParkingProvider.loadInitialData failed: $e');
      _state = _state.copyWith(isLoading: false, error: e.toString());
    }
    notifyListeners();
  }

  Future<CheckInResult> checkIn(String licensePlate, String zoneId) async {
    final result = await _repository.checkIn(licensePlate, zoneId);
    if (result == CheckInResult.success) {
      await loadActiveSessions();
    }
    return result;
  }

  Future<ParkingSession?> checkOut(int sessionId) async {
    final completed = await _repository.checkOut(sessionId);
    if (completed != null) {
      await loadActiveSessions();
      await loadCompletedSessions(); // keep History in sync after checkout
    }
    return completed;
  }

  Future<void> updateGarageSettings(GarageSettings settings) async {
    await _repository.updateGarageSettings(settings);
    _state = _state.copyWith(garageSettings: settings);
    notifyListeners();
  }

  // ── Garage layout ─────────────────────────────────────────────────────────

  Future<bool> isGarageConfigured() => _repository.isGarageConfigured();

  Future<List<ZoneConfig>> getGarageConfig() => _repository.getGarageConfig();

  /// Saves a new layout. On success, refreshes zones + settings so the rest of
  /// the app reflects the change immediately.
  Future<GarageConfigResult> saveGarageConfig(List<ZoneConfig> zones) async {
    final result = await _repository.applyGarageConfig(zones);
    if (result.status == GarageConfigStatus.success) {
      await loadZones();
      await loadGarageSettings();
    }
    return result;
  }
}

