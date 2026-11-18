import '../core/utils/currency_formatter.dart';

class BusinessTransaction {
  final int? id;
  final String transactionDate;
  final int? partyId;
  final String? partyName;
  final String transactionType; // customer_receipt, supplier_payment, expense, other_income, owner_capital, owner_withdrawal, cash_to_bank, bank_to_cash
  final int amountPaise;
  final String paymentMethod; // cash, upi, bank_transfer, cheque, other
  final String? referenceNumber;
  final int? relatedDocId;
  final String? relatedDocNumber;
  final String? expenseCategory;
  final String? notes;
  final String createdAt;

  BusinessTransaction({
    this.id,
    required this.transactionDate,
    this.partyId,
    this.partyName,
    required this.transactionType,
    required this.amountPaise,
    this.paymentMethod = 'cash',
    this.referenceNumber,
    this.relatedDocId,
    this.relatedDocNumber,
    this.expenseCategory,
    this.notes,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  double get amountRupees => CurrencyFormatter.paiseToRupees(amountPaise);

  bool get isCustomerReceipt => transactionType == 'customer_receipt';
  bool get isSupplierPayment => transactionType == 'supplier_payment';
  bool get isExpense => transactionType == 'expense';
  bool get isIncome => transactionType == 'other_income';
  bool get isTransfer => transactionType == 'cash_to_bank' || transactionType == 'bank_to_cash';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'transaction_date': transactionDate,
      'party_id': partyId,
      'transaction_type': transactionType,
      'amount_paise': amountPaise,
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'related_doc_id': relatedDocId,
      'expense_category': expenseCategory,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory BusinessTransaction.fromMap(Map<String, dynamic> map) {
    return BusinessTransaction(
      id: map['id'] as int?,
      transactionDate: map['transaction_date'] as String,
      partyId: map['party_id'] as int?,
      partyName: map['party_name'] as String?,
      transactionType: map['transaction_type'] as String,
      amountPaise: (map['amount_paise'] as num?)?.toInt() ?? 0,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      referenceNumber: map['reference_number'] as String?,
      relatedDocId: map['related_doc_id'] as int?,
      relatedDocNumber: map['related_doc_number'] as String?,
      expenseCategory: map['expense_category'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  BusinessTransaction copyWith({
    int? id,
    String? transactionDate,
    int? partyId,
    String? partyName,
    String? transactionType,
    int? amountPaise,
    String? paymentMethod,
    String? referenceNumber,
    int? relatedDocId,
    String? relatedDocNumber,
    String? expenseCategory,
    String? notes,
    String? createdAt,
  }) {
    return BusinessTransaction(
      id: id ?? this.id,
      transactionDate: transactionDate ?? this.transactionDate,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      transactionType: transactionType ?? this.transactionType,
      amountPaise: amountPaise ?? this.amountPaise,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      relatedDocId: relatedDocId ?? this.relatedDocId,
      relatedDocNumber: relatedDocNumber ?? this.relatedDocNumber,
      expenseCategory: expenseCategory ?? this.expenseCategory,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
