import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';

class ReportRepository {
  final DatabaseHelper _dbHelper;

  ReportRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Daily business summary for a specific date
  Future<Map<String, dynamic>> getDailySummary(String dateStr) async {
    final db = await _dbHelper.database;

    // Sales billed today
    final salesRes = await db.rawQuery('''
      SELECT COUNT(*) as doc_count, SUM(grand_total_paise) as total_sales
      FROM ${DatabaseTables.tableDocuments}
      WHERE doc_date = ? AND doc_type IN ('kaccha_bill', 'tax_invoice') AND is_cancelled = 0
    ''', [dateStr]);

    // Receipts collected today
    final receiptsRes = await db.rawQuery('''
      SELECT SUM(amount_paise) as total_receipts
      FROM ${DatabaseTables.tableTransactions}
      WHERE transaction_date = ? AND transaction_type = 'customer_receipt'
    ''', [dateStr]);

    // Supplier payments made today
    final paymentsRes = await db.rawQuery('''
      SELECT SUM(amount_paise) as total_payments
      FROM ${DatabaseTables.tableTransactions}
      WHERE transaction_date = ? AND transaction_type = 'supplier_payment'
    ''', [dateStr]);

    // Expenses incurred today
    final expensesRes = await db.rawQuery('''
      SELECT SUM(amount_paise) as total_expenses
      FROM ${DatabaseTables.tableTransactions}
      WHERE transaction_date = ? AND transaction_type = 'expense'
    ''', [dateStr]);

    return {
      'date': dateStr,
      'doc_count': (salesRes.first['doc_count'] as num?)?.toInt() ?? 0,
      'total_sales_rupees': ((salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0) / 100.0,
      'total_receipts_rupees': ((receiptsRes.first['total_receipts'] as num?)?.toDouble() ?? 0.0) / 100.0,
      'total_payments_rupees': ((paymentsRes.first['total_payments'] as num?)?.toDouble() ?? 0.0) / 100.0,
      'total_expenses_rupees': ((expensesRes.first['total_expenses'] as num?)?.toDouble() ?? 0.0) / 100.0,
    };
  }

  /// Customer outstanding balances
  Future<List<Map<String, dynamic>>> getCustomerOutstanding() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT id, name, phone, address, current_balance_paise
      FROM ${DatabaseTables.tableParties}
      WHERE (type = 'customer' OR type = 'both') AND is_archived = 0 AND current_balance_paise > 0
      ORDER BY current_balance_paise DESC
    ''');

    return res.map((r) => {
      'id': r['id'] as int,
      'name': r['name'] as String,
      'phone': r['phone'] as String?,
      'balance_rupees': ((r['current_balance_paise'] as num).toDouble()) / 100.0,
    }).toList();
  }

  /// Supplier outstanding balances
  Future<List<Map<String, dynamic>>> getSupplierOutstanding() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT id, name, phone, address, current_balance_paise
      FROM ${DatabaseTables.tableParties}
      WHERE (type = 'supplier' OR type = 'both') AND is_archived = 0 AND current_balance_paise < 0
      ORDER BY current_balance_paise ASC
    ''');

    return res.map((r) => {
      'id': r['id'] as int,
      'name': r['name'] as String,
      'phone': r['phone'] as String?,
      'balance_rupees': ((r['current_balance_paise'] as num).toDouble().abs()) / 100.0,
    }).toList();
  }

  /// Expense breakdown by category for a date range
  Future<List<Map<String, dynamic>>> getExpenseBreakdown({String? startDate, String? endDate}) async {
    final db = await _dbHelper.database;
    String sql = '''
      SELECT expense_category, SUM(amount_paise) as total_paise, COUNT(*) as count
      FROM ${DatabaseTables.tableTransactions}
      WHERE transaction_type = 'expense'
    ''';
    final List<dynamic> args = [];

    if (startDate != null && startDate.isNotEmpty) {
      sql += ' AND transaction_date >= ?';
      args.add(startDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      sql += ' AND transaction_date <= ?';
      args.add(endDate);
    }

    sql += ' GROUP BY expense_category ORDER BY total_paise DESC';

    final res = await db.rawQuery(sql, args);
    return res.map((r) => {
      'category': (r['expense_category'] as String?) ?? 'Miscellaneous',
      'amount_rupees': ((r['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0,
      'count': (r['count'] as num?)?.toInt() ?? 0,
    }).toList();
  }

  /// Sales and Gross Profit Estimation (Billed Sales minus cost of sold items)
  Future<Map<String, dynamic>> getProfitAndLossSummary({String? startDate, String? endDate}) async {
    final db = await _dbHelper.database;

    String docFilter = "doc_type IN ('kaccha_bill', 'tax_invoice') AND is_cancelled = 0";
    String txFilter = "1=1";
    final List<dynamic> docArgs = [];
    final List<dynamic> txArgs = [];

    if (startDate != null) {
      docFilter += " AND doc_date >= ?";
      txFilter += " AND transaction_date >= ?";
      docArgs.add(startDate);
      txArgs.add(startDate);
    }
    if (endDate != null) {
      docFilter += " AND doc_date <= ?";
      txFilter += " AND transaction_date <= ?";
      docArgs.add(endDate);
      txArgs.add(endDate);
    }

    final salesRes = await db.rawQuery('''
      SELECT SUM(grand_total_paise) as total_sales
      FROM ${DatabaseTables.tableDocuments}
      WHERE $docFilter
    ''', docArgs);
    final totalSales = ((salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0) / 100.0;

    final expenseRes = await db.rawQuery('''
      SELECT SUM(amount_paise) as total_expenses
      FROM ${DatabaseTables.tableTransactions}
      WHERE transaction_type = 'expense' AND $txFilter
    ''', txArgs);
    final totalExpenses = ((expenseRes.first['total_expenses'] as num?)?.toDouble() ?? 0.0) / 100.0;

    // Estimate item cost from inventory items purchase rates if linked
    final costRes = await db.rawQuery('''
      SELECT SUM(di.quantity * COALESCE(inv.purchase_rate_paise, di.rate_paise * 0.65)) as total_cost
      FROM ${DatabaseTables.tableDocumentItems} di
      JOIN ${DatabaseTables.tableDocuments} d ON di.document_id = d.id
      LEFT JOIN ${DatabaseTables.tableInventoryItems} inv ON di.inventory_item_id = inv.id
      WHERE d.$docFilter
    ''', docArgs);
    final costOfGoods = ((costRes.first['total_cost'] as num?)?.toDouble() ?? 0.0) / 100.0;

    final grossProfit = totalSales - costOfGoods;
    final netOperatingProfit = grossProfit - totalExpenses;

    return {
      'total_sales': totalSales,
      'cost_of_goods': costOfGoods,
      'gross_profit': grossProfit,
      'total_expenses': totalExpenses,
      'net_profit': netOperatingProfit,
    };
  }
}
