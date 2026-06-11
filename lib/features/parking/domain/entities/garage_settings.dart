class GarageSettings {
  final double hourlyRateEgp;
  final int totalCapacity;

  const GarageSettings({
    this.hourlyRateEgp = 5.0,
    this.totalCapacity = 60,
  });

  GarageSettings copyWith({
    double? hourlyRateEgp,
    int? totalCapacity,
  }) {
    return GarageSettings(
      hourlyRateEgp: hourlyRateEgp ?? this.hourlyRateEgp,
      totalCapacity: totalCapacity ?? this.totalCapacity,
    );
  }
}
