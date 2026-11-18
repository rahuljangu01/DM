import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'database_tables.dart';

class DatabaseHelper {
  static const String _dbName = 'dm_lace_surat.db';
  static const int _dbVersion = 1;

  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._internal();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  static String? testDbPath;

  /// Reset instance (helpful for test environments)
  static void resetForTesting([Database? testDb, String? path]) {
    _database = testDb;
    testDbPath = path;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // If running on Web, initialize FFI Web
    if (kIsWeb) {
      databaseFactory = createDatabaseFactoryFfiWeb();
    } else if (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (testDbPath != null) {
      path = testDbPath!;
    } else if (kIsWeb) {
      path = _dbName;
    } else {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        path = p.join(docDir.path, _dbName);
      } catch (_) {
        // Fallback for tests or headless environments where path_provider is unavailable
        path = inMemoryDatabasePath;
      }
    }

    final db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureCatalogColumns(db);
    await _ensurePartyColumns(db);
    await _ensureDocumentColumns(db);
    await _ensureWorkerTables(db);
    await _ensureDeletedRecordsTable(db);
    await _ensureAuthTables(db);
    return db;
  }

  Future<void> _ensureAuthTables(Database db) async {
    try {
      await db.execute(DatabaseTables.createAppUsersTable);
    } catch (_) {}
  }

  Future<void> _ensureDocumentColumns(Database db) async {
    try {
      final cols = await db.rawQuery('PRAGMA table_info(${DatabaseTables.tableDocuments});');
      final colNames = cols.map((c) => c['name'] as String).toSet();
      if (!colNames.contains('image_path')) {
        await db.execute('ALTER TABLE ${DatabaseTables.tableDocuments} ADD COLUMN image_path TEXT;');
      }
      if (!colNames.contains('trade_type')) {
        await db.execute("ALTER TABLE ${DatabaseTables.tableDocuments} ADD COLUMN trade_type TEXT NOT NULL DEFAULT 'sale';");
      }
      if (!colNames.contains('image_base64')) {
        await db.execute('ALTER TABLE ${DatabaseTables.tableDocuments} ADD COLUMN image_base64 TEXT;');
      }
      if (!colNames.contains('image_url')) {
        await db.execute('ALTER TABLE ${DatabaseTables.tableDocuments} ADD COLUMN image_url TEXT;');
      }
    } catch (_) {}
  }

  Future<void> _ensureDeletedRecordsTable(Database db) async {
    try {
      await db.execute(DatabaseTables.createDeletedRecordsTable);
    } catch (_) {}
  }

  Future<void> _ensurePartyColumns(Database db) async {
    try {
      final cols = await db.rawQuery('PRAGMA table_info(${DatabaseTables.tableParties});');
      final colNames = cols.map((c) => c['name'] as String).toSet();
      if (!colNames.contains('image_path')) {
        await db.execute('ALTER TABLE ${DatabaseTables.tableParties} ADD COLUMN image_path TEXT;');
      }
    } catch (_) {}
  }

  Future<void> _ensureWorkerTables(Database db) async {
    try {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='${DatabaseTables.tableWorkers}';");
      if (tables.isEmpty) {
        final batch = db.batch();
        batch.execute(DatabaseTables.createWorkersTable);
        batch.execute(DatabaseTables.createWorkerAttendanceTable);
        batch.execute(DatabaseTables.createMachineKataiEntriesTable);
        batch.execute(DatabaseTables.createWorkerPaymentsTable);
        batch.execute('CREATE INDEX IF NOT EXISTS idx_attendance_date ON ${DatabaseTables.tableWorkerAttendance} (date);');
        batch.execute('CREATE INDEX IF NOT EXISTS idx_attendance_worker ON ${DatabaseTables.tableWorkerAttendance} (worker_id);');
        batch.execute('CREATE INDEX IF NOT EXISTS idx_katai_date ON ${DatabaseTables.tableMachineKataiEntries} (date);');
        batch.execute('CREATE INDEX IF NOT EXISTS idx_katai_machine ON ${DatabaseTables.tableMachineKataiEntries} (machine_number);');
        batch.execute('CREATE INDEX IF NOT EXISTS idx_katai_worker ON ${DatabaseTables.tableMachineKataiEntries} (worker_id);');
        batch.execute('CREATE INDEX IF NOT EXISTS idx_payment_worker ON ${DatabaseTables.tableWorkerPayments} (worker_id);');
        await batch.commit(noResult: true);
      }
    } catch (_) {}
  }

  Future<void> _ensureCatalogColumns(Database db) async {
    try {
      final cols = await db.rawQuery('PRAGMA table_info(${DatabaseTables.tableInventoryItems});');
      final colNames = cols.map((c) => c['name'] as String).toSet();
      if (!colNames.contains('category')) {
        await db.execute('ALTER TABLE ${DatabaseTables.tableInventoryItems} ADD COLUMN category TEXT;');
      }
      if (!colNames.contains('width')) {
        await db.execute('ALTER TABLE ${DatabaseTables.tableInventoryItems} ADD COLUMN width TEXT;');
      }
      if (!colNames.contains('colors')) {
        await db.execute('ALTER TABLE ${DatabaseTables.tableInventoryItems} ADD COLUMN colors TEXT;');
      }
      if (!colNames.contains('image_path')) {
        await db.execute('ALTER TABLE ${DatabaseTables.tableInventoryItems} ADD COLUMN image_path TEXT;');
      }
      if (!colNames.contains('image_base64')) {
        await db.execute('ALTER TABLE ${DatabaseTables.tableInventoryItems} ADD COLUMN image_base64 TEXT;');
      }
      if (!colNames.contains('image_url')) {
        await db.execute('ALTER TABLE ${DatabaseTables.tableInventoryItems} ADD COLUMN image_url TEXT;');
      }
      if (!colNames.contains('description')) {
        await db.execute('ALTER TABLE ${DatabaseTables.tableInventoryItems} ADD COLUMN description TEXT;');
      }
    } catch (_) {}
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys constraint enforcement
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // Create tables
    batch.execute(DatabaseTables.createPartiesTable);
    batch.execute(DatabaseTables.createDocumentsTable);
    batch.execute(DatabaseTables.createDocumentItemsTable);
    batch.execute(DatabaseTables.createTransactionsTable);
    batch.execute(DatabaseTables.createTransactionAllocationsTable);
    batch.execute(DatabaseTables.createInventoryItemsTable);
    batch.execute(DatabaseTables.createStockMovementsTable);
    batch.execute(DatabaseTables.createAppSettingsTable);
    batch.execute(DatabaseTables.createAuditLogsTable);
    batch.execute(DatabaseTables.createWorkersTable);
    batch.execute(DatabaseTables.createWorkerAttendanceTable);
    batch.execute(DatabaseTables.createMachineKataiEntriesTable);
    batch.execute(DatabaseTables.createWorkerPaymentsTable);
    batch.execute(DatabaseTables.createDeletedRecordsTable);

    // Create indexes
    for (final indexSql in DatabaseTables.createIndices) {
      batch.execute(indexSql);
    }

    // Insert initial default business settings
    batch.insert(DatabaseTables.tableAppSettings, {
      'setting_key': 'business_name',
      'setting_value': 'DM Lace Surat',
      'updated_at': DateTime.now().toIso8601String(),
    });
    batch.insert(DatabaseTables.tableAppSettings, {
      'setting_key': 'market_address',
      'setting_value': 'Millennium Textile Market, Ring Road, Surat - 395002',
      'updated_at': DateTime.now().toIso8601String(),
    });
    batch.insert(DatabaseTables.tableAppSettings, {
      'setting_key': 'currency_symbol',
      'setting_value': '₹',
      'updated_at': DateTime.now().toIso8601String(),
    });
    batch.insert(DatabaseTables.tableAppSettings, {
      'setting_key': 'inventory_enabled',
      'setting_value': 'true',
      'updated_at': DateTime.now().toIso8601String(),
    });

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future schema migrations will go here
  }

  /// Run an action inside a database transaction
  Future<T> runTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction<T>(action);
  }

  /// Closes database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Wipe database for reset or restore
  Future<void> wipeDatabase() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF;');
      await txn.delete(DatabaseTables.tableTransactionAllocations);
      await txn.delete(DatabaseTables.tableDocumentItems);
      await txn.delete(DatabaseTables.tableTransactions);
      await txn.delete(DatabaseTables.tableDocuments);
      await txn.delete(DatabaseTables.tableStockMovements);
      await txn.delete(DatabaseTables.tableInventoryItems);
      await txn.delete(DatabaseTables.tableParties);
      await txn.delete(DatabaseTables.tableAuditLogs);
      await txn.delete(DatabaseTables.tableDeletedRecords);
      await txn.delete(DatabaseTables.tableWorkerPayments);
      await txn.delete(DatabaseTables.tableMachineKataiEntries);
      await txn.delete(DatabaseTables.tableWorkerAttendance);
      await txn.delete(DatabaseTables.tableWorkers);
      await txn.execute('PRAGMA foreign_keys = ON;');
    });
  }
}
