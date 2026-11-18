import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/worker.dart';
import '../models/worker_attendance.dart';
import '../models/machine_katai_entry.dart';
import '../models/worker_payment.dart';
import '../services/audit_service.dart';
import '../services/firebase_sync_service.dart';

class WorkerRepository {
  final DatabaseHelper _dbHelper;

  WorkerRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  // =========================================================================
  // 1. WORKERS CRUD
  // =========================================================================

  Future<int> insertWorker(Worker worker) async {
    final db = await _dbHelper.database;
    final id = await db.insert(
      DatabaseTables.tableWorkers,
      worker.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await AuditService.instance.log(
      entityType: 'WORKER',
      entityId: id,
      action: 'CREATE',
      details: 'Added Karigar/Operator: ${worker.name} (Machine: ${worker.machineNumber ?? "General"})',
    );
    final wData = worker.toMap();
    wData['id'] = id;
    FirebaseSyncService().pushSingleRecord(collection: 'workers', id: id.toString(), data: wData).catchError((_) => false);
    return id;
  }

  Future<int> updateWorker(Worker worker) async {
    final db = await _dbHelper.database;
    final count = await db.update(
      DatabaseTables.tableWorkers,
      worker.toMap(),
      where: 'id = ?',
      whereArgs: [worker.id],
    );
    if (worker.id != null) {
      await recalculateWorkerBalance(worker.id!);
      await AuditService.instance.log(
        entityType: 'WORKER',
        entityId: worker.id,
        action: 'UPDATE',
        details: 'Updated Karigar: ${worker.name}',
      );
      FirebaseSyncService().pushSingleRecord(collection: 'workers', id: worker.id.toString(), data: worker.toMap()).catchError((_) => false);
    }
    return count;
  }

  Future<int> deleteWorker(int id) async {
    final db = await _dbHelper.database;
    // Soft delete by setting is_active = 0
    final count = await db.update(
      DatabaseTables.tableWorkers,
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await AuditService.instance.log(
      entityType: 'WORKER',
      entityId: id,
      action: 'DELETE',
      details: 'Deactivated Karigar ID: $id',
    );
    return count;
  }

  Future<Worker?> getWorkerById(int id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseTables.tableWorkers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Worker.fromMap(results.first);
  }

  Future<List<Worker>> getAllWorkers({bool onlyActive = true}) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseTables.tableWorkers,
      where: onlyActive ? 'is_active = 1' : null,
      orderBy: 'name ASC',
    );
    return results.map((m) => Worker.fromMap(m)).toList();
  }

  // =========================================================================
  // 2. ATTENDANCE OPERATIONS (हाजिरी)
  // =========================================================================

  Future<void> markAttendance({
    required int workerId,
    required String date,
    required String status,
    double overtimeHours = 0.0,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    // Check if attendance already recorded for this worker on this date
    final existing = await db.query(
      DatabaseTables.tableWorkerAttendance,
      where: 'worker_id = ? AND date = ?',
      whereArgs: [workerId, date],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as int;
      await db.update(
        DatabaseTables.tableWorkerAttendance,
        {
          'status': status,
          'overtime_hours': overtimeHours,
          'notes': notes,
        },
        where: 'id = ?',
        whereArgs: [existingId],
      );
    } else {
      await db.insert(
        DatabaseTables.tableWorkerAttendance,
        {
          'worker_id': workerId,
          'date': date,
          'status': status,
          'overtime_hours': overtimeHours,
          'notes': notes,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  Future<List<WorkerAttendance>> getAttendanceForDate(String date) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT a.*, w.name as worker_name 
      FROM ${DatabaseTables.tableWorkerAttendance} a
      JOIN ${DatabaseTables.tableWorkers} w ON a.worker_id = w.id
      WHERE a.date = ?
      ORDER BY w.name ASC
    ''', [date]);

    return results.map((m) => WorkerAttendance.fromMap(m)).toList();
  }

  Future<Map<String, int>> getAttendanceSummary(String date) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT status, COUNT(*) as count
      FROM ${DatabaseTables.tableWorkerAttendance}
      WHERE date = ?
      GROUP BY status
    ''', [date]);

    int present = 0;
    int absent = 0;
    int halfDay = 0;
    int overtime = 0;

    for (final row in results) {
      final st = row['status'] as String?;
      final cnt = (row['count'] as num?)?.toInt() ?? 0;
      if (st == 'present') present = cnt;
      if (st == 'absent') absent = cnt;
      if (st == 'half_day') halfDay = cnt;
      if (st == 'overtime') overtime = cnt;
    }

    return {
      'present': present,
      'absent': absent,
      'half_day': halfDay,
      'overtime': overtime,
      'total': present + absent + halfDay + overtime,
    };
  }

  // =========================================================================
  // 3. MACHINE KATAI PRODUCTION (मशीन कटाई व उत्पादन)
  // =========================================================================

  Future<int> insertKataiEntry(MachineKataiEntry entry) async {
    final db = await _dbHelper.database;
    final id = await db.insert(
      DatabaseTables.tableMachineKataiEntries,
      entry.toMap(),
    );
    await recalculateWorkerBalance(entry.workerId);
    await AuditService.instance.log(
      entityType: 'KATAI',
      entityId: id,
      action: 'CREATE',
      details: 'Recorded ${entry.quantity}m on ${entry.machineNumber} (₹ ${(entry.totalAmountPaise / 100).toStringAsFixed(2)})',
    );
    final kData = entry.toMap();
    kData['id'] = id;
    FirebaseSyncService().pushSingleRecord(collection: 'machine_katai', id: id.toString(), data: kData).catchError((_) => false);
    return id;
  }

  Future<int> deleteKataiEntry(int id) async {
    final db = await _dbHelper.database;
    final entryRow = await db.query(
      DatabaseTables.tableMachineKataiEntries,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (entryRow.isEmpty) return 0;
    final workerId = entryRow.first['worker_id'] as int;

    final count = await db.delete(
      DatabaseTables.tableMachineKataiEntries,
      where: 'id = ?',
      whereArgs: [id],
    );
    await recalculateWorkerBalance(workerId);
    return count;
  }

  Future<List<MachineKataiEntry>> getKataiEntries({
    String? date,
    String? machineNumber,
    int? workerId,
  }) async {
    final db = await _dbHelper.database;
    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (date != null && date.isNotEmpty) {
      whereClause += ' AND k.date = ?';
      whereArgs.add(date);
    }
    if (machineNumber != null && machineNumber != 'all') {
      whereClause += ' AND k.machine_number = ?';
      whereArgs.add(machineNumber);
    }
    if (workerId != null) {
      whereClause += ' AND k.worker_id = ?';
      whereArgs.add(workerId);
    }

    final results = await db.rawQuery('''
      SELECT k.*, w.name as worker_name
      FROM ${DatabaseTables.tableMachineKataiEntries} k
      LEFT JOIN ${DatabaseTables.tableWorkers} w ON k.worker_id = w.id
      WHERE $whereClause
      ORDER BY k.date DESC, k.id DESC
    ''', whereArgs);

    return results.map((m) => MachineKataiEntry.fromMap(m)).toList();
  }

  Future<List<String>> getDistinctMachines() async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT machine_number FROM ${DatabaseTables.tableMachineKataiEntries}
      UNION
      SELECT DISTINCT machine_number FROM ${DatabaseTables.tableWorkers}
      WHERE machine_number IS NOT NULL AND machine_number != ''
      ORDER BY machine_number ASC
    ''');

    final set = <String>{};
    for (final r in results) {
      final m = r['machine_number'] as String?;
      if (m != null && m.trim().isNotEmpty) set.add(m.trim());
    }
    if (set.isEmpty) {
      return ['Machine 1', 'Machine 2', 'Machine 3', 'Multihead #1'];
    }
    return set.toList();
  }

  // =========================================================================
  // 4. PAYMENTS & WAGE SETTLEMENTS (मजदूरी, उठाव / एडवांस)
  // =========================================================================

  Future<int> recordPayment(WorkerPayment payment) async {
    final db = await _dbHelper.database;
    final id = await db.insert(
      DatabaseTables.tableWorkerPayments,
      payment.toMap(),
    );
    await recalculateWorkerBalance(payment.workerId);
    await AuditService.instance.log(
      entityType: 'WORKER_PAYMENT',
      entityId: id,
      action: 'CREATE',
      details: '${payment.paymentType}: ₹ ${(payment.amountPaise / 100).toStringAsFixed(2)} to Worker ID ${payment.workerId}',
    );
    final pData = payment.toMap();
    pData['id'] = id;
    FirebaseSyncService().pushSingleRecord(collection: 'worker_payments', id: id.toString(), data: pData).catchError((_) => false);
    return id;
  }

  Future<int> deletePayment(int id) async {
    final db = await _dbHelper.database;
    final row = await db.query(DatabaseTables.tableWorkerPayments, where: 'id = ?', whereArgs: [id], limit: 1);
    if (row.isEmpty) return 0;
    final workerId = row.first['worker_id'] as int;

    final count = await db.delete(DatabaseTables.tableWorkerPayments, where: 'id = ?', whereArgs: [id]);
    await recalculateWorkerBalance(workerId);
    return count;
  }

  Future<List<WorkerPayment>> getWorkerPayments(int workerId, {String? startDate, String? endDate}) async {
    final db = await _dbHelper.database;
    String whereClause = 'p.worker_id = ?';
    final List<dynamic> whereArgs = [workerId];

    if (startDate != null && startDate.isNotEmpty) {
      whereClause += ' AND p.date >= ?';
      whereArgs.add(startDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      whereClause += ' AND p.date <= ?';
      whereArgs.add(endDate);
    }

    final results = await db.rawQuery('''
      SELECT p.*, w.name as worker_name
      FROM ${DatabaseTables.tableWorkerPayments} p
      LEFT JOIN ${DatabaseTables.tableWorkers} w ON p.worker_id = w.id
      WHERE $whereClause
      ORDER BY p.date DESC, p.id DESC
    ''', whereArgs);

    return results.map((m) => WorkerPayment.fromMap(m)).toList();
  }

  Future<Map<String, dynamic>> getWorkerWageSummary(int workerId, {String? startDate, String? endDate}) async {
    final db = await _dbHelper.database;

    // 1. Katai Earnings
    String kataiWhere = 'worker_id = ?';
    final List<dynamic> kataiArgs = [workerId];
    if (startDate != null) {
      kataiWhere += ' AND date >= ?';
      kataiArgs.add(startDate);
    }
    if (endDate != null) {
      kataiWhere += ' AND date <= ?';
      kataiArgs.add(endDate);
    }

    final kataiRes = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity), 0) as total_qty, COALESCE(SUM(total_amount_paise), 0) as total_paise
      FROM ${DatabaseTables.tableMachineKataiEntries}
      WHERE $kataiWhere
    ''', kataiArgs);

    final totalKataiMeters = (kataiRes.first['total_qty'] as num?)?.toDouble() ?? 0.0;
    final totalKataiPaise = (kataiRes.first['total_paise'] as num?)?.toInt() ?? 0;

    // 2. Attendance count
    String attWhere = 'worker_id = ?';
    final List<dynamic> attArgs = [workerId];
    if (startDate != null) {
      attWhere += ' AND date >= ?';
      attArgs.add(startDate);
    }
    if (endDate != null) {
      attWhere += ' AND date <= ?';
      attArgs.add(endDate);
    }

    final attRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN status = 'present' OR status = 'overtime' THEN 1 ELSE 0 END), 0) as present_days,
        COALESCE(SUM(CASE WHEN status = 'half_day' THEN 0.5 ELSE 0 END), 0) as half_days,
        COALESCE(SUM(overtime_hours), 0) as total_ot
      FROM ${DatabaseTables.tableWorkerAttendance}
      WHERE $attWhere
    ''', attArgs);

    final presentDays = (attRes.first['present_days'] as num?)?.toInt() ?? 0;
    final halfDays = (attRes.first['half_days'] as num?)?.toDouble() ?? 0.0;
    final totalWorkedDays = presentDays + halfDays;
    final totalOtHours = (attRes.first['total_ot'] as num?)?.toDouble() ?? 0.0;

    // 3. Payments (Advances vs Wage settlements)
    String payWhere = 'worker_id = ?';
    final List<dynamic> payArgs = [workerId];
    if (startDate != null) {
      payWhere += ' AND date >= ?';
      payArgs.add(startDate);
    }
    if (endDate != null) {
      payWhere += ' AND date <= ?';
      payArgs.add(endDate);
    }

    final payRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN payment_type = 'advance' THEN amount_paise ELSE 0 END), 0) as total_advance,
        COALESCE(SUM(CASE WHEN payment_type = 'wage_payout' THEN amount_paise ELSE 0 END), 0) as total_wage_paid,
        COALESCE(SUM(CASE WHEN payment_type = 'bonus' THEN amount_paise ELSE 0 END), 0) as total_bonus
      FROM ${DatabaseTables.tableWorkerPayments}
      WHERE $payWhere
    ''', payArgs);

    final totalAdvancePaise = (payRes.first['total_advance'] as num?)?.toInt() ?? 0;
    final totalWagePaidPaise = (payRes.first['total_wage_paid'] as num?)?.toInt() ?? 0;
    final totalBonusPaise = (payRes.first['total_bonus'] as num?)?.toInt() ?? 0;

    // Worker's current balance
    final worker = await getWorkerById(workerId);
    int earnedPaise = totalKataiPaise;
    if (worker != null && worker.wageType == 'daily') {
      earnedPaise = (totalWorkedDays * worker.ratePaise).round();
    }

    final netPayablePaise = earnedPaise + totalBonusPaise - totalAdvancePaise - totalWagePaidPaise;

    return {
      'totalKataiMeters': totalKataiMeters,
      'totalKataiPaise': totalKataiPaise,
      'totalWorkedDays': totalWorkedDays,
      'totalOtHours': totalOtHours,
      'totalAdvancePaise': totalAdvancePaise,
      'totalWagePaidPaise': totalWagePaidPaise,
      'totalBonusPaise': totalBonusPaise,
      'totalEarnedPaise': earnedPaise,
      'netPayablePaise': netPayablePaise,
    };
  }

  Future<void> recalculateWorkerBalance(int workerId) async {
    final summary = await getWorkerWageSummary(workerId);
    final netPayablePaise = summary['netPayablePaise'] as int;

    final db = await _dbHelper.database;
    await db.update(
      DatabaseTables.tableWorkers,
      {
        'current_balance_paise': netPayablePaise.abs(),
        'balance_type': netPayablePaise >= 0 ? 'payable' : 'advance',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [workerId],
    );
  }
}
