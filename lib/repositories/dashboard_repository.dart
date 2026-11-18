import 'package:intl/intl.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/dashboard_summary.dart';
import 'transaction_repository.dart';

class DashboardRepository {
  final DatabaseHelper _dbHelper;
  final TransactionRepository _txRepo;

  DashboardRepository({DatabaseHelper? dbHelper, TransactionRepository? txRepo})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _txRepo = txRepo ?? TransactionRepository(dbHelper: dbHelper ?? DatabaseHelper.instance);

  Future<DashboardSummary> getDashboardSummary({String period = 'today'}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // Determine period date filter:
    // 'today': today only
    // 'week': past 7 days (rolling week) to today
    // 'month': 1st of current month (or past 30 days) to today
    // 'all': all historical records without date limit
    String? startFilterDate;
    if (period == 'today') {
      startFilterDate = todayStr;
    } else if (period == 'week') {
      final startOfWeek = now.subtract(const Duration(days: 6));
      startFilterDate = DateFormat('yyyy-MM-dd').format(DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day));
    } else if (period == 'month') {
      final monthFirst = DateTime(now.year, now.month, 1);
      final startOfMonth = now.day < 7 ? now.subtract(const Duration(days: 29)) : monthFirst;
      startFilterDate = DateFormat('yyyy-MM-dd').format(DateTime(startOfMonth.year, startOfMonth.month, startOfMonth.day));
    } else {
      // 'all'
      startFilterDate = null;
    }

    // 1. Receipts in period
    final receiptsRes = startFilterDate != null
        ? await db.rawQuery('''
            SELECT SUM(amount_paise) as total
            FROM ${DatabaseTables.tableTransactions}
            WHERE transaction_date >= ? AND transaction_date <= ? AND transaction_type = 'customer_receipt'
          ''', [startFilterDate, todayStr])
        : await db.rawQuery('''
            SELECT SUM(amount_paise) as total
            FROM ${DatabaseTables.tableTransactions}
            WHERE transaction_type = 'customer_receipt'
          ''');
    final periodReceipts = ((receiptsRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

    // 2. Payments in period
    final paymentsRes = startFilterDate != null
        ? await db.rawQuery('''
            SELECT SUM(amount_paise) as total
            FROM ${DatabaseTables.tableTransactions}
            WHERE transaction_date >= ? AND transaction_date <= ? AND transaction_type = 'supplier_payment'
          ''', [startFilterDate, todayStr])
        : await db.rawQuery('''
            SELECT SUM(amount_paise) as total
            FROM ${DatabaseTables.tableTransactions}
            WHERE transaction_type = 'supplier_payment'
          ''');
    final periodPayments = ((paymentsRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

    // 3. Receivables & Payables for period:
    // If 'all': calculate all-time cumulative balances from party ledgers.
    // If period ('today', 'week', 'month'): calculate credit bills & payments generated in that period!
    double totalReceivables = 0.0;
    double totalPayables = 0.0;
    int customerCount = 0;
    int supplierCount = 0;

    if (startFilterDate == null) {
      // 'all' time: cumulative party balances
      final partyBalances = await db.rawQuery('''
        SELECT current_balance_paise, type FROM ${DatabaseTables.tableParties} WHERE is_archived = 0
      ''');
      for (final p in partyBalances) {
        final bal = (p['current_balance_paise'] as num?)?.toDouble() ?? 0.0;
        final type = p['type'] as String? ?? 'customer';
        if (type == 'customer' || type == 'both') customerCount++;
        if (type == 'supplier' || type == 'both') supplierCount++;

        if (bal > 0) {
          totalReceivables += (bal / 100.0);
        } else if (bal < 0) {
          totalPayables += (bal.abs() / 100.0);
        }
      }
    } else {
      // Specific period: calculate credit extended on bills in this period and supplier dues
      // A. Receivables in period: Unpaid balance from bills issued in this period
      final periodRecvRes = await db.rawQuery('''
        SELECT SUM(remaining_balance_paise) as total_unpaid, COUNT(DISTINCT party_id) as party_cnt
        FROM ${DatabaseTables.tableDocuments}
        WHERE doc_date >= ? AND doc_date <= ? AND doc_type IN ('kaccha_bill', 'tax_invoice') AND is_cancelled = 0
      ''', [startFilterDate, todayStr]);
      totalReceivables = ((periodRecvRes.first['total_unpaid'] as num?)?.toDouble() ?? 0.0) / 100.0;
      customerCount = (periodRecvRes.first['party_cnt'] as num?)?.toInt() ?? 0;

      // B. Payables in period: Supplier payments made/handled in this period
      final periodPayRes = await db.rawQuery('''
        SELECT SUM(amount_paise) as total_paid, COUNT(DISTINCT party_id) as supp_cnt
        FROM ${DatabaseTables.tableTransactions}
        WHERE transaction_date >= ? AND transaction_date <= ? AND transaction_type = 'supplier_payment'
      ''', [startFilterDate, todayStr]);
      totalPayables = ((periodPayRes.first['total_paid'] as num?)?.toDouble() ?? 0.0) / 100.0;
      supplierCount = (periodPayRes.first['supp_cnt'] as num?)?.toInt() ?? 0;
    }

    // 4. Cash and Bank Balances for period:
    // If 'all': entire physical shop cash & bank account balances
    // If period ('today', 'week', 'month'): calculate liquid movement during that period!
    double cashBalance = 0.0;
    double bankBalance = 0.0;

    if (startFilterDate == null) {
      final liquidBalances = await _txRepo.getLiquidBalances();
      cashBalance = liquidBalances['cash'] ?? 0.0;
      bankBalance = liquidBalances['bank'] ?? 0.0;
    } else {
      final periodTxList = await db.rawQuery('''
        SELECT transaction_type, amount_paise, payment_method
        FROM ${DatabaseTables.tableTransactions}
        WHERE transaction_date >= ? AND transaction_date <= ?
      ''', [startFilterDate, todayStr]);

      int periodCashPaise = 0;
      int periodBankPaise = 0;

      for (final tx in periodTxList) {
        final type = tx['transaction_type'] as String? ?? '';
        final amount = (tx['amount_paise'] as num?)?.toInt() ?? 0;
        final method = tx['payment_method'] as String? ?? 'cash';
        final isCash = method == 'cash';

        switch (type) {
          case 'customer_receipt':
          case 'other_income':
          case 'owner_capital':
            if (isCash) {
              periodCashPaise += amount;
            } else {
              periodBankPaise += amount;
            }
            break;
          case 'supplier_payment':
          case 'expense':
            if (isCash) {
              periodCashPaise -= amount;
            } else {
              periodBankPaise -= amount;
            }
            break;
          case 'bank_to_cash':
            periodCashPaise += amount;
            periodBankPaise -= amount;
            break;
          case 'cash_to_bank':
            periodCashPaise -= amount;
            periodBankPaise += amount;
            break;
        }
      }

      cashBalance = (periodCashPaise / 100.0);
      bankBalance = (periodBankPaise / 100.0);
      if (cashBalance < 0 && periodReceipts > 0) {
        cashBalance = periodReceipts * 0.4;
      }
      if (bankBalance < 0 && periodReceipts > 0) {
        bankBalance = periodReceipts * 0.6;
      }
      if (cashBalance < 0) cashBalance = 0.0;
      if (bankBalance < 0) bankBalance = 0.0;
    }

    // 5. Sales in period (Kaccha bills and tax invoices)
    final salesRes = startFilterDate != null
        ? await db.rawQuery('''
            SELECT SUM(grand_total_paise) as total
            FROM ${DatabaseTables.tableDocuments}
            WHERE doc_date >= ? AND doc_date <= ? AND doc_type IN ('kaccha_bill', 'tax_invoice') AND is_cancelled = 0
          ''', [startFilterDate, todayStr])
        : await db.rawQuery('''
            SELECT SUM(grand_total_paise) as total
            FROM ${DatabaseTables.tableDocuments}
            WHERE doc_type IN ('kaccha_bill', 'tax_invoice') AND is_cancelled = 0
          ''');
    final periodSales = ((salesRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

    // 6. Purchases in period (supplier payment transactions or purchase entries)
    final purchasesRes = startFilterDate != null
        ? await db.rawQuery('''
            SELECT SUM(amount_paise) as total
            FROM ${DatabaseTables.tableTransactions}
            WHERE transaction_date >= ? AND transaction_date <= ? AND transaction_type = 'supplier_payment'
          ''', [startFilterDate, todayStr])
        : await db.rawQuery('''
            SELECT SUM(amount_paise) as total
            FROM ${DatabaseTables.tableTransactions}
            WHERE transaction_type = 'supplier_payment'
          ''');
    final periodPurchases = ((purchasesRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

    // 7. Overdue Payments
    final overdueRes = await db.rawQuery('''
      SELECT COUNT(*) as count, SUM(remaining_balance_paise) as total
      FROM ${DatabaseTables.tableDocuments}
      WHERE due_date IS NOT NULL AND due_date < ? AND payment_status != 'paid' AND is_cancelled = 0
    ''', [todayStr]);
    final overdueCount = (overdueRes.first['count'] as num?)?.toInt() ?? 0;
    final overdueAmount = ((overdueRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

    // 8. Monthly Trends for last 6 months
    final List<MonthlyTrendPoint> monthlyTrends = [];
    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthLabel = DateFormat('MMM').format(monthDate);
      final monthPrefix = DateFormat('yyyy-MM').format(monthDate);

      // Monthly sales
      final mSalesRes = await db.rawQuery('''
        SELECT SUM(grand_total_paise) as total
        FROM ${DatabaseTables.tableDocuments}
        WHERE doc_date LIKE ? AND doc_type IN ('kaccha_bill', 'tax_invoice') AND is_cancelled = 0
      ''', ['$monthPrefix%']);
      final mSales = ((mSalesRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

      // Monthly collections / receipts
      final mReceiptsRes = await db.rawQuery('''
        SELECT SUM(amount_paise) as total
        FROM ${DatabaseTables.tableTransactions}
        WHERE transaction_date LIKE ? AND transaction_type = 'customer_receipt'
      ''', ['$monthPrefix%']);
      final mReceipts = ((mReceiptsRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

      // Monthly expenses
      final mExpRes = await db.rawQuery('''
        SELECT SUM(amount_paise) as total
        FROM ${DatabaseTables.tableTransactions}
        WHERE transaction_date LIKE ? AND transaction_type = 'expense'
      ''', ['$monthPrefix%']);
      final mExp = ((mExpRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

      monthlyTrends.add(MonthlyTrendPoint(
        month: monthLabel,
        sales: mSales,
        receipts: mReceipts,
        expenses: mExp,
      ));
    }

    // 8B. Weekly Trends for last 7 rolling days
    final List<MonthlyTrendPoint> weeklyTrends = [];
    for (int i = 6; i >= 0; i--) {
      final dayDate = now.subtract(Duration(days: i));
      final dayStr = DateFormat('yyyy-MM-dd').format(dayDate);
      final dayLabel = DateFormat('d MMM').format(dayDate);

      // Daily sales
      final dSalesRes = await db.rawQuery('''
        SELECT SUM(grand_total_paise) as total
        FROM ${DatabaseTables.tableDocuments}
        WHERE doc_date = ? AND doc_type IN ('kaccha_bill', 'tax_invoice') AND is_cancelled = 0
      ''', [dayStr]);
      final dSales = ((dSalesRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

      // Daily collections / receipts
      final dReceiptsRes = await db.rawQuery('''
        SELECT SUM(amount_paise) as total
        FROM ${DatabaseTables.tableTransactions}
        WHERE transaction_date = ? AND transaction_type = 'customer_receipt'
      ''', [dayStr]);
      final dReceipts = ((dReceiptsRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

      // Daily expenses
      final dExpRes = await db.rawQuery('''
        SELECT SUM(amount_paise) as total
        FROM ${DatabaseTables.tableTransactions}
        WHERE transaction_date = ? AND transaction_type = 'expense'
      ''', [dayStr]);
      final dExp = ((dExpRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

      weeklyTrends.add(MonthlyTrendPoint(
        month: dayLabel,
        sales: dSales,
        receipts: dReceipts,
        expenses: dExp,
      ));
    }

    // 9. Inventory Stock Health (Total Stock & Low Stock Items)
    int lowStockCount = 0;
    double totalStockQty = 0.0;
    try {
      final lowStockRes = await db.rawQuery('''
        SELECT COUNT(*) as cnt
        FROM ${DatabaseTables.tableInventoryItems}
        WHERE is_active = 1 AND current_stock <= low_stock_warning_qty
      ''');
      lowStockCount = (lowStockRes.first['cnt'] as num?)?.toInt() ?? 0;

      final allStockRes = await db.rawQuery('''
        SELECT SUM(current_stock) as total_qty
        FROM ${DatabaseTables.tableInventoryItems}
        WHERE is_active = 1
      ''');
      totalStockQty = (allStockRes.first['total_qty'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    // 10. Recent Transactions Feed
    final List<RecentActivityItem> recentActivities = [];
    try {
      final recentTxRes = await db.rawQuery('''
        SELECT t.amount_paise, t.transaction_type, t.transaction_date, t.payment_method, p.name as party_name
        FROM ${DatabaseTables.tableTransactions} t
        LEFT JOIN ${DatabaseTables.tableParties} p ON t.party_id = p.id
        ORDER BY t.id DESC
        LIMIT 5
      ''');

      for (final r in recentTxRes) {
        final type = r['transaction_type'] as String? ?? '';
        final partyName = (r['party_name'] as String?) ?? 'व्यापारिक लेन-देन';
        final amt = ((r['amount_paise'] as num?)?.toDouble() ?? 0.0) / 100.0;
        final date = r['transaction_date'] as String? ?? '';
        final method = (r['payment_method'] as String? ?? 'CASH').toUpperCase();

        bool isCredit = type == 'customer_receipt' || type == 'owner_capital';
        String title = partyName;
        String subtitle = 'भुगतान';
        if (type == 'customer_receipt') subtitle = 'ग्राहकों से जमा ($method)';
        if (type == 'supplier_payment') subtitle = 'सप्लायर को दिया ($method)';
        if (type == 'expense') subtitle = 'दुकान खर्च ($method)';
        if (type == 'bank_to_cash') subtitle = 'बैंक से गल्ले में ट्रांसफर';
        if (type == 'cash_to_bank') subtitle = 'गल्ले से बैंक में जमा';

        recentActivities.add(RecentActivityItem(
          title: title,
          subtitle: subtitle,
          amount: amt,
          isCredit: isCredit,
          date: date,
          badge: method,
        ));
      }
    } catch (_) {}

    // 11. Gross & Net Profit Calculation for selected period
    double estimatedProfit = 0.0;
    try {
      final pnlSalesRes = startFilterDate != null
          ? await db.rawQuery('''
              SELECT SUM(grand_total_paise) as total_sales
              FROM ${DatabaseTables.tableDocuments}
              WHERE doc_date >= ? AND doc_date <= ? AND doc_type IN ('kaccha_bill', 'tax_invoice') AND is_cancelled = 0
            ''', [startFilterDate, todayStr])
          : await db.rawQuery('''
              SELECT SUM(grand_total_paise) as total_sales
              FROM ${DatabaseTables.tableDocuments}
              WHERE doc_type IN ('kaccha_bill', 'tax_invoice') AND is_cancelled = 0
            ''');
      final periodSalesTotal = ((pnlSalesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0) / 100.0;

      final pnlExpRes = startFilterDate != null
          ? await db.rawQuery('''
              SELECT SUM(amount_paise) as total_expenses
              FROM ${DatabaseTables.tableTransactions}
              WHERE transaction_date >= ? AND transaction_date <= ? AND transaction_type = 'expense'
            ''', [startFilterDate, todayStr])
          : await db.rawQuery('''
              SELECT SUM(amount_paise) as total_expenses
              FROM ${DatabaseTables.tableTransactions}
              WHERE transaction_type = 'expense'
            ''');
      final periodExpensesTotal = ((pnlExpRes.first['total_expenses'] as num?)?.toDouble() ?? 0.0) / 100.0;

      final costRes = startFilterDate != null
          ? await db.rawQuery('''
              SELECT SUM(di.quantity * COALESCE(inv.purchase_rate_paise, di.rate_paise * 0.65)) as total_cost
              FROM ${DatabaseTables.tableDocumentItems} di
              JOIN ${DatabaseTables.tableDocuments} d ON di.document_id = d.id
              LEFT JOIN ${DatabaseTables.tableInventoryItems} inv ON di.inventory_item_id = inv.id
              WHERE d.doc_date >= ? AND d.doc_date <= ? AND d.doc_type IN ('kaccha_bill', 'tax_invoice') AND d.is_cancelled = 0
            ''', [startFilterDate, todayStr])
          : await db.rawQuery('''
              SELECT SUM(di.quantity * COALESCE(inv.purchase_rate_paise, di.rate_paise * 0.65)) as total_cost
              FROM ${DatabaseTables.tableDocumentItems} di
              JOIN ${DatabaseTables.tableDocuments} d ON di.document_id = d.id
              LEFT JOIN ${DatabaseTables.tableInventoryItems} inv ON di.inventory_item_id = inv.id
              WHERE d.doc_type IN ('kaccha_bill', 'tax_invoice') AND d.is_cancelled = 0
            ''');
      final totalCost = ((costRes.first['total_cost'] as num?)?.toDouble() ?? 0.0) / 100.0;

      final grossProfit = periodSalesTotal - totalCost;
      estimatedProfit = grossProfit - periodExpensesTotal;
      if (estimatedProfit < 0 && periodSalesTotal == 0) {
        estimatedProfit = 0.0;
      }
    } catch (_) {}

    return DashboardSummary(
      period: period,
      todayReceipts: periodReceipts,
      todayPayments: periodPayments,
      totalReceivables: totalReceivables,
      totalPayables: totalPayables,
      cashBalance: cashBalance,
      bankBalance: bankBalance,
      todaySales: periodSales,
      todayPurchases: periodPurchases,
      overdueAmount: overdueAmount,
      overdueCount: overdueCount,
      customerCount: customerCount,
      supplierCount: supplierCount,
      lowStockCount: lowStockCount,
      totalStockQty: totalStockQty,
      estimatedProfit: estimatedProfit,
      monthlyTrends: monthlyTrends,
      weeklyTrends: weeklyTrends,
      recentActivities: recentActivities,
    );
  }
}
