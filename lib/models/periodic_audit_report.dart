import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';

class PeriodicAuditReport {
  final String startDate;
  final String endDate;
  final String periodTitle;
  final DateTime generatedAt;

  // Financial Stats (in Paise)
  final int totalSalesPaise;
  final int totalSalesCount;
  final int totalReceiptsPaise;
  final int cashReceiptsPaise;
  final int upiReceiptsPaise;
  final int bankReceiptsPaise;
  final int totalPaymentsPaise;
  final int totalExpensesPaise;

  // Factory & Karigar Katai (in Paise & Meters)
  final double totalKataiMeters;
  final int totalKataiAmountPaise;
  final int totalWorkerAdvancesPaise;
  final List<Map<String, dynamic>> workerSummaries;

  // Market Pending Balances
  final List<Map<String, dynamic>> topCustomersDue;
  final List<Map<String, dynamic>> topSuppliersDue;

  // Detailed Transaction Rows for the 10 Days
  final List<Map<String, dynamic>> transactions;

  const PeriodicAuditReport({
    required this.startDate,
    required this.endDate,
    required this.periodTitle,
    required this.generatedAt,
    required this.totalSalesPaise,
    required this.totalSalesCount,
    required this.totalReceiptsPaise,
    this.cashReceiptsPaise = 0,
    this.upiReceiptsPaise = 0,
    this.bankReceiptsPaise = 0,
    required this.totalPaymentsPaise,
    required this.totalExpensesPaise,
    this.totalKataiMeters = 0.0,
    this.totalKataiAmountPaise = 0,
    this.totalWorkerAdvancesPaise = 0,
    this.workerSummaries = const [],
    this.topCustomersDue = const [],
    this.topSuppliersDue = const [],
    this.transactions = const [],
  });

  // Currency helpers
  double get totalSalesRupees => CurrencyFormatter.paiseToRupees(totalSalesPaise);
  double get totalReceiptsRupees => CurrencyFormatter.paiseToRupees(totalReceiptsPaise);
  double get cashReceiptsRupees => CurrencyFormatter.paiseToRupees(cashReceiptsPaise);
  double get upiReceiptsRupees => CurrencyFormatter.paiseToRupees(upiReceiptsPaise);
  double get bankReceiptsRupees => CurrencyFormatter.paiseToRupees(bankReceiptsPaise);
  double get totalPaymentsRupees => CurrencyFormatter.paiseToRupees(totalPaymentsPaise);
  double get totalExpensesRupees => CurrencyFormatter.paiseToRupees(totalExpensesPaise);
  double get netCashFlowRupees => totalReceiptsRupees - totalPaymentsRupees - totalExpensesRupees;
  double get totalKataiAmountRupees => CurrencyFormatter.paiseToRupees(totalKataiAmountPaise);
  double get totalWorkerAdvancesRupees => CurrencyFormatter.paiseToRupees(totalWorkerAdvancesPaise);

  String get generatedAtDisplay => DateFormatter.formatReadable(generatedAt);
}
