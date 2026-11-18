import '../core/utils/currency_formatter.dart';
import 'document_item.dart';

class BusinessDocument {
  final int? id;
  final String docNumber;
  final String docType; // 'kaccha_bill', 'challan', 'tax_invoice', 'purchase_bill'
  final String tradeType; // 'sale' (माल दिया/आउटवर्ड) or 'purchase' (माल आया/इनवर्ड)
  final int partyId;
  final String? partyName;
  final String docDate; // ISO-8601 or YYYY-MM-DD
  final String? dueDate;
  final int subtotalPaise;
  final int discountPaise;
  final int taxPaise;
  final int grandTotalPaise;
  final int paidAmountPaise;
  final int remainingBalancePaise;
  final String paymentStatus; // 'unpaid', 'partial', 'paid'
  final bool isConvertedFromChallan;
  final int? originalChallanId;
  final bool isCancelled;
  final String? imagePath;
  final String? imageBase64;
  final String? imageUrl;
  final String? notes;
  final String createdAt;
  final List<DocumentItem> items;

  BusinessDocument({
    this.id,
    required this.docNumber,
    required this.docType,
    this.tradeType = 'sale',
    required this.partyId,
    this.partyName,
    required this.docDate,
    this.dueDate,
    this.subtotalPaise = 0,
    this.discountPaise = 0,
    this.taxPaise = 0,
    this.grandTotalPaise = 0,
    this.paidAmountPaise = 0,
    int? remainingBalancePaise,
    String? paymentStatus,
    this.isConvertedFromChallan = false,
    this.originalChallanId,
    this.isCancelled = false,
    this.imagePath,
    this.imageBase64,
    this.imageUrl,
    this.notes,
    String? createdAt,
    this.items = const [],
  })  : remainingBalancePaise = remainingBalancePaise ?? (grandTotalPaise - paidAmountPaise),
        paymentStatus = paymentStatus ??
            _deriveStatus(grandTotalPaise, paidAmountPaise),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  static String _deriveStatus(int grandTotal, int paid) {
    if (paid >= grandTotal && grandTotal > 0) return 'paid';
    if (paid > 0) return 'partial';
    return 'unpaid';
  }

  bool get isChallan => docType == 'challan';
  bool get isKacchaBill => docType == 'kaccha_bill';
  bool get isTaxInvoice => docType == 'tax_invoice';
  bool get isPurchase => tradeType == 'purchase' || docType == 'purchase_bill';
  bool get hasImage =>
      (imageUrl != null && imageUrl!.trim().isNotEmpty) ||
      (imagePath != null && imagePath!.trim().isNotEmpty) ||
      (imageBase64 != null && imageBase64!.trim().isNotEmpty);

  double get grandTotalRupees => CurrencyFormatter.paiseToRupees(grandTotalPaise);
  double get paidAmountRupees => CurrencyFormatter.paiseToRupees(paidAmountPaise);
  double get remainingBalanceRupees => CurrencyFormatter.paiseToRupees(remainingBalancePaise);
  double get subtotalRupees => CurrencyFormatter.paiseToRupees(subtotalPaise);
  double get discountRupees => CurrencyFormatter.paiseToRupees(discountPaise);
  double get taxRupees => CurrencyFormatter.paiseToRupees(taxPaise);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'doc_number': docNumber,
      'doc_type': docType,
      'trade_type': tradeType,
      'party_id': partyId,
      'doc_date': docDate,
      'due_date': dueDate,
      'subtotal_paise': subtotalPaise,
      'discount_paise': discountPaise,
      'tax_paise': taxPaise,
      'grand_total_paise': grandTotalPaise,
      'paid_amount_paise': paidAmountPaise,
      'remaining_balance_paise': remainingBalancePaise,
      'payment_status': paymentStatus,
      'is_converted_from_challan': isConvertedFromChallan ? 1 : 0,
      'original_challan_id': originalChallanId,
      'is_cancelled': isCancelled ? 1 : 0,
      'image_path': imagePath,
      'image_base64': imageBase64,
      'image_url': imageUrl,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory BusinessDocument.fromMap(Map<String, dynamic> map, {List<DocumentItem> items = const []}) {
    return BusinessDocument(
      id: map['id'] as int?,
      docNumber: map['doc_number'] as String,
      docType: map['doc_type'] as String,
      tradeType: (map['trade_type'] as String?) ?? 'sale',
      partyId: map['party_id'] as int,
      partyName: map['party_name'] as String?,
      docDate: map['doc_date'] as String,
      dueDate: map['due_date'] as String?,
      subtotalPaise: (map['subtotal_paise'] as num?)?.toInt() ?? 0,
      discountPaise: (map['discount_paise'] as num?)?.toInt() ?? 0,
      taxPaise: (map['tax_paise'] as num?)?.toInt() ?? 0,
      grandTotalPaise: (map['grand_total_paise'] as num?)?.toInt() ?? 0,
      paidAmountPaise: (map['paid_amount_paise'] as num?)?.toInt() ?? 0,
      remainingBalancePaise: (map['remaining_balance_paise'] as num?)?.toInt() ?? 0,
      paymentStatus: map['payment_status'] as String? ?? 'unpaid',
      isConvertedFromChallan: (map['is_converted_from_challan'] as int? ?? 0) == 1,
      originalChallanId: map['original_challan_id'] as int?,
      isCancelled: (map['is_cancelled'] as int? ?? 0) == 1,
      imagePath: map['image_path'] as String?,
      imageBase64: map['image_base64'] as String?,
      imageUrl: map['image_url'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
      items: items,
    );
  }

  BusinessDocument copyWith({
    int? id,
    String? docNumber,
    String? docType,
    String? tradeType,
    int? partyId,
    String? partyName,
    String? docDate,
    String? dueDate,
    int? subtotalPaise,
    int? discountPaise,
    int? taxPaise,
    int? grandTotalPaise,
    int? paidAmountPaise,
    int? remainingBalancePaise,
    String? paymentStatus,
    bool? isConvertedFromChallan,
    int? originalChallanId,
    bool? isCancelled,
    String? imagePath,
    String? imageBase64,
    String? imageUrl,
    String? notes,
    String? createdAt,
    List<DocumentItem>? items,
  }) {
    return BusinessDocument(
      id: id ?? this.id,
      docNumber: docNumber ?? this.docNumber,
      docType: docType ?? this.docType,
      tradeType: tradeType ?? this.tradeType,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      docDate: docDate ?? this.docDate,
      dueDate: dueDate ?? this.dueDate,
      subtotalPaise: subtotalPaise ?? this.subtotalPaise,
      discountPaise: discountPaise ?? this.discountPaise,
      taxPaise: taxPaise ?? this.taxPaise,
      grandTotalPaise: grandTotalPaise ?? this.grandTotalPaise,
      paidAmountPaise: paidAmountPaise ?? this.paidAmountPaise,
      remainingBalancePaise: remainingBalancePaise ?? this.remainingBalancePaise,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isConvertedFromChallan: isConvertedFromChallan ?? this.isConvertedFromChallan,
      originalChallanId: originalChallanId ?? this.originalChallanId,
      isCancelled: isCancelled ?? this.isCancelled,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}
