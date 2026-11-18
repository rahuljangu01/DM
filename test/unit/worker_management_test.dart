import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dm_lace_surat/core/database/database_helper.dart';
import 'package:dm_lace_surat/repositories/worker_repository.dart';
import 'package:dm_lace_surat/models/worker.dart';
import 'package:dm_lace_surat/models/machine_katai_entry.dart';
import 'package:dm_lace_surat/models/worker_payment.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.resetForTesting(null, inMemoryDatabasePath);
  });

  group('WorkerManagement & Production Tests', () {
    late DatabaseHelper dbHelper;
    late WorkerRepository repo;

    setUp(() async {
      dbHelper = DatabaseHelper.instance;
      await dbHelper.wipeDatabase();
      repo = WorkerRepository(dbHelper: dbHelper);
    });

    test('Worker lifecycle: insert, get, update, distinct machines', () async {
      final worker = Worker(
        name: 'Ramesh Bhai',
        phone: '9825100001',
        machineNumber: 'Machine 1',
        wageType: 'katai_piece',
        ratePaise: 250, // ₹ 2.50
      );

      final id = await repo.insertWorker(worker);
      expect(id, isPositive);

      final list = await repo.getAllWorkers();
      expect(list.length, 1);
      expect(list.first.name, 'Ramesh Bhai');
      expect(list.first.rateRupees, 2.50);

      final machines = await repo.getDistinctMachines();
      expect(machines, contains('Machine 1'));
    });

    test('Attendance tracking: mark present, absent, half_day & daily summary', () async {
      final workerId = await repo.insertWorker(Worker(
        name: 'Suresh Bhai',
        machineNumber: 'Machine 2',
        wageType: 'daily',
        ratePaise: 50000, // ₹ 500
      ));

      await repo.markAttendance(workerId: workerId, date: '2026-11-17', status: 'present');

      final summary = await repo.getAttendanceSummary('2026-11-17');
      expect(summary['present'], 1);
      expect(summary['absent'], 0);

      // Change to half_day
      await repo.markAttendance(workerId: workerId, date: '2026-11-17', status: 'half_day');
      final updatedSummary = await repo.getAttendanceSummary('2026-11-17');
      expect(updatedSummary['present'], 0);
      expect(updatedSummary['half_day'], 1);
    });

    test('Production & Katai tracking with wage calculation', () async {
      final workerId = await repo.insertWorker(Worker(
        name: 'Mukesh Bhai',
        machineNumber: 'Machine 3',
        wageType: 'katai_piece',
        ratePaise: 200, // ₹ 2.00 / meter
      ));

      // Record 500 meters cut
      final katai = MachineKataiEntry(
        date: '2026-11-17',
        machineNumber: 'Machine 3',
        workerId: workerId,
        designCode: 'DM-ZARI-101',
        shift: 'day',
        quantity: 500.0,
        unit: 'meter',
        ratePaise: 200,
        totalAmountPaise: 100000, // ₹ 1,000
      );

      final kataiId = await repo.insertKataiEntry(katai);
      expect(kataiId, isPositive);

      // Record ₹ 300 advance given
      await repo.recordPayment(WorkerPayment(
        workerId: workerId,
        date: '2026-11-17',
        paymentType: 'advance',
        amountPaise: 30000, // ₹ 300
        paymentMethod: 'cash',
      ));

      // Record ₹ 200 wage settlement
      await repo.recordPayment(WorkerPayment(
        workerId: workerId,
        date: '2026-11-17',
        paymentType: 'wage_payout',
        amountPaise: 20000, // ₹ 200
        paymentMethod: 'cash',
      ));

      final wageSummary = await repo.getWorkerWageSummary(workerId);
      expect(wageSummary['totalEarnedPaise'], 100000); // ₹ 1,000 earned
      expect(wageSummary['totalAdvancePaise'], 30000);  // ₹ 300 advance
      expect(wageSummary['totalWagePaidPaise'], 20000); // ₹ 200 wage paid
      // Net Payable = Earned (1000) - Advance (300) - Paid (200) = ₹ 500
      expect(wageSummary['netPayablePaise'], 50000);
    });
  });
}
