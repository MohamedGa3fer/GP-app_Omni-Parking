class ParkingSpot {
  final String spotId;
  final String zoneId;
  final int spotNumber;
  final bool isOccupied;

  const ParkingSpot({
    required this.spotId,
    required this.zoneId,
    required this.spotNumber,
    required this.isOccupied,
  });

  Map<String, dynamic> toMap() => {
        'spot_id': spotId,
        'zone_id': zoneId,
        'spot_number': spotNumber,
        'is_occupied': isOccupied ? 1 : 0,
      };

  factory ParkingSpot.fromMap(Map<String, dynamic> map) => ParkingSpot(
        spotId: map['spot_id'] as String,
        zoneId: map['zone_id'] as String,
        spotNumber: map['spot_number'] as int,
        isOccupied: (map['is_occupied'] as int) == 1,
      );
}
