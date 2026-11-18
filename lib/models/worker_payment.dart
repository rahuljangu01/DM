import '../core/utils/currency_formatter.dart';

class WorkerPayment {
  final int? id;
  final int workerId;
  final String? workerName;
  final String date; // YYYY-MM-DD
  final String paymentType; // 'wage_payout', 'advance', 'bonus'
  final int amountPaise;
  final String paymentMethod; // 'cash', 'upi', 'bank_transfer'
  final String? referenceNo;
  final String? notes;
  final String createdAt;

  WorkerPayment({
    this.id,
    required this.workerId,
    this.workerName,
    required this.date,
    this.paymentType = 'wage_payout',
    required this.amountPaise,
    this.paymentMethod = 'cash',
    this.referenceNo,
    this.notes,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  double get amountRupees => CurrencyFormatter.paiseToRupees(amountPaise);

  String paymentTypeDisplay(bool isHindi) {
    switch (paymentType) {
      case 'advance':
        return isHindi ? 'उठाव / एडवांस' : 'Advance';
      case 'bonus':
        return isHindi ? 'बोनस' : 'Bonus';
      case 'wage_payout':
      default:
        return isHindi ? 'मजदूरी भुगतान' : 'Wage Payout';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'worker_id': workerId,
      'date': date,
      'payment_type': paymentType,
      'amount_paise': amountPaise,
      'payment_method': paymentMethod,
      'reference_no': referenceNo,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory WorkerPayment.fromMap(Map<String, dynamic> map, [String? workerName]) {
    return WorkerPayment(
      id: map['id'] as int?,
      workerId: map['worker_id'] as int,
      workerName: workerName ?? map['worker_name'] as String?,
      date: map['date'] as String,
      paymentType: map['payment_type'] as String? ?? 'wage_payout',
      amountPaise: (map['amount_paise'] as num?)?.toInt() ?? 0,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      referenceNo: map['reference_no'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }
}
