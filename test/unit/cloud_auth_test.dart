import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dm_lace_surat/core/database/database_helper.dart';
import 'package:dm_lace_surat/core/security/auth_service.dart';
import 'package:dm_lace_surat/services/cloud_auth_service.dart';
import 'package:dm_lace_surat/services/firebase_sync_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null; // Allow real network requests in test
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.resetForTesting(null, inMemoryDatabasePath);
  });

  group('CloudAuthService Tests', () {
    test('sanitizeEmail creates safe alphanumeric identifier', () {
      expect(CloudAuthService.sanitizeEmail('rahuljangu01@gmail.com'), 'rahuljangu01_gmail_com');
      expect(CloudAuthService.sanitizeEmail('test.user+tag@domain.co.in'), 'test_user_tag_domain_co_in');
    });

    test('fetchUserFromCloud retrieves online user record', () async {
      final user = await CloudAuthService.fetchUserFromCloud('rahuljangu01@gmail.com');
      expect(user, isNotNull);
      expect(user!['email'], 'rahuljangu01@gmail.com');
      expect(user['name'], 'Kana Ram');
    });

    test('AuthService logs in from Cloud when local DB is empty', () async {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.wipeDatabase();

      final result = await AuthService.login(
        email: 'rahuljangu01@gmail.com',
        password: 'password123',
      );
      expect(result.error, isNot(contains('इस ईमेल पर कोई खाता नहीं मिला')));
    });

    test('FirebaseSyncService uploads full live snapshot to cloud', () async {
      final syncService = FirebaseSyncService();
      final result = await syncService.syncAllToCloud();
      expect(result.success, isTrue);
    });
  });
}
