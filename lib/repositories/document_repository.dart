import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../services/firebase_sync_service.dart';
import 'party_repository.dart';

class DocumentRepository {
  final DatabaseHelper _dbHelper;
  final PartyRepository _partyRepo;

  DocumentRepository({DatabaseHelper? dbHelper, PartyRepository? partyRepo})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _partyRepo = partyRepo ?? PartyRepository(dbHelper: dbHelper ?? DatabaseHelper.instance);

  /// Generates next unique document number based on type and current year
  Future<String> generateNextDocNumber(String docType) async {
    final db = await _dbHelper.database;
    final year = DateTime.now().year;
    String prefix;

    switch (docType) {
      case 'challan':
        prefix = 'DC-$year-';
        break;
      case 'tax_invoice':
        prefix = 'INV-$year-';
        break;
      case 'kaccha_bill':
      default:
        prefix = 'KB-$year-';
        break;
    }

    final result = await db.rawQuery(
      'SELECT doc_number FROM ${DatabaseTables.tableDocuments} WHERE doc_number LIKE ? ORDER BY id DESC LIMIT 1',
      ['$prefix%'],
    );

    int nextNum = 1;
    if (result.isNotEmpty) {
      final lastNumStr = (result.first['doc_number'] as String).replaceFirst(prefix, '');
      final parsed = int.tryParse(lastNumStr);
      if (parsed != null) {
        nextNum = parsed + 1;
      }
    }

    // Double-check candidate against the entire database so conflicts never occur
    while (true) {
      final candidate = '$prefix${nextNum.toString().padLeft(4, '0')}';
      final exists = await db.rawQuery(
        'SELECT 1 FROM ${DatabaseTables.tableDocuments} WHERE doc_number = ? OR doc_number = ? LIMIT 1',
        [candidate, 'CH-$candidate'],
      );
      if (exists.isEmpty) {
        return candidate;
      }
      nextNum++;
    }
  }

  /// Create a new document with line items and optional immediate advance payment
  Future<int> createDocument(BusinessDocument doc, {int advancePaymentPaise = 0, String paymentMethod = 'cash'}) async {
    final docId = await _dbHelper.runTransaction<int>((txn) async {
      // 1. Calculate grand totals from items if present, or fallback to doc totals
      int subtotal = 0;
      int totalTax = 0;
      if (doc.items.isNotEmpty) {
        for (final item in doc.items) {
          subtotal += item.taxableAmountPaise;
          totalTax += (item.lineTotalPaise - item.taxableAmountPaise);
        }
      } else {
        subtotal = doc.subtotalPaise > 0 ? doc.subtotalPaise : doc.grandTotalPaise;
        totalTax = doc.taxPaise;
      }
      final grandTotal = (doc.items.isNotEmpty
              ? (subtotal + totalTax - doc.discountPaise)
              : (doc.grandTotalPaise > 0 ? doc.grandTotalPaise : subtotal + totalTax - doc.discountPaise))
          .clamp(0, 999999999);
      final paid = advancePaymentPaise.clamp(0, grandTotal);
      final balance = grandTotal - paid;
      final status = paid >= grandTotal ? 'paid' : (paid > 0 ? 'partial' : 'unpaid');

      // 2. Insert document record
      final docMap = doc.toMap();
      docMap.remove('id');
      docMap['subtotal_paise'] = subtotal;
      docMap['tax_paise'] = totalTax;
      docMap['grand_total_paise'] = grandTotal;
      docMap['paid_amount_paise'] = paid;
      docMap['remaining_balance_paise'] = balance;
      docMap['payment_status'] = status;

      // Guarantee doc_number uniqueness to prevent SQLite UNIQUE constraint failure
      var finalDocNumber = doc.docNumber;
      final existingCheck = await txn.rawQuery(
        'SELECT 1 FROM ${DatabaseTables.tableDocuments} WHERE doc_number = ? LIMIT 1',
        [finalDocNumber],
      );
      if (existingCheck.isNotEmpty) {
        final countRes = await txn.rawQuery(
          'SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableDocuments}',
        );
        final totalCount = (countRes.first['cnt'] as int? ?? 0) + 1;
        finalDocNumber = '$finalDocNumber-$totalCount';
        docMap['doc_number'] = finalDocNumber;
      }

      final insertedDocId = await txn.insert(
        DatabaseTables.tableDocuments,
        docMap,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      // 3. Insert items
      for (final item in doc.items) {
        final itemMap = item.toMap();
        itemMap.remove('id'); // Always allow auto-increment for new document items
        itemMap['document_id'] = insertedDocId;
        await txn.insert(DatabaseTables.tableDocumentItems, itemMap);

        // If inventory item linked, update inventory stock
        if (item.inventoryItemId != null) {
          // If challan, dispatch stock movement
          // If invoice/bill converted from challan, DO NOT reduce stock again!
          if (!doc.isConvertedFromChallan) {
            await txn.insert(DatabaseTables.tableStockMovements, {
              'item_id': item.inventoryItemId,
              'movement_date': doc.docDate,
              'movement_type': doc.isChallan ? 'challan_dispatch' : 'sale',
              'quantity': item.quantity,
              'unit_rate_paise': item.ratePaise,
              'reference_doc_id': insertedDocId,
              'notes': '${doc.docType.toUpperCase()}: ${doc.docNumber}',
              'created_at': DateTime.now().toIso8601String(),
            });

            // Update item current stock
            await txn.rawUpdate(
              'UPDATE ${DatabaseTables.tableInventoryItems} SET current_stock = current_stock - ?, sales_quantity = sales_quantity + ? WHERE id = ?',
              [item.quantity, item.quantity, item.inventoryItemId],
            );
          }
        }
      }

      // 4. If advance payment made, record transaction
      if (paid > 0) {
        final isPurchaseDoc = doc.tradeType == 'purchase' || doc.docType == 'purchase_bill';
        final txId = await txn.insert(DatabaseTables.tableTransactions, {
          'transaction_date': doc.docDate,
          'party_id': doc.partyId,
          'transaction_type': isPurchaseDoc ? 'supplier_payment' : 'customer_receipt',
          'amount_paise': paid,
          'payment_method': paymentMethod,
          'reference_number': 'ADV-${doc.docNumber}',
          'related_doc_id': insertedDocId,
          'notes': 'Advance payment for ${doc.docNumber}',
          'created_at': DateTime.now().toIso8601String(),
        });

        // Link allocation
        await txn.insert(DatabaseTables.tableTransactionAllocations, {
          'transaction_id': txId,
          'document_id': insertedDocId,
          'allocated_amount_paise': paid,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // 5. Audit log
      await txn.insert(DatabaseTables.tableAuditLogs, {
        'entity_type': 'BILL',
        'entity_id': insertedDocId,
        'action': 'CREATE',
        'details': 'Created ${doc.docType.toUpperCase()}: ${doc.docNumber} for ₹ ${(grandTotal / 100).toStringAsFixed(2)}',
        'created_at': DateTime.now().toIso8601String(),
      });

      return insertedDocId;
    });

    // Recalculate live party balance
    await _partyRepo.recalculatePartyBalance(doc.partyId);

    // Auto-generate Base64 if document has an imagePath but imageBase64 is not populated yet
    String? b64 = doc.imageBase64;
    if ((b64 == null || b64.isEmpty) && doc.imagePath != null && doc.imagePath!.isNotEmpty) {
      try {
        if (doc.imagePath!.startsWith('assets/')) {
          final data = await rootBundle.load(doc.imagePath!);
          b64 = base64Encode(data.buffer.asUint8List());
        } else {
          final f = File(doc.imagePath!);
          if (f.existsSync()) {
            final bytes = await f.readAsBytes();
            if (bytes.length < 800000) {
              b64 = base64Encode(bytes);
            }
          }
        }
        if (b64 != null && b64.isNotEmpty) {
          final db = await _dbHelper.database;
          await db.update(
            DatabaseTables.tableDocuments,
            {'image_base64': b64},
            where: 'id = ?',
            whereArgs: [docId],
          );
        }
      } catch (_) {}
    }

    // Push bill with line items and image to Firebase in real-time
    final billData = doc.toMap();
    billData['id'] = docId;
    if (b64 != null && b64.isNotEmpty) {
      billData['image_base64'] = b64;
    }
    billData['items_json'] = jsonEncode(doc.items.map((i) => i.toMap()).toList());

    FirebaseSyncService().pushSingleRecord(
      collection: 'bills',
      id: docId.toString(),
      data: billData,
    ).catchError((_) => false);

    if (doc.isChallan) {
      FirebaseSyncService().pushSingleRecord(
        collection: 'challans',
        id: docId.toString(),
        data: billData,
      ).catchError((_) => false);
    }

    return docId;
  }

  /// Get document with all line items and party name
  Future<BusinessDocument?> getDocumentById(int id) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT d.*, p.name as party_name
      FROM ${DatabaseTables.tableDocuments} d
      JOIN ${DatabaseTables.tableParties} p ON d.party_id = p.id
      WHERE d.id = ?
      LIMIT 1
    ''', [id]);

    if (results.isEmpty) return null;

    final items = await getDocumentItems(id);
    var doc = BusinessDocument.fromMap(results.first, items: items);

    // If local document lacks image, attempt cloud fetch fallback
    if (!doc.hasImage) {
      try {
        final cloudDoc = await FirebaseSyncService().fetchSingleDocument(id.toString());
        if (cloudDoc != null && cloudDoc['image_base64'] != null) {
          final cloudB64 = cloudDoc['image_base64'] as String;
          if (cloudB64.isNotEmpty) {
            await db.update(
              DatabaseTables.tableDocuments,
              {'image_base64': cloudB64},
              where: 'id = ?',
              whereArgs: [id],
            );
            doc = doc.copyWith(imageBase64: cloudB64);
          }
        }
      } catch (_) {}
    }

    return doc;
  }

  /// Get line items for a document
  Future<List<DocumentItem>> getDocumentItems(int documentId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseTables.tableDocumentItems,
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
    return results.map((m) => DocumentItem.fromMap(m)).toList();
  }

  /// List documents with filters
  Future<List<BusinessDocument>> getDocuments({
    String? docType,
    String? tradeType,
    int? partyId,
    String? status,
    String? searchQuery,
  }) async {
    final db = await _dbHelper.database;
    String sql = '''
      SELECT d.*, p.name as party_name
      FROM ${DatabaseTables.tableDocuments} d
      JOIN ${DatabaseTables.tableParties} p ON d.party_id = p.id
      WHERE 1=1
    ''';
    final List<dynamic> args = [];

    if (docType != null && docType != 'all') {
      sql += ' AND d.doc_type = ?';
      args.add(docType);
    }

    if (tradeType != null && tradeType != 'all') {
      sql += ' AND d.trade_type = ?';
      args.add(tradeType);
    }

    if (partyId != null) {
      sql += ' AND d.party_id = ?';
      args.add(partyId);
    }

    if (status != null && status != 'all') {
      sql += ' AND d.payment_status = ?';
      args.add(status);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      sql += ' AND (d.doc_number LIKE ? OR p.name LIKE ? OR d.notes LIKE ?)';
      args.add('%${searchQuery.trim()}%');
      args.add('%${searchQuery.trim()}%');
      args.add('%${searchQuery.trim()}%');
    }

    sql += ' ORDER BY d.id DESC';

    final results = await db.rawQuery(sql, args);
    return results.map((m) => BusinessDocument.fromMap(m)).toList();
  }

  /// Convert Delivery Challan into a Kaccha Bill or Tax Invoice
  Future<int> convertChallanToInvoice({
    required int challanId,
    required String targetDocType, // 'kaccha_bill' or 'tax_invoice'
    int discountPaise = 0,
    int advancePaymentPaise = 0,
    String paymentMethod = 'cash',
  }) async {
    final original = await getDocumentById(challanId);
    if (original == null) throw Exception('Original challan not found');
    if (!original.isChallan) throw Exception('Document is not a delivery challan');

    final newDocNumber = await generateNextDocNumber(targetDocType);

    final convertedDoc = BusinessDocument(
      docNumber: newDocNumber,
      docType: targetDocType,
      partyId: original.partyId,
      docDate: DateTime.now().toIso8601String().substring(0, 10),
      dueDate: original.dueDate,
      discountPaise: discountPaise,
      isConvertedFromChallan: true,
      originalChallanId: challanId,
      notes: 'Converted from Challan #${original.docNumber}. ${original.notes ?? ""}',
      items: original.items,
    );

    final newDocId = await createDocument(
      convertedDoc,
      advancePaymentPaise: advancePaymentPaise,
      paymentMethod: paymentMethod,
    );

    // Update original challan to note conversion
    final db = await _dbHelper.database;
    await db.update(
      DatabaseTables.tableDocuments,
      {
        'notes': '${original.notes ?? ""}\n[Converted to $targetDocType #$newDocNumber]',
      },
      where: 'id = ?',
      whereArgs: [challanId],
    );

    return newDocId;
  }

  /// Cancel document (with audit log)
  Future<void> cancelDocument(int docId, String reason) async {
    final doc = await getDocumentById(docId);
    if (doc == null) return;

    final db = await _dbHelper.database;
    await db.update(
      DatabaseTables.tableDocuments,
      {
        'is_cancelled': 1,
        'notes': '${doc.notes ?? ""}\n[CANCELLED: $reason]',
      },
      where: 'id = ?',
      whereArgs: [docId],
    );

    // If items had inventory stock movements and was not a conversion, reverse stock movements
    if (!doc.isConvertedFromChallan) {
      for (final item in doc.items) {
        if (item.inventoryItemId != null) {
          await db.rawUpdate(
            'UPDATE ${DatabaseTables.tableInventoryItems} SET current_stock = current_stock + ?, sales_quantity = sales_quantity - ? WHERE id = ?',
            [item.quantity, item.quantity, item.inventoryItemId],
          );
        }
      }
    }

    await db.insert(DatabaseTables.tableAuditLogs, {
      'entity_type': 'BILL',
      'entity_id': docId,
      'action': 'DELETE',
      'details': 'Cancelled ${doc.docNumber}: $reason',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Save to local deleted_records (Recycle Bin)
    await db.insert(
      DatabaseTables.tableDeletedRecords,
      {
        'entity_type': 'bill',
        'entity_id': docId,
        'title': doc.docNumber,
        'subtitle': '₹${(doc.grandTotalPaise / 100).toStringAsFixed(2)} • ${doc.docType.toUpperCase()}',
        'details_json': jsonEncode(doc.toMap()),
        'deleted_at': DateTime.now().toIso8601String(),
        'is_restored': 0,
      },
    );

    // Archive in Firebase Firestore "deleted_records" folder!
    FirebaseSyncService().archiveDeletedRecord(
      entityType: 'bill',
      entityId: docId,
      title: doc.docNumber,
      subtitle: '₹${(doc.grandTotalPaise / 100).toStringAsFixed(2)}',
      data: doc.toMap(),
    ).catchError((_) => false);

    await _partyRepo.recalculatePartyBalance(doc.partyId);
  }
}
