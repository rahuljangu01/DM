import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/party.dart';
import '../services/audit_service.dart';
import '../services/firebase_sync_service.dart';

class PartyRepository {
  final DatabaseHelper _dbHelper;

  PartyRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<int> insertParty(Party party) async {
    final db = await _dbHelper.database;
    final id = await db.insert(
      DatabaseTables.tableParties,
      party.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await recalculatePartyBalance(id);
    await AuditService.instance.log(
      entityType: 'PARTY',
      entityId: id,
      action: 'CREATE',
      details: 'Added ${party.type}: ${party.name}',
    );
    FirebaseSyncService().pushSingleParty(party.copyWith(id: id).toMap(), id).catchError((_) => false);
    return id;
  }

  Future<int> updateParty(Party party) async {
    final db = await _dbHelper.database;
    final count = await db.update(
      DatabaseTables.tableParties,
      party.toMap(),
      where: 'id = ?',
      whereArgs: [party.id],
    );
    if (party.id != null) {
      await recalculatePartyBalance(party.id!);
      await AuditService.instance.log(
        entityType: 'PARTY',
        entityId: party.id,
        action: 'UPDATE',
        details: 'Updated ${party.name}',
      );
      FirebaseSyncService().pushSingleParty(party.toMap(), party.id!).catchError((_) => false);
    }
    return count;
  }

  Future<Party?> getPartyById(int id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseTables.tableParties,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Party.fromMap(results.first);
  }

  Future<List<Party>> getAllParties({
    String? type,
    String? searchQuery,
    bool includeArchived = false,
  }) async {
    final db = await _dbHelper.database;
    String whereClause = includeArchived ? '1=1' : 'is_archived = 0';
    final List<dynamic> whereArgs = [];

    if (type != null && type != 'all') {
      if (type == 'customer') {
        whereClause += ' AND (type IN ("customer", "wholesaler", "retailer", "both"))';
      } else if (type == 'supplier') {
        whereClause += ' AND (type IN ("supplier", "manufacturer", "material", "both"))';
      } else {
        whereClause += ' AND (type = ? OR type = "both")';
        whereArgs.add(type);
      }
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause += ' AND (name LIKE ? OR phone LIKE ?)';
      whereArgs.add('%${searchQuery.trim()}%');
      whereArgs.add('%${searchQuery.trim()}%');
    }

    final results = await db.query(
      DatabaseTables.tableParties,
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    return results.map((m) => Party.fromMap(m)).toList();
  }

  /// Check whether party can be deleted (prevent accidental deletion if transactions or bills exist)
  Future<bool> canDeleteParty(int partyId) async {
    final db = await _dbHelper.database;
    final docCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseTables.tableDocuments} WHERE party_id = ?',
      [partyId],
    )) ?? 0;

    final txCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseTables.tableTransactions} WHERE party_id = ?',
      [partyId],
    )) ?? 0;

    return docCount == 0 && txCount == 0;
  }

  /// Delete or archive party with automatic Recycle Bin & Firebase archive
  Future<bool> deleteParty(int partyId) async {
    final db = await _dbHelper.database;
    final party = await getPartyById(partyId);

    // Save to local deleted_records (Recycle Bin)
    if (party != null) {
      await db.insert(
        DatabaseTables.tableDeletedRecords,
        {
          'entity_type': 'party',
          'entity_id': partyId,
          'title': party.name,
          'subtitle': party.phone ?? party.address ?? '',
          'details_json': jsonEncode(party.toMap()),
          'deleted_at': DateTime.now().toIso8601String(),
          'is_restored': 0,
        },
      );

      // Archive in Firebase Firestore "deleted_records" folder!
      FirebaseSyncService().archiveDeletedRecord(
        entityType: 'party',
        entityId: partyId,
        title: party.name,
        subtitle: party.phone ?? party.address,
        data: party.toMap(),
      ).catchError((_) => false);
    }

    final canDelete = await canDeleteParty(partyId);
    if (!canDelete) {
      // Soft-delete by archiving
      await db.update(
        DatabaseTables.tableParties,
        {'is_archived': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [partyId],
      );
      await AuditService.instance.log(
        entityType: 'PARTY',
        entityId: partyId,
        action: 'DELETE',
        details: 'Archived party #$partyId (bills/payments exist)',
      );
      return false; // Indicating archived rather than permanently removed
    }

    await db.delete(
      DatabaseTables.tableParties,
      where: 'id = ?',
      whereArgs: [partyId],
    );
    await AuditService.instance.log(
      entityType: 'PARTY',
      entityId: partyId,
      action: 'DELETE',
      details: 'Permanently deleted party #$partyId',
    );
    return true;
  }

  /// Restore party from Recycle Bin
  Future<bool> restorePartyFromTrash(int recordId) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      DatabaseTables.tableDeletedRecords,
      where: 'id = ?',
      whereArgs: [recordId],
    );
    if (res.isEmpty) return false;
    final row = res.first;
    final jsonStr = row['details_json'] as String;
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    data.remove('id');
    data['is_archived'] = 0;
    final newId = await insertParty(Party.fromMap(data));
    await db.update(
      DatabaseTables.tableDeletedRecords,
      {'is_restored': 1},
      where: 'id = ?',
      whereArgs: [recordId],
    );
    return newId > 0;
  }

  /// Recalculates live party balance based on opening balance, bills, and payments
  Future<int> recalculatePartyBalance(int partyId) async {
    final db = await _dbHelper.database;
    final partyMap = await getPartyById(partyId);
    if (partyMap == null) return 0;

    // Base opening balance (positive for receivable, negative for payable)
    int baseBalance = partyMap.balanceType == 'receivable'
        ? partyMap.openingBalancePaise
        : -partyMap.openingBalancePaise;

    // Total sales bills (kaccha_bill or tax_invoice, NOT delivery challans, NOT cancelled)
    final billTotalResult = await db.rawQuery('''
      SELECT SUM(grand_total_paise) as total
      FROM ${DatabaseTables.tableDocuments}
      WHERE party_id = ? AND doc_type IN ('kaccha_bill', 'tax_invoice') AND is_cancelled = 0
    ''', [partyId]);
    final billedSales = (billTotalResult.first['total'] as num?)?.toInt() ?? 0;

    // Total purchase bills from suppliers (increases payable)
    final purchaseTotalResult = await db.rawQuery('''
      SELECT SUM(grand_total_paise) as total
      FROM ${DatabaseTables.tableDocuments}
      WHERE party_id = ? AND doc_type = 'purchase_bill' AND is_cancelled = 0
    ''', [partyId]);
    final billedPurchases = (purchaseTotalResult.first['total'] as num?)?.toInt() ?? 0;

    // Total customer receipts
    final receiptsResult = await db.rawQuery('''
      SELECT SUM(amount_paise) as total
      FROM ${DatabaseTables.tableTransactions}
      WHERE party_id = ? AND transaction_type = 'customer_receipt'
    ''', [partyId]);
    final receipts = (receiptsResult.first['total'] as num?)?.toInt() ?? 0;

    // Total supplier payments made by us (reduces payable)
    final supplierPaymentsResult = await db.rawQuery('''
      SELECT SUM(amount_paise) as total
      FROM ${DatabaseTables.tableTransactions}
      WHERE party_id = ? AND transaction_type = 'supplier_payment'
    ''', [partyId]);
    final supplierPayments = (supplierPaymentsResult.first['total'] as num?)?.toInt() ?? 0;

    // Net balance: positive = business has to collect (Receivable), negative = business has to pay (Payable)
    final netBalance = baseBalance + billedSales - receipts - billedPurchases + supplierPayments;

    await db.update(
      DatabaseTables.tableParties,
      {
        'current_balance_paise': netBalance,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [partyId],
    );

    return netBalance;
  }

  /// Get party ledger entries in chronological order
  Future<List<Map<String, dynamic>>> getPartyLedger(int partyId) async {
    final db = await _dbHelper.database;
    final party = await getPartyById(partyId);
    if (party == null) return [];

    final List<Map<String, dynamic>> ledger = [];

    // 1. Opening Balance entry
    if (party.openingBalancePaise > 0) {
      ledger.add({
        'date': party.createdAt,
        'description': 'Opening Balance (${party.balanceType.toUpperCase()})',
        'type': party.balanceType == 'receivable' ? 'debit' : 'credit',
        'debit_paise': party.balanceType == 'receivable' ? party.openingBalancePaise : 0,
        'credit_paise': party.balanceType == 'payable' ? party.openingBalancePaise : 0,
        'ref_doc': 'OPENING',
      });
    }

    // 2. Documents (Bills & Challans)
    final docs = await db.query(
      DatabaseTables.tableDocuments,
      where: 'party_id = ? AND is_cancelled = 0',
      whereArgs: [partyId],
      orderBy: 'doc_date ASC',
    );

    for (final doc in docs) {
      final docType = doc['doc_type'] as String;
      final docNum = doc['doc_number'] as String;
      final total = (doc['grand_total_paise'] as num).toInt();
      final date = doc['doc_date'] as String;

      if (docType == 'challan') {
        ledger.add({
          'date': date,
          'description': 'Delivery Challan: $docNum (Material Dispatch)',
          'type': 'challan',
          'debit_paise': 0,
          'credit_paise': 0,
          'ref_doc': docNum,
          'is_challan': true,
        });
      } else {
        // Sales bill increases receivable (Debit to party ledger)
        ledger.add({
          'date': date,
          'description': docType == 'kaccha_bill' ? 'Kaccha Bill #$docNum' : 'Tax Invoice #$docNum',
          'type': 'debit',
          'debit_paise': total,
          'credit_paise': 0,
          'ref_doc': docNum,
        });
      }
    }

    // 3. Transactions (Receipts & Payments)
    final txs = await db.query(
      DatabaseTables.tableTransactions,
      where: 'party_id = ?',
      whereArgs: [partyId],
      orderBy: 'transaction_date ASC',
    );

    for (final tx in txs) {
      final txType = tx['transaction_type'] as String;
      final amount = (tx['amount_paise'] as num).toInt();
      final date = tx['transaction_date'] as String;
      final method = (tx['payment_method'] as String).toUpperCase();
      final ref = tx['reference_number'] as String?;

      if (txType == 'customer_receipt') {
        ledger.add({
          'date': date,
          'description': 'Payment Received [$method] ${ref != null ? "Ref: $ref" : ""}',
          'type': 'credit',
          'debit_paise': 0,
          'credit_paise': amount,
          'ref_doc': ref ?? 'RECEIPT',
        });
      } else if (txType == 'supplier_payment') {
        ledger.add({
          'date': date,
          'description': 'Payment Made [$method] ${ref != null ? "Ref: $ref" : ""}',
          'type': 'debit',
          'debit_paise': amount,
          'credit_paise': 0,
          'ref_doc': ref ?? 'PAYMENT',
        });
      }
    }

    // Sort all entries chronologically
    ledger.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    // Calculate running balance
    int running = 0;
    for (final item in ledger) {
      if (item['is_challan'] == true) {
        item['running_balance_paise'] = running;
        continue;
      }
      final debit = item['debit_paise'] as int;
      final credit = item['credit_paise'] as int;
      running += (debit - credit);
      item['running_balance_paise'] = running;
    }

    return ledger;
  }

  /// Summary statistics for the Parties & Khata Module Dashboard
  Future<Map<String, dynamic>> getPartySummaryStats() async {
    final db = await _dbHelper.database;
    final parties = await db.query(
      DatabaseTables.tableParties,
      where: 'is_archived = 0',
    );

    int receivablePaise = 0;
    int payablePaise = 0;
    int count = parties.length;
    int receivablePartiesCount = 0;
    int payablePartiesCount = 0;
    int settledPartiesCount = 0;

    for (final p in parties) {
      final bal = (p['current_balance_paise'] as num?)?.toInt() ?? 0;
      if (bal > 0) {
        receivablePaise += bal;
        receivablePartiesCount++;
      } else if (bal < 0) {
        payablePaise += bal.abs();
        payablePartiesCount++;
      } else {
        settledPartiesCount++;
      }
    }

    // Overdue count from unpaid/partial documents past due date
    final now = DateTime.now().toIso8601String().substring(0, 10);
    final overdueResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT party_id) as overdue_count
      FROM ${DatabaseTables.tableDocuments}
      WHERE doc_type IN ('kaccha_bill', 'tax_invoice')
        AND payment_status IN ('unpaid', 'partial')
        AND is_cancelled = 0
        AND due_date IS NOT NULL
        AND due_date < ?
    ''', [now]);

    final overduePartiesCount = (overdueResult.first['overdue_count'] as num?)?.toInt() ?? 0;

    return {
      'totalParties': count,
      'receivableRupees': receivablePaise / 100.0,
      'payableRupees': payablePaise / 100.0,
      'overduePartiesCount': overduePartiesCount,
      'receivablePartiesCount': receivablePartiesCount,
      'payablePartiesCount': payablePartiesCount,
      'settledPartiesCount': settledPartiesCount,
    };
  }
}
