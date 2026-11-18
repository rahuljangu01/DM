import '../core/utils/currency_formatter.dart';

class MachineKataiEntry {
  final int? id;
  final String date; // YYYY-MM-DD
  final String machineNumber; // e.g. "Machine 1", "Multihead #2"
  final int workerId;
  final String? workerName;
  final String? designCode; // e.g. "DM-ZARI-101"
  final String shift; // 'day', 'night'
  final double quantity; // in meters / pieces
  final String unit; // 'meter', 'piece', 'than'
  final int ratePaise;
  final int totalAmountPaise;
  final String? notes;
  final String createdAt;

  MachineKataiEntry({
    this.id,
    required this.date,
    required this.machineNumber,
    required this.workerId,
    this.workerName,
    this.designCode,
    this.shift = 'day',
    required this.quantity,
    this.unit = 'meter',
    required this.ratePaise,
    int? totalAmountPaise,
    this.notes,
    String? createdAt,
  })  : totalAmountPaise = totalAmountPaise ?? (quantity * ratePaise).round(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  double get rateRupees => CurrencyFormatter.paiseToRupees(ratePaise);
  double get totalAmountRupees => CurrencyFormatter.paiseToRupees(totalAmountPaise);

  String shiftDisplay(bool isHindi) {
    return shift == 'night'
        ? (isHindi ? 'रात शिफ्ट' : 'Night Shift')
        : (isHindi ? 'दिन शिफ्ट' : 'Day Shift');
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'machine_number': machineNumber,
      'worker_id': workerId,
      'design_code': designCode,
      'shift': shift,
      'quantity': quantity,
      'unit': unit,
      'rate_paise': ratePaise,
      'total_amount_paise': totalAmountPaise,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory MachineKataiEntry.fromMap(Map<String, dynamic> map, [String? workerName]) {
    return MachineKataiEntry(
      id: map['id'] as int?,
      date: map['date'] as String,
      machineNumber: map['machine_number'] as String,
      workerId: map['worker_id'] as int,
      workerName: workerName ?? map['worker_name'] as String?,
      designCode: map['design_code'] as String?,
      shift: map['shift'] as String? ?? 'day',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'meter',
      ratePaise: (map['rate_paise'] as num?)?.toInt() ?? 0,
      totalAmountPaise: (map['total_amount_paise'] as num?)?.toInt() ?? 0,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }
}
