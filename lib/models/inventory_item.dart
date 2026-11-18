import '../core/utils/currency_formatter.dart';

class InventoryItem {
  final int? id;
  final String designCode;
  final String itemName;
  final String unit; // 'meter', 'roll', 'piece', 'kg', 'yard'
  final double openingQuantity;
  final double purchaseQuantity;
  final double salesQuantity;
  final double currentStock;
  final int purchaseRatePaise;
  final int sellingRatePaise;
  final double lowStockWarningQty;
  final bool isActive;
  final String createdAt;
  final String? category;
  final String? width;
  final String? colors;
  final String? imagePath;
  final String? imageBase64;
  final String? imageUrl;
  final String? description;

  InventoryItem({
    this.id,
    required this.designCode,
    required this.itemName,
    this.unit = 'meter',
    this.openingQuantity = 0.0,
    this.purchaseQuantity = 0.0,
    this.salesQuantity = 0.0,
    double? currentStock,
    this.purchaseRatePaise = 0,
    this.sellingRatePaise = 0,
    this.lowStockWarningQty = 50.0,
    this.isActive = true,
    String? createdAt,
    this.category,
    this.width,
    this.colors,
    this.imagePath,
    this.imageBase64,
    this.imageUrl,
    this.description,
  })  : currentStock = currentStock ?? (openingQuantity + purchaseQuantity - salesQuantity),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  double get purchaseRateRupees => CurrencyFormatter.paiseToRupees(purchaseRatePaise);
  double get sellingRateRupees => CurrencyFormatter.paiseToRupees(sellingRatePaise);
  double get saleRateRupees => sellingRateRupees;
  bool get isLowStock => currentStock <= lowStockWarningQty;
  bool get hasImage =>
      (imagePath != null && imagePath!.isNotEmpty) ||
      (imageBase64 != null && imageBase64!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'design_code': designCode,
      'item_name': itemName,
      'unit': unit,
      'opening_quantity': openingQuantity,
      'purchase_quantity': purchaseQuantity,
      'sales_quantity': salesQuantity,
      'current_stock': currentStock,
      'purchase_rate_paise': purchaseRatePaise,
      'selling_rate_paise': sellingRatePaise,
      'low_stock_warning_qty': lowStockWarningQty,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      if (category != null) 'category': category,
      if (width != null) 'width': width,
      if (colors != null) 'colors': colors,
      if (imagePath != null) 'image_path': imagePath,
      if (imageBase64 != null) 'image_base64': imageBase64,
      if (imageUrl != null) 'image_url': imageUrl,
      if (description != null) 'description': description,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as int?,
      designCode: map['design_code'] as String,
      itemName: map['item_name'] as String,
      unit: map['unit'] as String? ?? 'meter',
      openingQuantity: (map['opening_quantity'] as num?)?.toDouble() ?? 0.0,
      purchaseQuantity: (map['purchase_quantity'] as num?)?.toDouble() ?? 0.0,
      salesQuantity: (map['sales_quantity'] as num?)?.toDouble() ?? 0.0,
      currentStock: (map['current_stock'] as num?)?.toDouble() ?? 0.0,
      purchaseRatePaise: (map['purchase_rate_paise'] as num?)?.toInt() ?? 0,
      sellingRatePaise: (map['selling_rate_paise'] as num?)?.toInt() ?? 0,
      lowStockWarningQty: (map['low_stock_warning_qty'] as num?)?.toDouble() ?? 50.0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
      category: map['category'] as String?,
      width: map['width'] as String?,
      colors: map['colors'] as String?,
      imagePath: map['image_path'] as String?,
      imageBase64: map['image_base64'] as String?,
      imageUrl: map['image_url'] as String?,
      description: map['description'] as String?,
    );
  }

  InventoryItem copyWith({
    int? id,
    String? designCode,
    String? itemName,
    String? unit,
    double? openingQuantity,
    double? purchaseQuantity,
    double? salesQuantity,
    double? currentStock,
    int? purchaseRatePaise,
    int? sellingRatePaise,
    double? lowStockWarningQty,
    bool? isActive,
    String? createdAt,
    String? category,
    String? width,
    String? colors,
    String? imagePath,
    String? imageBase64,
    String? imageUrl,
    String? description,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      designCode: designCode ?? this.designCode,
      itemName: itemName ?? this.itemName,
      unit: unit ?? this.unit,
      openingQuantity: openingQuantity ?? this.openingQuantity,
      purchaseQuantity: purchaseQuantity ?? this.purchaseQuantity,
      salesQuantity: salesQuantity ?? this.salesQuantity,
      currentStock: currentStock ?? this.currentStock,
      purchaseRatePaise: purchaseRatePaise ?? this.purchaseRatePaise,
      sellingRatePaise: sellingRatePaise ?? this.sellingRatePaise,
      lowStockWarningQty: lowStockWarningQty ?? this.lowStockWarningQty,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      width: width ?? this.width,
      colors: colors ?? this.colors,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
    );
  }
}
