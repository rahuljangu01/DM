import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/share_helper.dart';

class BackupService {
  final DatabaseHelper _dbHelper;

  BackupService({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Export all tables to a verified JSON backup string
  Future<String> createBackupJson() async {
    final db = await _dbHelper.database;

    final parties = await db.query(DatabaseTables.tableParties);
    final documents = await db.query(DatabaseTables.tableDocuments);
    final documentItems = await db.query(DatabaseTables.tableDocumentItems);
    final transactions = await db.query(DatabaseTables.tableTransactions);
    final allocations = await db.query(DatabaseTables.tableTransactionAllocations);
    final inventory = await db.query(DatabaseTables.tableInventoryItems);
    final stockMovements = await db.query(DatabaseTables.tableStockMovements);
    final settings = await db.query(DatabaseTables.tableAppSettings);
    final workers = await db.query(DatabaseTables.tableWorkers);
    final attendance = await db.query(DatabaseTables.tableWorkerAttendance);
    final kataiEntries = await db.query(DatabaseTables.tableMachineKataiEntries);
    final workerPayments = await db.query(DatabaseTables.tableWorkerPayments);
    final deletedRecords = await db.query(DatabaseTables.tableDeletedRecords);
    final appUsers = await db.query(DatabaseTables.tableAppUsers);

    final payload = {
      'app': 'DM Lace Surat',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'data': {
        DatabaseTables.tableParties: parties,
        DatabaseTables.tableDocuments: documents,
        DatabaseTables.tableDocumentItems: documentItems,
        DatabaseTables.tableTransactions: transactions,
        DatabaseTables.tableTransactionAllocations: allocations,
        DatabaseTables.tableInventoryItems: inventory,
        DatabaseTables.tableStockMovements: stockMovements,
        DatabaseTables.tableAppSettings: settings,
        DatabaseTables.tableWorkers: workers,
        DatabaseTables.tableWorkerAttendance: attendance,
        DatabaseTables.tableMachineKataiEntries: kataiEntries,
        DatabaseTables.tableWorkerPayments: workerPayments,
        DatabaseTables.tableDeletedRecords: deletedRecords,
        DatabaseTables.tableAppUsers: appUsers,
      },
    };

    final rawJson = jsonEncode(payload);
    final checksum = sha256.convert(utf8.encode(rawJson)).toString();

    final wrappedBackup = {
      'checksum': checksum,
      'payload': payload,
    };

    return jsonEncode(wrappedBackup);
  }

  /// Export and share backup file to WhatsApp, Google Drive, Email or Device Storage
  Future<void> exportAndShareBackup() async {
    final jsonStr = await createBackupJson();
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final filename = 'DM_Lace_Backup_$dateStr.json';

    try {
      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/$filename');
      await backupFile.writeAsString(jsonStr);

      await ShareHelper.shareImageWithText(
        imagePath: backupFile.path,
        text: '👑 DM LACE SURAT • सुरक्षित डेटाबेस बैकअप ($dateStr)\n\nइस बैकअप फ़ाइल को Google Drive, WhatsApp या ईमेल पर सुरक्षित रखें। नया फ़ोन लेने पर इसी फ़ाइल से 1-क्लिक में पूरा डेटा रिस्टोर हो जाएगा।',
        subject: filename,
      );
    } catch (_) {
      // Fallback to text sharing if file writing is unavailable
      await ShareHelper.shareText(jsonStr, subject: filename);
    }
  }

  /// Validate backup format and integrity
  Map<String, dynamic>? validateBackup(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return null;

      if (!decoded.containsKey('checksum') || !decoded.containsKey('payload')) {
        return null;
      }

      final payload = decoded['payload'] as Map<String, dynamic>;
      final rawPayloadJson = jsonEncode(payload);
      final computedChecksum = sha256.convert(utf8.encode(rawPayloadJson)).toString();

      if (computedChecksum != decoded['checksum']) {
        return null; // Tampered or corrupted backup
      }

      if (payload['app'] != 'DM Lace Surat') {
        return null;
      }

      return payload;
    } catch (_) {
      return null;
    }
  }

  /// Restore validated backup into SQLite database
  Future<bool> restoreBackup(String jsonStr) async {
    final payload = validateBackup(jsonStr);
    if (payload == null) return false;

    final data = payload['data'] as Map<String, dynamic>;

    await _dbHelper.wipeDatabase();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Independent parent tables
      final parties = List<Map<String, dynamic>>.from(data[DatabaseTables.tableParties] ?? []);
      for (final p in parties) {
        await txn.insert(DatabaseTables.tableParties, p, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final inventory = List<Map<String, dynamic>>.from(data[DatabaseTables.tableInventoryItems] ?? []);
      for (final i in inventory) {
        await txn.insert(DatabaseTables.tableInventoryItems, i, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 2. Documents (references parties)
      final documents = List<Map<String, dynamic>>.from(data[DatabaseTables.tableDocuments] ?? []);
      for (final d in documents) {
        await txn.insert(DatabaseTables.tableDocuments, d, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 3. Document items (references documents and inventory)
      final docItems = List<Map<String, dynamic>>.from(data[DatabaseTables.tableDocumentItems] ?? []);
      for (final di in docItems) {
        await txn.insert(DatabaseTables.tableDocumentItems, di, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 4. Transactions (references parties and documents)
      final transactions = List<Map<String, dynamic>>.from(data[DatabaseTables.tableTransactions] ?? []);
      for (final t in transactions) {
        await txn.insert(DatabaseTables.tableTransactions, t, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 5. Transaction allocations (references transactions and documents)
      final allocations = List<Map<String, dynamic>>.from(data[DatabaseTables.tableTransactionAllocations] ?? []);
      for (final a in allocations) {
        await txn.insert(DatabaseTables.tableTransactionAllocations, a, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 6. Stock movements (references inventory and documents)
      final stock = List<Map<String, dynamic>>.from(data[DatabaseTables.tableStockMovements] ?? []);
      for (final s in stock) {
        await txn.insert(DatabaseTables.tableStockMovements, s, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 7. Settings
      final settings = List<Map<String, dynamic>>.from(data[DatabaseTables.tableAppSettings] ?? []);
      for (final st in settings) {
        await txn.insert(DatabaseTables.tableAppSettings, st, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 8. Workers (Karigar)
      final workers = List<Map<String, dynamic>>.from(data[DatabaseTables.tableWorkers] ?? []);
      for (final w in workers) {
        await txn.insert(DatabaseTables.tableWorkers, w, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 9. Worker Attendance
      final attendance = List<Map<String, dynamic>>.from(data[DatabaseTables.tableWorkerAttendance] ?? []);
      for (final a in attendance) {
        await txn.insert(DatabaseTables.tableWorkerAttendance, a, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 10. Machine Katai Production Entries
      final katai = List<Map<String, dynamic>>.from(data[DatabaseTables.tableMachineKataiEntries] ?? []);
      for (final k in katai) {
        await txn.insert(DatabaseTables.tableMachineKataiEntries, k, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 11. Worker Payments
      final workerPayments = List<Map<String, dynamic>>.from(data[DatabaseTables.tableWorkerPayments] ?? []);
      for (final wp in workerPayments) {
        await txn.insert(DatabaseTables.tableWorkerPayments, wp, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 12. Recycle Bin Deleted Records
      final deleted = List<Map<String, dynamic>>.from(data[DatabaseTables.tableDeletedRecords] ?? []);
      for (final dr in deleted) {
        await txn.insert(DatabaseTables.tableDeletedRecords, dr, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 13. App Users
      final appUsers = List<Map<String, dynamic>>.from(data[DatabaseTables.tableAppUsers] ?? []);
      for (final u in appUsers) {
        await txn.insert(DatabaseTables.tableAppUsers, u, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    return true;
  }
}
