import '../entities/parking_session.dart';
import '../entities/zone.dart';
import '../entities/zone_config.dart';
import '../entities/garage_settings.dart';

/// Outcome of a check-in attempt. These are *expected* business results, not
/// programmer errors, so they're modelled as values (not thrown exceptions) —
/// the UI can show the precise reason instead of a generic failure.
enum CheckInResult {
  success,
  duplicate, // plate already has an active session
  garageFull, // no free spot in the chosen zone
  error, // unexpected failure (DB, etc.)
}

/// Outcome of applying a garage layout. [blockedZoneName] is set when the
/// failure is [GarageConfigStatus.zoneHasParkedCars].
enum GarageConfigStatus { success, needAtLeastOneZone, zoneHasParkedCars, error }

class GarageConfigResult {
  final GarageConfigStatus status;
  final String? blockedZoneName;
  const GarageConfigResult(this.status, {this.blockedZoneName});
}

abstract class ParkingRepository {
  Future<List<ParkingSession>> getActiveSessions();
  Future<List<ParkingSession>> getCompletedSessions();
  Future<ParkingSession?> getSessionById(int id);
  Future<ParkingSession?> getActiveSessionByPlate(String normalizedPlate);
  Future<CheckInResult> checkIn(String licensePlate, String zoneId);
  /// Checks a car out. Returns the completed [ParkingSession] (with exit time,
  /// duration, and final fee) on success, or null if the session wasn't found.
  Future<ParkingSession?> checkOut(int sessionId);
  Future<List<Zone>> getZones();
  Future<Zone?> getZoneById(String id);
  Future<GarageSettings> getGarageSettings();
  Future<void> updateGarageSettings(GarageSettings settings);

  // Garage layout (user-defined zones).
  Future<bool> isGarageConfigured();
  Future<List<ZoneConfig>> getGarageConfig();
  Future<GarageConfigResult> applyGarageConfig(List<ZoneConfig> zones);
}

