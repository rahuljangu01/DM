import '../core/utils/currency_formatter.dart';

class Worker {
  final int? id;
  final String name;
  final String? phone;
  final String? machineNumber;
  final String wageType; // 'katai_piece', 'daily', 'monthly'
  final int ratePaise; // Rate per meter / day in paise
  final int openingBalancePaise;
  final String balanceType; // 'payable', 'advance'
  final int currentBalancePaise;
  final String? notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  Worker({
    this.id,
    required this.name,
    this.phone,
    this.machineNumber,
    this.wageType = 'katai_piece',
    this.ratePaise = 0,
    this.openingBalancePaise = 0,
    this.balanceType = 'payable',
    this.currentBalancePaise = 0,
    this.notes,
    this.isActive = true,
    String? createdAt,
    String? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  double get rateRupees => CurrencyFormatter.paiseToRupees(ratePaise);
  double get openingBalanceRupees => CurrencyFormatter.paiseToRupees(openingBalancePaise);
  double get currentBalanceRupees => CurrencyFormatter.paiseToRupees(currentBalancePaise);

  String wageTypeDisplay(bool isHindi) {
    switch (wageType) {
      case 'daily':
        return isHindi ? 'दैनिक मजदूरी' : 'Daily Wage';
      case 'monthly':
        return isHindi ? 'मासिक पगार' : 'Monthly Salary';
      case 'katai_piece':
      default:
        return isHindi ? 'कटाई दर' : 'Per Meter Katai';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'machine_number': machineNumber,
      'wage_type': wageType,
      'rate_paise': ratePaise,
      'opening_balance_paise': openingBalancePaise,
      'balance_type': balanceType,
      'current_balance_paise': currentBalancePaise,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Worker.fromMap(Map<String, dynamic> map) {
    return Worker(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      machineNumber: map['machine_number'] as String?,
      wageType: map['wage_type'] as String? ?? 'katai_piece',
      ratePaise: (map['rate_paise'] as num?)?.toInt() ?? 0,
      openingBalancePaise: (map['opening_balance_paise'] as num?)?.toInt() ?? 0,
      balanceType: map['balance_type'] as String? ?? 'payable',
      currentBalancePaise: (map['current_balance_paise'] as num?)?.toInt() ?? 0,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Worker copyWith({
    int? id,
    String? name,
    String? phone,
    String? machineNumber,
    String? wageType,
    int? ratePaise,
    int? openingBalancePaise,
    String? balanceType,
    int? currentBalancePaise,
    String? notes,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Worker(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      machineNumber: machineNumber ?? this.machineNumber,
      wageType: wageType ?? this.wageType,
      ratePaise: ratePaise ?? this.ratePaise,
      openingBalancePaise: openingBalancePaise ?? this.openingBalancePaise,
      balanceType: balanceType ?? this.balanceType,
      currentBalancePaise: currentBalancePaise ?? this.currentBalancePaise,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
