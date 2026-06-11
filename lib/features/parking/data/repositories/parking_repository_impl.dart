import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:gp_app/data/dataproviders/local_db_helper.dart';
import 'package:gp_app/data/models/transaction_model.dart';
import 'package:gp_app/features/parking/domain/entities/garage_settings.dart';
import 'package:gp_app/features/parking/domain/entities/parking_session.dart';
import 'package:gp_app/features/parking/domain/entities/zone.dart';
import 'package:gp_app/features/parking/domain/entities/zone_config.dart';
import 'package:gp_app/features/parking/domain/repositories/parking_repository.dart';

class ParkingRepositoryImpl implements ParkingRepository {
  final _db = LocalDbHelper.instance;
  final _uuid = const Uuid();

  // Maps stable int session ID → plate number so CheckoutScreen can call checkOut(id).
  final Map<int, String> _idToPlate = {};

  GarageSettings _settings = const GarageSettings();

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Stable int ID for a plate: same plate always maps to same number.
  int _plateId(String plate) => plate.hashCode.abs();

  /// Convert our Transaction to their ParkingSession. [zoneName] is the human
  /// label for the spot's zone (resolved by the caller); falls back to the raw
  /// spot id if unknown (e.g. the zone was later deleted).
  ParkingSession _toSession(Transaction t, {String? zoneName}) {
    final id = _plateId(t.plateNumber);
    _idToPlate[id] = t.plateNumber;
    // Actual parked duration in hours (only meaningful once checked out).
    // Derived from the timestamps — there's no duration column in the DB.
    final durationHours = t.checkOutTime != null
        ? t.checkOutTime!.difference(t.checkInTime).inMinutes / 60.0
        : 0.0;
    return ParkingSession(
      id: id,
      licensePlate: t.plateNumber,
      normalizedPlate: t.plateNumber,
      zoneId: zoneName ?? t.spotAssigned ?? '—',
      spotId: t.spotAssigned,
      entryTime: t.checkInTime,
      status: t.status == 'Active' ? 'active' : 'completed',
      syncStatus: 'PENDING',
      createdAt: t.checkInTime,
      exitTime: t.checkOutTime,
      durationHours: durationHours,
      totalFee: t.totalFee ?? 0.0,
    );
  }

  // ── ParkingRepository ────────────────────────────────────────────────────

  @override
  Future<List<ParkingSession>> getActiveSessions() async {
    final txns = await _db.getActiveTransactions();
    final names = await _db.spotZoneNames();
    _idToPlate.clear();
    return txns
        .map((t) => _toSession(t, zoneName: names[t.spotAssigned]))
        .toList();
  }

  @override
  Future<List<ParkingSession>> getCompletedSessions() async {
    final txns = await _db.getCompletedTransactions();
    final names = await _db.spotZoneNames();
    return txns
        .map((t) => _toSession(t, zoneName: names[t.spotAssigned]))
        .toList();
  }

  @override
  Future<ParkingSession?> getSessionById(int id) async {
    final plate = _idToPlate[id];
    if (plate == null) return null;
    final t = await _db.getActiveTransactionByPlate(plate);
    return t == null ? null : _toSession(t);
  }

  @override
  Future<ParkingSession?> getActiveSessionByPlate(String plate) async {
    final t = await _db.getActiveTransactionByPlate(plate);
    return t == null ? null : _toSession(t);
  }

  @override
  Future<CheckInResult> checkIn(String licensePlate, String zoneId) async {
    try {
      // Duplicate guard — plate already parked.
      final existing = await _db.getActiveTransactionByPlate(licensePlate);
      if (existing != null) return CheckInResult.duplicate;

      // Assign a free spot within the chosen zone (zone selection now matters).
      final spot = await _db.getFirstAvailableSpotInZone(zoneId);
      if (spot == null) return CheckInResult.garageFull;

      final txn = Transaction(
        id: _uuid.v4(),
        plateNumber: licensePlate,
        checkInTime: DateTime.now(),
        spotAssigned: spot.spotId,
        isSynced: false,
        status: 'Active',
      );

      await _db.insertTransaction(txn);
      await _db.updateSpotStatus(spot.spotId, true);
      return CheckInResult.success;
    } catch (e) {
      debugPrint('checkIn failed: $e');
      return CheckInResult.error;
    }
  }

  @override
  Future<ParkingSession?> checkOut(int sessionId) async {
    final plate = _idToPlate[sessionId];
    if (plate == null) return null;

    final txn = await _db.getActiveTransactionByPlate(plate);
    if (txn == null) return null;

    if (txn.spotAssigned == null) return null;

    final now = DateTime.now();
    final hours = now.difference(txn.checkInTime).inMinutes / 60.0;
    final billable = hours < 1.0 ? 1.0 : hours;
    final fee = billable * _settings.hourlyRateEgp;

    await _db.completeTransaction(
      transactionId: txn.id,
      checkOutTime: now,
      totalFee: fee,
    );
    await _db.updateSpotStatus(txn.spotAssigned!, false);

    // Return the completed session so the UI can show a checkout ticket with
    // the actual stored exit time, duration, and fee (no logic duplicated).
    final names = await _db.spotZoneNames();
    return ParkingSession(
      id: sessionId,
      licensePlate: txn.plateNumber,
      normalizedPlate: txn.plateNumber,
      zoneId: names[txn.spotAssigned] ?? txn.spotAssigned ?? '—',
      spotId: txn.spotAssigned,
      entryTime: txn.checkInTime,
      exitTime: now,
      durationHours: now.difference(txn.checkInTime).inMinutes / 60.0,
      totalFee: fee,
      status: 'completed',
      createdAt: txn.checkInTime,
    );
  }

  @override
  Future<List<Zone>> getZones() async {
    final stats = await _db.getZoneStats();
    return stats
        .map((s) => Zone(
              id: s.zoneId,
              name: s.name,
              totalCapacity: s.capacity,
              occupiedSpots: s.occupied,
            ))
        .toList();
  }

  @override
  Future<Zone?> getZoneById(String id) async {
    final zones = await getZones();
    for (final z in zones) {
      if (z.id == id) return z;
    }
    return null;
  }

  @override
  Future<GarageSettings> getGarageSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rate = prefs.getDouble('hourly_rate') ?? 10.0;
    final capacity = await _db.totalCapacity();
    return _settings =
        _settings.copyWith(hourlyRateEgp: rate, totalCapacity: capacity);
  }

  @override
  Future<void> updateGarageSettings(GarageSettings settings) async {
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hourly_rate', settings.hourlyRateEgp);
  }

  // ── Garage layout ─────────────────────────────────────────────────────────

  @override
  Future<bool> isGarageConfigured() => _db.isGarageConfigured();

  @override
  Future<List<ZoneConfig>> getGarageConfig() async {
    final rows = await _db.getGarageConfig();
    return rows
        .map((r) =>
            ZoneConfig(zoneId: r.zoneId, name: r.name, capacity: r.capacity))
        .toList();
  }

  @override
  Future<GarageConfigResult> applyGarageConfig(List<ZoneConfig> zones) async {
    try {
      // Keep only meaningful zones (named, ≥1 slot).
      final valid = zones
          .where((z) => z.name.trim().isNotEmpty && z.capacity > 0)
          .toList();
      if (valid.isEmpty) {
        return const GarageConfigResult(GarageConfigStatus.needAtLeastOneZone);
      }

      // Block & warn: a kept zone can't shrink below its occupancy, and a zone
      // being removed can't still have cars parked.
      final stats = await _db.getZoneStats();
      final keptIds =
          valid.where((z) => z.zoneId != null).map((z) => z.zoneId!).toSet();
      for (final s in stats) {
        if (!keptIds.contains(s.zoneId)) {
          if (s.occupied > 0) {
            return GarageConfigResult(GarageConfigStatus.zoneHasParkedCars,
                blockedZoneName: s.name);
          }
        } else {
          final desired = valid.firstWhere((z) => z.zoneId == s.zoneId);
          if (desired.capacity < s.occupied) {
            return GarageConfigResult(GarageConfigStatus.zoneHasParkedCars,
                blockedZoneName: s.name);
          }
        }
      }

      await _db.applyGarageConfig(
        valid
            .map<ZoneConfigRow>((z) =>
                (zoneId: z.zoneId, name: z.name.trim(), capacity: z.capacity))
            .toList(),
      );
      return const GarageConfigResult(GarageConfigStatus.success);
    } catch (e) {
      debugPrint('applyGarageConfig failed: $e');
      return const GarageConfigResult(GarageConfigStatus.error);
    }
  }
}
