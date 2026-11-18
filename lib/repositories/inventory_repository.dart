import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/inventory_item.dart';
import '../services/audit_service.dart';
import '../services/firebase_sync_service.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper;

  InventoryRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<int> insertItem(InventoryItem item) async {
    final db = await _dbHelper.database;
    final id = await db.insert(
      DatabaseTables.tableInventoryItems,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // If opening stock > 0, log opening stock movement
    if (item.openingQuantity > 0) {
      await db.insert(DatabaseTables.tableStockMovements, {
        'item_id': id,
        'movement_date': DateTime.now().toIso8601String().substring(0, 10),
        'movement_type': 'opening',
        'quantity': item.openingQuantity,
        'unit_rate_paise': item.purchaseRatePaise,
        'notes': 'Initial opening stock',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    await AuditService.instance.log(
      entityType: 'INVENTORY',
      entityId: id,
      action: 'CREATE',
      details: 'Added design ${item.designCode} (${item.itemName})',
    );

    final cData = item.toMap();
    cData['id'] = id;
    FirebaseSyncService().pushSingleRecord(collection: 'catalog', id: id.toString(), data: cData).catchError((_) => false);

    return id;
  }

  Future<int> updateItem(InventoryItem item) async {
    final db = await _dbHelper.database;
    final res = await db.update(
      DatabaseTables.tableInventoryItems,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );

    if (item.id != null) {
      await AuditService.instance.log(
        entityType: 'INVENTORY',
        entityId: item.id,
        action: 'UPDATE',
        details: 'Updated design ${item.designCode}',
      );
      FirebaseSyncService().pushSingleRecord(collection: 'catalog', id: item.id.toString(), data: item.toMap()).catchError((_) => false);
    }
    return res;
  }

  Future<int> updateItemImage(int id, String? imagePath, {String? imageBase64, String? imageUrl}) async {
    final db = await _dbHelper.database;
    final data = <String, dynamic>{'image_path': imagePath};
    if (imageBase64 != null) data['image_base64'] = imageBase64;
    if (imageUrl != null) data['image_url'] = imageUrl;
    return await db.update(
      DatabaseTables.tableInventoryItems,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await _dbHelper.database;
    final res = await db.update(
      DatabaseTables.tableInventoryItems,
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    await AuditService.instance.log(
      entityType: 'INVENTORY',
      entityId: id,
      action: 'DELETE',
      details: 'Deleted/archived design item #$id',
    );
    return res;
  }

  Future<void> deleteItems(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _dbHelper.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE ${DatabaseTables.tableInventoryItems} SET is_active = 0 WHERE id IN ($placeholders)',
      ids,
    );

    await AuditService.instance.log(
      entityType: 'INVENTORY',
      action: 'DELETE',
      details: 'Deleted ${ids.length} design items',
    );
  }

  Future<List<InventoryItem>> getItems({String? searchQuery, bool onlyLowStock = false}) async {
    final db = await _dbHelper.database;
    String whereClause = 'is_active = 1';
    final List<dynamic> args = [];

    if (onlyLowStock) {
      whereClause += ' AND current_stock <= low_stock_warning_qty';
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause += ' AND (item_name LIKE ? OR design_code LIKE ?)';
      args.add('%${searchQuery.trim()}%');
      args.add('%${searchQuery.trim()}%');
    }

    final results = await db.query(
      DatabaseTables.tableInventoryItems,
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'item_name ASC',
    );

    return results.map((m) => InventoryItem.fromMap(m)).toList();
  }

  Future<InventoryItem?> getItemById(int id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseTables.tableInventoryItems,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return InventoryItem.fromMap(results.first);
  }

  Future<void> adjustStock({
    required int itemId,
    required double adjustedQty,
    required String reason,
  }) async {
    final item = await getItemById(itemId);
    if (item == null) return;

    final db = await _dbHelper.database;
    final diff = adjustedQty - item.currentStock;

    await db.transaction((txn) async {
      await txn.update(
        DatabaseTables.tableInventoryItems,
        {'current_stock': adjustedQty},
        where: 'id = ?',
        whereArgs: [itemId],
      );

      await txn.insert(DatabaseTables.tableStockMovements, {
        'item_id': itemId,
        'movement_date': DateTime.now().toIso8601String().substring(0, 10),
        'movement_type': 'adjustment',
        'quantity': diff,
        'unit_rate_paise': item.purchaseRatePaise,
        'notes': 'Manual adjustment: $reason',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  /// KPI Summary Stats for Stock & Catalog Module Dashboard
  Future<Map<String, dynamic>> getInventorySummaryStats() async {
    final db = await _dbHelper.database;
    final items = await db.query(
      DatabaseTables.tableInventoryItems,
      where: 'is_active = 1',
    );

    double totalQty = 0.0;
    double totalValuation = 0.0;
    int lowStockCount = 0;

    for (final m in items) {
      final stock = (m['current_stock'] as num?)?.toDouble() ?? 0.0;
      final ratePaise = (m['sale_rate_paise'] as num?)?.toInt() ?? 0;
      final warnQty = (m['low_stock_warning_qty'] as num?)?.toDouble() ?? 5.0;

      totalQty += stock;
      totalValuation += (stock * (ratePaise / 100.0));
      if (stock <= warnQty) {
        lowStockCount++;
      }
    }

    return {
      'totalItems': items.length,
      'totalQuantity': totalQty,
      'totalValuationRupees': totalValuation,
      'lowStockCount': lowStockCount,
    };
  }
}
