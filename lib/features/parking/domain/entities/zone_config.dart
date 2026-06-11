/// One editable zone in the garage layout. [zoneId] is null for a zone the
/// user just added that hasn't been persisted yet.
class ZoneConfig {
  final String? zoneId;
  final String name;
  final int capacity;

  const ZoneConfig({
    this.zoneId,
    required this.name,
    required this.capacity,
  });

  ZoneConfig copyWith({String? name, int? capacity}) {
    return ZoneConfig(
      zoneId: zoneId,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
    );
  }
}
