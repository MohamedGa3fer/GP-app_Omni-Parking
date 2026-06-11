class Zone {
  final String id;
  final String name;
  final String? description;
  final int totalCapacity;
  final int occupiedSpots;

  const Zone({
    required this.id,
    required this.name,
    this.description,
    required this.totalCapacity,
    this.occupiedSpots = 0,
  });

  int get availableSpots => totalCapacity - occupiedSpots;

  Zone copyWith({int? occupiedSpots}) {
    return Zone(
      id: id,
      name: name,
      description: description,
      totalCapacity: totalCapacity,
      occupiedSpots: occupiedSpots ?? this.occupiedSpots,
    );
  }
}

