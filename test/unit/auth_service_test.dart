import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dm_lace_surat/core/database/database_helper.dart';
import 'package:dm_lace_surat/core/security/auth_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.resetForTesting(null, inMemoryDatabasePath);
  });

  setUp(() async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.wipeDatabase();
    await AuthService.logout();
  });

  test('AuthService hashes passwords consistently with salt', () {
    final hash1 = AuthService.hashPassword('secret123');
    final hash2 = AuthService.hashPassword('secret123');
    final hashDifferent = AuthService.hashPassword('secret124');

    expect(hash1, equals(hash2));
    expect(hash1, isNot(equals(hashDifferent)));
    expect(hash1.length, equals(64)); // sha256 hex length
  });

  test('AuthService handles Sign Up, Login, and Logout flow smoothly', () async {
    // 1. Initial state should be logged out
    expect(await AuthService.isLoggedIn(), isFalse);
    expect(await AuthService.getCurrentUser(), isNull);

    // 2. Sign Up with valid email & password
    final signUpRes = await AuthService.signUp(
      name: 'Dinesh Bhai',
      email: 'dinesh@dmlace.com',
      password: 'password123',
      shopName: 'DM LACE SURAT',
      phone: '9825012345',
    );

    expect(signUpRes.success, isTrue);
    expect(signUpRes.error, isNull);
    expect(signUpRes.user?['name'], equals('Dinesh Bhai'));
    expect(signUpRes.user?['email'], equals('dinesh@dmlace.com'));

    // 3. Strict workflow: Sign Up does NOT auto-login. User remains logged out until explicit login.
    expect(await AuthService.isLoggedIn(), isFalse);
    expect(await AuthService.getCurrentUser(), isNull);

    // 4. Duplicate sign up should fail
    final dupRes = await AuthService.signUp(
      name: 'Another Name',
      email: 'dinesh@dmlace.com',
      password: 'newpassword123',
    );
    expect(dupRes.success, isFalse);
    expect(dupRes.error, contains('पहले से'));

    // 5. Logout
    await AuthService.logout();
    expect(await AuthService.isLoggedIn(), isFalse);
    expect(await AuthService.getCurrentUser(), isNull);

    // 6. Login with wrong password should fail
    final wrongPassRes = await AuthService.login(
      email: 'dinesh@dmlace.com',
      password: 'wrongpassword',
    );
    expect(wrongPassRes.success, isFalse);
    expect(wrongPassRes.error, contains('गलत पासवर्ड'));

    // 7. Login with correct password should succeed
    final correctLoginRes = await AuthService.login(
      email: 'DINESH@DMLACE.COM ', // case-insensitive & trimmed
      password: 'password123',
    );
    expect(correctLoginRes.success, isTrue);
    expect(await AuthService.isLoggedIn(), isTrue);

    // 8. Reset password
    final resetOk = await AuthService.resetPassword(
      email: 'dinesh@dmlace.com',
      newPassword: 'newSecretPass789',
    );
    expect(resetOk, isTrue);

    // Login with old password fails
    final oldPassRes = await AuthService.login(
      email: 'dinesh@dmlace.com',
      password: 'password123',
    );
    expect(oldPassRes.success, isFalse);

    // Login with new password succeeds
    final newPassRes = await AuthService.login(
      email: 'dinesh@dmlace.com',
      password: 'newSecretPass789',
    );
    expect(newPassRes.success, isTrue);
  });
}
