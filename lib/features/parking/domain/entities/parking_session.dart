class ParkingSession {
  final int? id;
  final String licensePlate;
  final String normalizedPlate;
  final String zoneId;
  final String? spotId;
  final DateTime entryTime;
  final DateTime? exitTime;
  final double durationHours;
  final double totalFee;
  final String status;
  final String syncStatus;
  final DateTime createdAt;

  const ParkingSession({
    this.id,
    required this.licensePlate,
    required this.normalizedPlate,
    required this.zoneId,
    this.spotId,
    required this.entryTime,
    this.exitTime,
    this.durationHours = 0.0,
    this.totalFee = 0.0,
    this.status = 'active',
    this.syncStatus = 'PENDING',
    required this.createdAt,
  });

  ParkingSession copyWith({
    int? id,
    String? licensePlate,
    String? normalizedPlate,
    String? zoneId,
    String? spotId,
    DateTime? entryTime,
    DateTime? exitTime,
    double? durationHours,
    double? totalFee,
    String? status,
    String? syncStatus,
    DateTime? createdAt,
  }) {
    return ParkingSession(
      id: id ?? this.id,
      licensePlate: licensePlate ?? this.licensePlate,
      normalizedPlate: normalizedPlate ?? this.normalizedPlate,
      zoneId: zoneId ?? this.zoneId,
      spotId: spotId ?? this.spotId,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      durationHours: durationHours ?? this.durationHours,
      totalFee: totalFee ?? this.totalFee,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

