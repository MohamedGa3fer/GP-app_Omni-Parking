class Transaction {
  final String id;
  final String plateNumber;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String? spotAssigned;
  final double? totalFee;
  final bool isSynced;
  final String status;

  const Transaction({
    required this.id,
    required this.plateNumber,
    required this.checkInTime,
    this.checkOutTime,
    this.spotAssigned,
    this.totalFee,
    required this.isSynced,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'plate_number': plateNumber,
        'check_in_time': checkInTime.toIso8601String(),
        'check_out_time': checkOutTime?.toIso8601String(),
        'spot_assigned': spotAssigned,
        'total_fee': totalFee,
        'is_synced': isSynced ? 1 : 0,
        'status': status,
      };

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
        id: map['id'] as String,
        plateNumber: map['plate_number'] as String,
        checkInTime: DateTime.parse(map['check_in_time'] as String),
        checkOutTime: map['check_out_time'] != null
            ? DateTime.parse(map['check_out_time'] as String)
            : null,
        spotAssigned: map['spot_assigned'] as String?,
        totalFee: (map['total_fee'] as num?)?.toDouble(),
        isSynced: (map['is_synced'] as int) == 1,
        status: map['status'] as String,
      );
}