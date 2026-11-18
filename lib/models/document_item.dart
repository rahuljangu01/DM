import '../core/utils/currency_formatter.dart';

class DocumentItem {
  final int? id;
  final int? documentId;
  final String itemName;
  final String? description;
  final double quantity;
  final String unit; // 'meter', 'roll', 'piece', 'kg', 'yard'
  final int ratePaise;
  final int discountPaise;
  final double gstRatePercent;
  final int taxableAmountPaise;
  final int lineTotalPaise;
  final int? inventoryItemId;

  DocumentItem({
    this.id,
    this.documentId,
    required this.itemName,
    this.description,
    this.quantity = 1.0,
    this.unit = 'meter',
    this.ratePaise = 0,
    this.discountPaise = 0,
    this.gstRatePercent = 0.0,
    int? taxableAmountPaise,
    int? lineTotalPaise,
    this.inventoryItemId,
  })  : taxableAmountPaise = taxableAmountPaise ?? _calculateTaxable(quantity, ratePaise, discountPaise),
        lineTotalPaise = lineTotalPaise ??
            _calculateTotal(
              taxableAmountPaise ?? _calculateTaxable(quantity, ratePaise, discountPaise),
              gstRatePercent,
            );

  static int _calculateTaxable(double qty, int rate, int discount) {
    final raw = (qty * rate).round();
    final afterDiscount = raw - discount;
    return afterDiscount > 0 ? afterDiscount : 0;
  }

  static int _calculateTotal(int taxable, double gstPercent) {
    final taxAmount = (taxable * (gstPercent / 100.0)).round();
    return taxable + taxAmount;
  }

  double get rateRupees => CurrencyFormatter.paiseToRupees(ratePaise);
  double get discountRupees => CurrencyFormatter.paiseToRupees(discountPaise);
  double get taxableAmountRupees => CurrencyFormatter.paiseToRupees(taxableAmountPaise);
  double get lineTotalRupees => CurrencyFormatter.paiseToRupees(lineTotalPaise);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      'item_name': itemName,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'rate_paise': ratePaise,
      'discount_paise': discountPaise,
      'gst_rate_percent': gstRatePercent,
      'taxable_amount_paise': taxableAmountPaise,
      'line_total_paise': lineTotalPaise,
      'inventory_item_id': inventoryItemId,
    };
  }

  factory DocumentItem.fromMap(Map<String, dynamic> map) {
    return DocumentItem(
      id: map['id'] as int?,
      documentId: map['document_id'] as int?,
      itemName: map['item_name'] as String,
      description: map['description'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] as String? ?? 'meter',
      ratePaise: (map['rate_paise'] as num?)?.toInt() ?? 0,
      discountPaise: (map['discount_paise'] as num?)?.toInt() ?? 0,
      gstRatePercent: (map['gst_rate_percent'] as num?)?.toDouble() ?? 0.0,
      taxableAmountPaise: (map['taxable_amount_paise'] as num?)?.toInt() ?? 0,
      lineTotalPaise: (map['line_total_paise'] as num?)?.toInt() ?? 0,
      inventoryItemId: map['inventory_item_id'] as int?,
    );
  }

  DocumentItem copyWith({
    int? id,
    int? documentId,
    String? itemName,
    String? description,
    double? quantity,
    String? unit,
    int? ratePaise,
    int? discountPaise,
    double? gstRatePercent,
    int? taxableAmountPaise,
    int? lineTotalPaise,
    int? inventoryItemId,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      ratePaise: ratePaise ?? this.ratePaise,
      discountPaise: discountPaise ?? this.discountPaise,
      gstRatePercent: gstRatePercent ?? this.gstRatePercent,
      taxableAmountPaise: taxableAmountPaise ?? this.taxableAmountPaise,
      lineTotalPaise: lineTotalPaise ?? this.lineTotalPaise,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
    );
  }
}
