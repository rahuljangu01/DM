import '../core/utils/currency_formatter.dart';
import '../widgets/badge_chip.dart';

class Party {
  final int? id;
  final String name;
  final String type; // 'customer', 'supplier', 'both', 'wholesaler', 'retailer', 'manufacturer', 'material'
  final String? phone;
  final String? address;
  final String? imagePath;
  final int openingBalancePaise;
  final String balanceType; // 'receivable', 'payable'
  final int currentBalancePaise;
  final String? notes;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  Party({
    this.id,
    required this.name,
    this.type = 'customer',
    this.phone,
    this.address,
    this.imagePath,
    this.openingBalancePaise = 0,
    this.balanceType = 'receivable',
    this.currentBalancePaise = 0,
    this.notes,
    this.isArchived = false,
    String? createdAt,
    String? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  double get openingBalanceRupees => CurrencyFormatter.paiseToRupees(openingBalancePaise);
  double get currentBalanceRupees => CurrencyFormatter.paiseToRupees(currentBalancePaise);

  bool get isCustomer => type == 'customer' || type == 'wholesaler' || type == 'retailer' || type == 'both';
  bool get isSupplier => type == 'supplier' || type == 'manufacturer' || type == 'material' || type == 'both';
  bool get isWholesaler => type == 'wholesaler';
  bool get isRetailer => type == 'retailer';
  bool get isManufacturer => type == 'manufacturer';
  bool get isMaterial => type == 'material';

  String typeDisplayName(bool isHindi) {
    switch (type) {
      case 'wholesaler':
        return isHindi ? 'होलसेलर (Wholesaler)' : 'Wholesaler';
      case 'retailer':
        return isHindi ? 'रिटेलर (Retailer)' : 'Retailer';
      case 'manufacturer':
        return isHindi ? 'मैन्युफैक्चरर (कारखाना)' : 'Manufacturer';
      case 'material':
        return isHindi ? 'सप्लायर (कच्चा माल)' : 'Raw Material';
      case 'supplier':
        return isHindi ? 'सप्लायर (Supplier)' : 'Supplier';
      case 'both':
        return isHindi ? 'ग्राहक व सप्लायर' : 'Customer & Supplier';
      case 'customer':
      default:
        return isHindi ? 'ग्राहक (Customer)' : 'Customer';
    }
  }

  BadgeType get badgeType {
    switch (type) {
      case 'wholesaler':
        return BadgeType.wholesaler;
      case 'retailer':
        return BadgeType.retailer;
      case 'manufacturer':
        return BadgeType.manufacturer;
      case 'material':
        return BadgeType.material;
      case 'supplier':
        return BadgeType.supplier;
      case 'both':
        return BadgeType.both;
      case 'customer':
      default:
        return BadgeType.customer;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'phone': phone,
      'address': address,
      'image_path': imagePath,
      'opening_balance_paise': openingBalancePaise,
      'balance_type': balanceType,
      'current_balance_paise': currentBalancePaise,
      'notes': notes,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Party.fromMap(Map<String, dynamic> map) {
    return Party(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String? ?? 'customer',
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      imagePath: map['image_path'] as String?,
      openingBalancePaise: (map['opening_balance_paise'] as num?)?.toInt() ?? 0,
      balanceType: map['balance_type'] as String? ?? 'receivable',
      currentBalancePaise: (map['current_balance_paise'] as num?)?.toInt() ?? 0,
      notes: map['notes'] as String?,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Party copyWith({
    int? id,
    String? name,
    String? type,
    String? phone,
    String? address,
    String? imagePath,
    bool clearImagePath = false,
    int? openingBalancePaise,
    String? balanceType,
    int? currentBalancePaise,
    String? notes,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
  }) {
    return Party(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      openingBalancePaise: openingBalancePaise ?? this.openingBalancePaise,
      balanceType: balanceType ?? this.balanceType,
      currentBalancePaise: currentBalancePaise ?? this.currentBalancePaise,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
