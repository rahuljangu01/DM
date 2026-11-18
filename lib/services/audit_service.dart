import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';

class AuditLogEntry {
  final int? id;
  final String entityType; // 'PARTY', 'BILL', 'PAYMENT', 'INVENTORY', 'SECURITY', 'SYSTEM'
  final int? entityId;
  final String action;     // 'CREATE', 'UPDATE', 'DELETE', 'PIN_ENABLE', 'PIN_DISABLE', 'BACKUP_EXPORT'
  final String? details;
  final String createdAt;

  AuditLogEntry({
    this.id,
    required this.entityType,
    this.entityId,
    required this.action,
    this.details,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'details': details,
      'created_at': createdAt,
    };
  }

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    return AuditLogEntry(
      id: map['id'] as int?,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as int?,
      action: map['action'] as String,
      details: map['details'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}

class AuditService {
  final DatabaseHelper _dbHelper;

  AuditService({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static final AuditService instance = AuditService();

  /// Record an audit event securely
  Future<void> log({
    required String entityType,
    int? entityId,
    required String action,
    String? details,
  }) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        DatabaseTables.tableAuditLogs,
        {
          'entity_type': entityType,
          'entity_id': entityId,
          'action': action,
          'details': details,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Never crash the parent operation if logging fails
    }
  }

  /// Fetch chronological audit trail
  Future<List<AuditLogEntry>> getLogs({int limit = 150}) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        DatabaseTables.tableAuditLogs,
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return results.map((m) => AuditLogEntry.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear all audit logs (requires owner authorization)
  Future<void> clearLogs() async {
    try {
      final db = await _dbHelper.database;
      await db.delete(DatabaseTables.tableAuditLogs);
    } catch (_) {}
  }
}
