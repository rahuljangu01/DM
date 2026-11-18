import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/transaction.dart';
import '../services/firebase_sync_service.dart';
import 'party_repository.dart';

class TransactionRepository {
  final DatabaseHelper _dbHelper;
  final PartyRepository _partyRepo;

  TransactionRepository({DatabaseHelper? dbHelper, PartyRepository? partyRepo})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _partyRepo = partyRepo ?? PartyRepository(dbHelper: dbHelper ?? DatabaseHelper.instance);

  /// Create transaction and update party balance + document allocation
  Future<int> insertTransaction(BusinessTransaction tx, {int? allocatedDocId}) async {
    final txId = await _dbHelper.runTransaction<int>((txn) async {
      // 1. Insert transaction record
      final txId = await txn.insert(
        DatabaseTables.tableTransactions,
        tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      // 2. If allocated to a specific document, link and update document paid amounts
      final targetDocId = allocatedDocId ?? tx.relatedDocId;
      if (targetDocId != null) {
        await txn.insert(DatabaseTables.tableTransactionAllocations, {
          'transaction_id': txId,
          'document_id': targetDocId,
          'allocated_amount_paise': tx.amountPaise,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Update document remaining balance & payment status
        final docRows = await txn.query(
          DatabaseTables.tableDocuments,
          where: 'id = ?',
          whereArgs: [targetDocId],
          limit: 1,
        );

        if (docRows.isNotEmpty) {
          final doc = docRows.first;
          final grandTotal = (doc['grand_total_paise'] as num).toInt();
          final currentPaid = (doc['paid_amount_paise'] as num).toInt();
          final newPaid = (currentPaid + tx.amountPaise).clamp(0, grandTotal);
          final newRemaining = (grandTotal - newPaid).clamp(0, grandTotal);
          final status = newPaid >= grandTotal ? 'paid' : 'partial';

          await txn.update(
            DatabaseTables.tableDocuments,
            {
              'paid_amount_paise': newPaid,
              'remaining_balance_paise': newRemaining,
              'payment_status': status,
            },
            where: 'id = ?',
            whereArgs: [targetDocId],
          );
        }
      }

      // 3. Audit log
      await txn.insert(DatabaseTables.tableAuditLogs, {
        'entity_type': 'PAYMENT',
        'entity_id': txId,
        'action': 'CREATE',
        'details': 'Recorded ${tx.transactionType.toUpperCase()}: ₹ ${(tx.amountPaise / 100).toStringAsFixed(2)} via ${tx.paymentMethod}',
        'created_at': DateTime.now().toIso8601String(),
      });

      return txId;
    });

    // Update party balance if party involved
    if (tx.partyId != null) {
      await _partyRepo.recalculatePartyBalance(tx.partyId!);
    }

    // Push transaction to Firebase in real-time
    final txData = tx.toMap();
    txData['id'] = txId;
    FirebaseSyncService().pushSingleRecord(
      collection: 'transactions',
      id: txId.toString(),
      data: txData,
    ).catchError((_) => false);

    return txId;
  }

  /// List transactions with optional date range, type, party filter
  Future<List<BusinessTransaction>> getTransactions({
    String? startDate,
    String? endDate,
    String? type,
    int? partyId,
    String? paymentMethod,
    String? searchQuery,
    int? limit,
  }) async {
    final db = await _dbHelper.database;
    String sql = '''
      SELECT t.*, p.name as party_name, d.doc_number as related_doc_number
      FROM ${DatabaseTables.tableTransactions} t
      LEFT JOIN ${DatabaseTables.tableParties} p ON t.party_id = p.id
      LEFT JOIN ${DatabaseTables.tableDocuments} d ON t.related_doc_id = d.id
      WHERE 1=1
    ''';
    final List<dynamic> args = [];

    if (startDate != null && startDate.isNotEmpty) {
      sql += ' AND t.transaction_date >= ?';
      args.add(startDate);
    }

    if (endDate != null && endDate.isNotEmpty) {
      sql += ' AND t.transaction_date <= ?';
      args.add(endDate);
    }

    if (type != null && type != 'all') {
      sql += ' AND t.transaction_type = ?';
      args.add(type);
    }

    if (partyId != null) {
      sql += ' AND t.party_id = ?';
      args.add(partyId);
    }

    if (paymentMethod != null && paymentMethod != 'all') {
      sql += ' AND t.payment_method = ?';
      args.add(paymentMethod);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      sql += ' AND (p.name LIKE ? OR t.notes LIKE ? OR t.expense_category LIKE ?)';
      final q = '%${searchQuery.trim()}%';
      args.addAll([q, q, q]);
    }

    sql += ' ORDER BY t.transaction_date DESC, t.id DESC';

    if (limit != null) {
      sql += ' LIMIT ?';
      args.add(limit);
    }

    final results = await db.rawQuery(sql, args);
    return results.map((m) => BusinessTransaction.fromMap(m)).toList();
  }

  /// Calculates net liquid cash and bank balances
  Future<Map<String, double>> getLiquidBalances() async {
    final db = await _dbHelper.database;
    final txs = await db.query(DatabaseTables.tableTransactions);

    int cashPaise = 0;
    int bankPaise = 0;

    for (final tx in txs) {
      final type = tx['transaction_type'] as String;
      final amount = (tx['amount_paise'] as num).toInt();
      final method = tx['payment_method'] as String? ?? 'cash';
      final isCashMethod = method == 'cash';

      switch (type) {
        case 'customer_receipt':
        case 'other_income':
        case 'owner_capital':
          if (isCashMethod) {
            cashPaise += amount;
          } else {
            bankPaise += amount;
          }
          break;

        case 'supplier_payment':
        case 'expense':
        case 'owner_withdrawal':
          if (isCashMethod) {
            cashPaise -= amount;
          } else {
            bankPaise -= amount;
          }
          break;

        case 'cash_to_bank':
          cashPaise -= amount;
          bankPaise += amount;
          break;

        case 'bank_to_cash':
          bankPaise -= amount;
          cashPaise += amount;
          break;
      }
    }

    return {
      'cash': cashPaise / 100.0,
      'bank': bankPaise / 100.0,
      'total': (cashPaise + bankPaise) / 100.0,
    };
  }

  /// Delete transaction and adjust party balance
  Future<void> deleteTransaction(int txId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseTables.tableTransactions,
      where: 'id = ?',
      whereArgs: [txId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final partyId = rows.first['party_id'] as int?;
    final txMap = rows.first;

    // Save to local deleted_records (Recycle Bin)
    final amountPaise = (txMap['amount_paise'] as int?) ?? 0;
    await db.insert(
      DatabaseTables.tableDeletedRecords,
      {
        'entity_type': 'transaction',
        'entity_id': txId,
        'title': 'Payment #$txId',
        'subtitle': '₹${(amountPaise / 100).toStringAsFixed(2)} • ${txMap['payment_mode'] ?? 'Cash/UPI'}',
        'details_json': jsonEncode(txMap),
        'deleted_at': DateTime.now().toIso8601String(),
        'is_restored': 0,
      },
    );

    // Archive in Firebase Firestore "deleted_records" folder!
    FirebaseSyncService().archiveDeletedRecord(
      entityType: 'transaction',
      entityId: txId,
      title: 'Payment #$txId',
      subtitle: '₹${(amountPaise / 100).toStringAsFixed(2)}',
      data: txMap,
    ).catchError((_) => false);

    await db.delete(
      DatabaseTables.tableTransactions,
      where: 'id = ?',
      whereArgs: [txId],
    );

    await db.insert(DatabaseTables.tableAuditLogs, {
      'entity_type': 'PAYMENT',
      'entity_id': txId,
      'action': 'DELETE',
      'details': 'Deleted payment transaction #$txId',
      'created_at': DateTime.now().toIso8601String(),
    });

    if (partyId != null) {
      await _partyRepo.recalculatePartyBalance(partyId);
    }
  }
}
