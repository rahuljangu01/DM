class DashboardSummary {
  final String period; // 'today', 'week', 'month', 'all'
  final double todayReceipts;
  final double todayPayments;
  final double totalReceivables;
  final double totalPayables;
  final double cashBalance;
  final double bankBalance;
  final double todaySales;
  final double todayPurchases;
  final double overdueAmount;
  final int overdueCount;
  final int customerCount;
  final int supplierCount;
  final int lowStockCount;
  final double totalStockQty;
  final double estimatedProfit;
  final List<MonthlyTrendPoint> monthlyTrends;
  final List<MonthlyTrendPoint> weeklyTrends;
  final List<RecentActivityItem> recentActivities;

  const DashboardSummary({
    this.period = 'today',
    this.todayReceipts = 0.0,
    this.todayPayments = 0.0,
    this.totalReceivables = 0.0,
    this.totalPayables = 0.0,
    this.cashBalance = 0.0,
    this.bankBalance = 0.0,
    this.todaySales = 0.0,
    this.todayPurchases = 0.0,
    this.overdueAmount = 0.0,
    this.overdueCount = 0,
    this.customerCount = 0,
    this.supplierCount = 0,
    this.lowStockCount = 0,
    this.totalStockQty = 0.0,
    this.estimatedProfit = 0.0,
    this.monthlyTrends = const [],
    this.weeklyTrends = const [],
    this.recentActivities = const [],
  });

  // Descriptive period getters
  double get periodReceipts => todayReceipts;
  double get periodPayments => todayPayments;
  double get periodSales => todaySales;
  double get periodPurchases => todayPurchases;
  double get periodProfit => estimatedProfit;

  DashboardSummary copyWith({
    String? period,
    double? todayReceipts,
    double? todayPayments,
    double? totalReceivables,
    double? totalPayables,
    double? cashBalance,
    double? bankBalance,
    double? todaySales,
    double? todayPurchases,
    double? overdueAmount,
    int? overdueCount,
    int? customerCount,
    int? supplierCount,
    int? lowStockCount,
    double? totalStockQty,
    double? estimatedProfit,
    List<MonthlyTrendPoint>? monthlyTrends,
    List<MonthlyTrendPoint>? weeklyTrends,
    List<RecentActivityItem>? recentActivities,
  }) {
    return DashboardSummary(
      period: period ?? this.period,
      todayReceipts: todayReceipts ?? this.todayReceipts,
      todayPayments: todayPayments ?? this.todayPayments,
      totalReceivables: totalReceivables ?? this.totalReceivables,
      totalPayables: totalPayables ?? this.totalPayables,
      cashBalance: cashBalance ?? this.cashBalance,
      bankBalance: bankBalance ?? this.bankBalance,
      todaySales: todaySales ?? this.todaySales,
      todayPurchases: todayPurchases ?? this.todayPurchases,
      overdueAmount: overdueAmount ?? this.overdueAmount,
      overdueCount: overdueCount ?? this.overdueCount,
      customerCount: customerCount ?? this.customerCount,
      supplierCount: supplierCount ?? this.supplierCount,
      lowStockCount: lowStockCount ?? this.lowStockCount,
      totalStockQty: totalStockQty ?? this.totalStockQty,
      estimatedProfit: estimatedProfit ?? this.estimatedProfit,
      monthlyTrends: monthlyTrends ?? this.monthlyTrends,
      weeklyTrends: weeklyTrends ?? this.weeklyTrends,
      recentActivities: recentActivities ?? this.recentActivities,
    );
  }
}

class MonthlyTrendPoint {
  final String month;
  final double sales;
  final double receipts;
  final double expenses;

  const MonthlyTrendPoint({
    required this.month,
    required this.sales,
    required this.receipts,
    this.expenses = 0.0,
  });
}

class RecentActivityItem {
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  final String date;
  final String badge;

  const RecentActivityItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.date,
    required this.badge,
  });
}
