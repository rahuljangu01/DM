class DatabaseTables {
  static const String tableParties = 'parties';
  static const String tableDocuments = 'documents';
  static const String tableDocumentItems = 'document_items';
  static const String tableTransactions = 'transactions';
  static const String tableTransactionAllocations = 'transaction_allocations';
  static const String tableInventoryItems = 'inventory_items';
  static const String tableStockMovements = 'stock_movements';
  static const String tableAppSettings = 'app_settings';
  static const String tableAuditLogs = 'audit_logs';
  static const String tableWorkers = 'workers';
  static const String tableWorkerAttendance = 'worker_attendance';
  static const String tableMachineKataiEntries = 'machine_katai_entries';
  static const String tableWorkerPayments = 'worker_payments';
  static const String tableDeletedRecords = 'deleted_records';
  static const String tableAppUsers = 'app_users';

  static const String createAppUsersTable = '''
    CREATE TABLE IF NOT EXISTS $tableAppUsers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      phone TEXT,
      shop_name TEXT,
      created_at TEXT NOT NULL,
      last_login_at TEXT
    );
  ''';

  static const String createDeletedRecordsTable = '''
    CREATE TABLE IF NOT EXISTS $tableDeletedRecords (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity_type TEXT NOT NULL,
      entity_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      subtitle TEXT,
      details_json TEXT NOT NULL,
      deleted_at TEXT NOT NULL,
      is_restored INTEGER NOT NULL DEFAULT 0
    );
  ''';

  static const String createWorkersTable = '''
    CREATE TABLE $tableWorkers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT,
      machine_number TEXT,
      wage_type TEXT NOT NULL DEFAULT 'katai_piece',
      rate_paise INTEGER NOT NULL DEFAULT 0,
      opening_balance_paise INTEGER NOT NULL DEFAULT 0,
      balance_type TEXT NOT NULL DEFAULT 'payable',
      current_balance_paise INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createWorkerAttendanceTable = '''
    CREATE TABLE $tableWorkerAttendance (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      worker_id INTEGER NOT NULL,
      date TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'present',
      overtime_hours REAL DEFAULT 0.0,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (worker_id) REFERENCES $tableWorkers (id) ON DELETE CASCADE
    );
  ''';

  static const String createMachineKataiEntriesTable = '''
    CREATE TABLE $tableMachineKataiEntries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      machine_number TEXT NOT NULL,
      worker_id INTEGER NOT NULL,
      design_code TEXT,
      shift TEXT NOT NULL DEFAULT 'day',
      quantity REAL NOT NULL,
      unit TEXT NOT NULL DEFAULT 'meter',
      rate_paise INTEGER NOT NULL,
      total_amount_paise INTEGER NOT NULL,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (worker_id) REFERENCES $tableWorkers (id) ON DELETE CASCADE
    );
  ''';

  static const String createWorkerPaymentsTable = '''
    CREATE TABLE $tableWorkerPayments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      worker_id INTEGER NOT NULL,
      date TEXT NOT NULL,
      payment_type TEXT NOT NULL DEFAULT 'wage_payout',
      amount_paise INTEGER NOT NULL,
      payment_method TEXT NOT NULL DEFAULT 'cash',
      reference_no TEXT,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (worker_id) REFERENCES $tableWorkers (id) ON DELETE CASCADE
    );
  ''';

  static const String createPartiesTable = '''
    CREATE TABLE $tableParties (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'customer',
      phone TEXT,
      address TEXT,
      opening_balance_paise INTEGER NOT NULL DEFAULT 0,
      balance_type TEXT NOT NULL DEFAULT 'receivable',
      current_balance_paise INTEGER NOT NULL DEFAULT 0,
      image_path TEXT,
      image_base64 TEXT,
      image_url TEXT,
      notes TEXT,
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createDocumentsTable = '''
    CREATE TABLE $tableDocuments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      doc_number TEXT NOT NULL UNIQUE,
      doc_type TEXT NOT NULL,
      trade_type TEXT NOT NULL DEFAULT 'sale',
      party_id INTEGER NOT NULL,
      doc_date TEXT NOT NULL,
      due_date TEXT,
      subtotal_paise INTEGER NOT NULL DEFAULT 0,
      discount_paise INTEGER NOT NULL DEFAULT 0,
      tax_paise INTEGER NOT NULL DEFAULT 0,
      grand_total_paise INTEGER NOT NULL DEFAULT 0,
      paid_amount_paise INTEGER NOT NULL DEFAULT 0,
      remaining_balance_paise INTEGER NOT NULL DEFAULT 0,
      payment_status TEXT NOT NULL DEFAULT 'unpaid',
      is_converted_from_challan INTEGER NOT NULL DEFAULT 0,
      original_challan_id INTEGER,
      is_cancelled INTEGER NOT NULL DEFAULT 0,
      image_path TEXT,
      image_base64 TEXT,
      image_url TEXT,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (party_id) REFERENCES $tableParties (id) ON DELETE RESTRICT,
      FOREIGN KEY (original_challan_id) REFERENCES $tableDocuments (id) ON DELETE SET NULL
    );
  ''';

  static const String createDocumentItemsTable = '''
    CREATE TABLE $tableDocumentItems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id INTEGER NOT NULL,
      item_name TEXT NOT NULL,
      description TEXT,
      quantity REAL NOT NULL DEFAULT 1.0,
      unit TEXT NOT NULL DEFAULT 'meter',
      rate_paise INTEGER NOT NULL DEFAULT 0,
      discount_paise INTEGER NOT NULL DEFAULT 0,
      gst_rate_percent REAL NOT NULL DEFAULT 0.0,
      taxable_amount_paise INTEGER NOT NULL DEFAULT 0,
      line_total_paise INTEGER NOT NULL DEFAULT 0,
      inventory_item_id INTEGER,
      FOREIGN KEY (document_id) REFERENCES $tableDocuments (id) ON DELETE CASCADE,
      FOREIGN KEY (inventory_item_id) REFERENCES $tableInventoryItems (id) ON DELETE SET NULL
    );
  ''';

  static const String createTransactionsTable = '''
    CREATE TABLE $tableTransactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_date TEXT NOT NULL,
      party_id INTEGER,
      transaction_type TEXT NOT NULL,
      amount_paise INTEGER NOT NULL,
      payment_method TEXT NOT NULL DEFAULT 'cash',
      reference_number TEXT,
      related_doc_id INTEGER,
      expense_category TEXT,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (party_id) REFERENCES $tableParties (id) ON DELETE RESTRICT,
      FOREIGN KEY (related_doc_id) REFERENCES $tableDocuments (id) ON DELETE SET NULL
    );
  ''';

  static const String createTransactionAllocationsTable = '''
    CREATE TABLE $tableTransactionAllocations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL,
      document_id INTEGER NOT NULL,
      allocated_amount_paise INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (transaction_id) REFERENCES $tableTransactions (id) ON DELETE CASCADE,
      FOREIGN KEY (document_id) REFERENCES $tableDocuments (id) ON DELETE CASCADE
    );
  ''';

  static const String createInventoryItemsTable = '''
    CREATE TABLE $tableInventoryItems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      design_code TEXT NOT NULL UNIQUE,
      item_name TEXT NOT NULL,
      unit TEXT NOT NULL DEFAULT 'meter',
      opening_quantity REAL NOT NULL DEFAULT 0.0,
      purchase_quantity REAL NOT NULL DEFAULT 0.0,
      sales_quantity REAL NOT NULL DEFAULT 0.0,
      current_stock REAL NOT NULL DEFAULT 0.0,
      purchase_rate_paise INTEGER NOT NULL DEFAULT 0,
      selling_rate_paise INTEGER NOT NULL DEFAULT 0,
      low_stock_warning_qty REAL NOT NULL DEFAULT 50.0,
      is_active INTEGER NOT NULL DEFAULT 1,
      category TEXT,
      width TEXT,
      colors TEXT,
      image_path TEXT,
      image_base64 TEXT,
      image_url TEXT,
      description TEXT,
      created_at TEXT NOT NULL
    );
  ''';

  static const String createStockMovementsTable = '''
    CREATE TABLE $tableStockMovements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id INTEGER NOT NULL,
      movement_date TEXT NOT NULL,
      movement_type TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_rate_paise INTEGER NOT NULL DEFAULT 0,
      reference_doc_id INTEGER,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (item_id) REFERENCES $tableInventoryItems (id) ON DELETE CASCADE,
      FOREIGN KEY (reference_doc_id) REFERENCES $tableDocuments (id) ON DELETE SET NULL
    );
  ''';

  static const String createAppSettingsTable = '''
    CREATE TABLE $tableAppSettings (
      setting_key TEXT PRIMARY KEY,
      setting_value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createAuditLogsTable = '''
    CREATE TABLE $tableAuditLogs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity_type TEXT NOT NULL,
      entity_id INTEGER,
      action TEXT NOT NULL,
      details TEXT,
      created_at TEXT NOT NULL
    );
  ''';

  static const List<String> createIndices = [
    'CREATE INDEX idx_party_name ON $tableParties (name);',
    'CREATE INDEX idx_party_type ON $tableParties (type);',
    'CREATE INDEX idx_party_archived ON $tableParties (is_archived);',
    'CREATE INDEX idx_doc_number ON $tableDocuments (doc_number);',
    'CREATE INDEX idx_doc_party ON $tableDocuments (party_id);',
    'CREATE INDEX idx_doc_date ON $tableDocuments (doc_date);',
    'CREATE INDEX idx_doc_status ON $tableDocuments (payment_status);',
    'CREATE INDEX idx_item_doc ON $tableDocumentItems (document_id);',
    'CREATE INDEX idx_tx_date ON $tableTransactions (transaction_date);',
    'CREATE INDEX idx_tx_party ON $tableTransactions (party_id);',
    'CREATE INDEX idx_tx_type ON $tableTransactions (transaction_type);',
    'CREATE INDEX idx_stock_item ON $tableStockMovements (item_id);',
    'CREATE INDEX idx_attendance_date ON $tableWorkerAttendance (date);',
    'CREATE INDEX idx_attendance_worker ON $tableWorkerAttendance (worker_id);',
    'CREATE INDEX idx_katai_date ON $tableMachineKataiEntries (date);',
    'CREATE INDEX idx_katai_machine ON $tableMachineKataiEntries (machine_number);',
    'CREATE INDEX idx_katai_worker ON $tableMachineKataiEntries (worker_id);',
    'CREATE INDEX idx_payment_worker ON $tableWorkerPayments (worker_id);',
  ];
}
