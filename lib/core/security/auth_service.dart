import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../../services/cloud_auth_service.dart';

class AuthService {
  static const String _authSalt = 'DmLaceSurat_Auth_Salt_2026_Secure';
  static Map<String, dynamic>? _cachedCurrentUser;
  static String? _cachedUserName;
  static bool _isLoggedIn = false;
  static bool bypassAuthForTesting = false;

  static bool get isLoggedInSync => bypassAuthForTesting || _isLoggedIn;

  static String get currentUserName {
    if (_cachedCurrentUser != null && _cachedCurrentUser!['name'] != null) {
      final name = _cachedCurrentUser!['name'] as String;
      if (name.isNotEmpty) return name;
    }
    return _cachedUserName ?? '';
  }

  /// Initialize auth state from DB
  static Future<void> init() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        DatabaseTables.tableAppSettings,
        where: 'setting_key = ?',
        whereArgs: ['auth_is_logged_in'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        _isLoggedIn = rows.first['setting_value'] == 'true';
      } else {
        _isLoggedIn = false;
      }

      final nameRows = await db.query(
        DatabaseTables.tableAppSettings,
        where: 'setting_key = ?',
        whereArgs: ['auth_logged_in_name'],
        limit: 1,
      );
      if (nameRows.isNotEmpty) {
        _cachedUserName = nameRows.first['setting_value'] as String?;
      }
    } catch (_) {
      _isLoggedIn = false;
    }
  }

  /// Hash password using SHA-256 with salt
  static String hashPassword(String password) {
    final bytes = utf8.encode('$password$_authSalt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Check whether a user is currently logged in
  static Future<bool> isLoggedIn() async {
    if (bypassAuthForTesting) return true;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        DatabaseTables.tableAppSettings,
        where: 'setting_key = ?',
        whereArgs: ['auth_is_logged_in'],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      _isLoggedIn = rows.first['setting_value'] == 'true';
      return _isLoggedIn;
    } catch (_) {
      return false;
    }
  }

  /// Check whether any registered accounts exist on this device
  static Future<bool> hasAnyUsers() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableAppUsers}');
      final count = (rows.first['cnt'] as num?)?.toInt() ?? 0;
      return count > 0;
    } catch (_) {
      return false;
    }
  }

  /// Check whether a specific email is already registered (checks local DB then cloud)
  static Future<bool> isEmailRegistered(String email) async {
    final cleanEmail = email.toLowerCase().trim();
    if (cleanEmail.isEmpty) return false;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        DatabaseTables.tableAppUsers,
        where: 'email = ?',
        whereArgs: [cleanEmail],
        limit: 1,
      );
      if (rows.isNotEmpty) return true;
      final cloudUser = await CloudAuthService.fetchUserFromCloud(cleanEmail);
      return cloudUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Get currently authenticated user details
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_cachedCurrentUser != null) return _cachedCurrentUser;
    try {
      final db = await DatabaseHelper.instance.database;
      final settingRows = await db.query(
        DatabaseTables.tableAppSettings,
        where: 'setting_key = ?',
        whereArgs: ['auth_logged_in_email'],
        limit: 1,
      );
      if (settingRows.isEmpty) return null;
      final email = settingRows.first['setting_value'] as String?;
      if (email == null || email.isEmpty) return null;

      final userRows = await db.query(
        DatabaseTables.tableAppUsers,
        where: 'email = ?',
        whereArgs: [email.toLowerCase().trim()],
        limit: 1,
      );
      if (userRows.isNotEmpty) {
        _cachedCurrentUser = Map<String, dynamic>.from(userRows.first);
        _isLoggedIn = true;
        return _cachedCurrentUser;
      }
    } catch (_) {}
    return null;
  }

  /// Sign In with Email & Password
  static Future<({bool success, String? error, Map<String, dynamic>? user})> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.toLowerCase().trim();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty) {
      return (success: false, error: 'कृपया ईमेल पता दर्ज करें', user: null);
    }
    if (cleanPassword.isEmpty) {
      return (success: false, error: 'कृपया पासवर्ड दर्ज करें', user: null);
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        DatabaseTables.tableAppUsers,
        where: 'email = ?',
        whereArgs: [cleanEmail],
        limit: 1,
      );

      if (rows.isEmpty) {
        // If not found in local DB (e.g. fresh install/reinstall), check Online Cloud Database
        final cloudUser = await CloudAuthService.fetchUserFromCloud(cleanEmail);
        if (cloudUser == null) {
          return (
            success: false,
            error: 'इस ईमेल पर कोई खाता नहीं मिला। कृपया पहले साइन अप करें।',
            user: null,
          );
        }

        final expectedHash = cloudUser['password_hash'] as String?;
        final inputHash = hashPassword(cleanPassword);

        if (expectedHash != inputHash) {
          return (
            success: false,
            error: 'गलत पासवर्ड! कृपया सही पासवर्ड दर्ज करें।',
            user: null,
          );
        }

        // Successfully verified from Online Cloud Database!
        // Save user into local SQLite database so it stays offline accessible too
        final now = DateTime.now().toIso8601String();
        final newId = await db.insert(
          DatabaseTables.tableAppUsers,
          {
            'name': cloudUser['name'] ?? 'User',
            'email': cleanEmail,
            'password_hash': expectedHash,
            'phone': cloudUser['phone'],
            'shop_name': cloudUser['shop_name'] ?? 'DM LACE SURAT',
            'created_at': cloudUser['created_at'] ?? now,
            'last_login_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final restoredUser = {
          'id': newId,
          'name': cloudUser['name'] ?? 'User',
          'email': cleanEmail,
          'phone': cloudUser['phone'],
          'shop_name': cloudUser['shop_name'] ?? 'DM LACE SURAT',
          'created_at': cloudUser['created_at'] ?? now,
          'last_login_at': now,
        };

        await db.rawInsert(
          'INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at) VALUES (?, ?, ?)',
          ['auth_is_logged_in', 'true', now],
        );
        await db.rawInsert(
          'INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at) VALUES (?, ?, ?)',
          ['auth_logged_in_email', cleanEmail, now],
        );
        await db.rawInsert(
          'INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at) VALUES (?, ?, ?)',
          ['auth_logged_in_name', (cloudUser['name'] as String?) ?? 'User', now],
        );

        _isLoggedIn = true;
        _cachedCurrentUser = restoredUser;
        _cachedUserName = (cloudUser['name'] as String?) ?? 'User';

        // Background restore of shop data from cloud if available
        CloudAuthService.restoreBackupFromCloud(cleanEmail).catchError((_) => false);

        return (success: true, error: null, user: _cachedCurrentUser);
      }

      final userData = rows.first;
      final expectedHash = userData['password_hash'] as String;
      final inputHash = hashPassword(cleanPassword);

      if (expectedHash != inputHash) {
        return (
          success: false,
          error: 'गलत पासवर्ड! कृपया सही पासवर्ड दर्ज करें।',
          user: null,
        );
      }

      // Successful login - persist session
      final now = DateTime.now().toIso8601String();
      await db.update(
        DatabaseTables.tableAppUsers,
        {'last_login_at': now},
        where: 'id = ?',
        whereArgs: [userData['id']],
      );

      await db.rawInsert(
        'INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at) VALUES (?, ?, ?)',
        ['auth_is_logged_in', 'true', now],
      );
      await db.rawInsert(
        'INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at) VALUES (?, ?, ?)',
        ['auth_logged_in_email', cleanEmail, now],
      );
      await db.rawInsert(
        'INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at) VALUES (?, ?, ?)',
        ['auth_logged_in_name', (userData['name'] as String?) ?? 'User', now],
      );

      _isLoggedIn = true;
      _cachedCurrentUser = Map<String, dynamic>.from(userData);
      _cachedUserName = (userData['name'] as String?) ?? 'User';

      // Keep online cloud updated with latest login timestamp
      CloudAuthService.saveUserToCloud(_cachedCurrentUser!).catchError((_) => false);

      return (success: true, error: null, user: _cachedCurrentUser);
    } catch (e) {
      return (success: false, error: 'लॉगिन में त्रुटि: $e', user: null);
    }
  }

  /// Sign Up / Create New Account
  /// As per strict workflow: creates account, but user must then log in on the Login tab.
  static Future<({bool success, String? error, Map<String, dynamic>? user})> signUp({
    required String name,
    required String email,
    required String password,
    String? shopName,
    String? phone,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.toLowerCase().trim();
    final cleanPassword = password.trim();

    if (cleanName.isEmpty) {
      return (success: false, error: 'कृपया अपना नाम दर्ज करें', user: null);
    }
    if (cleanEmail.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(cleanEmail)) {
      return (success: false, error: 'कृपया एक मान्य ईमेल आईडी दर्ज करें (उदा. info@gmail.com)', user: null);
    }
    if (cleanPassword.length < 6) {
      return (success: false, error: 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए', user: null);
    }

    try {
      final db = await DatabaseHelper.instance.database;

      // Check if user already exists locally or in Online Cloud
      final existing = await db.query(
        DatabaseTables.tableAppUsers,
        where: 'email = ?',
        whereArgs: [cleanEmail],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return (
          success: false,
          error: 'इस ईमेल से खाता पहले से मौजूद है! कृपया लॉगिन करें।',
          user: null,
        );
      }

      final existingCloud = await CloudAuthService.fetchUserFromCloud(cleanEmail);
      if (existingCloud != null) {
        return (
          success: false,
          error: 'इस ईमेल से खाता ऑनलाइन क्लाउड में पहले से मौजूद है! कृपया सीधे लॉगिन करें।',
          user: null,
        );
      }

      // Ensure 100% fresh, clean account: clear all prior entries so account starts empty
      await DatabaseHelper.instance.wipeDatabase();

      final now = DateTime.now().toIso8601String();
      final hashedPassword = hashPassword(cleanPassword);

      final newUserId = await db.insert(
        DatabaseTables.tableAppUsers,
        {
          'name': cleanName,
          'email': cleanEmail,
          'password_hash': hashedPassword,
          'phone': phone?.trim(),
          'shop_name': shopName?.trim() ?? 'DM LACE SURAT',
          'created_at': now,
          'last_login_at': now,
        },
      );

      if (shopName != null && shopName.trim().isNotEmpty) {
        await db.rawInsert(
          'INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at) VALUES (?, ?, ?)',
          ['shop_name', shopName.trim(), now],
        );
      }

      final newUser = {
        'id': newUserId,
        'name': cleanName,
        'email': cleanEmail,
        'password_hash': hashedPassword,
        'phone': phone?.trim(),
        'shop_name': shopName?.trim() ?? 'DM LACE SURAT',
        'created_at': now,
        'last_login_at': now,
      };

      // Instantly save to permanent online cloud database
      CloudAuthService.saveUserToCloud(newUser).catchError((_) => false);

      // Do NOT set _isLoggedIn = true yet; user will proceed to login screen to sign in
      return (success: true, error: null, user: newUser);
    } catch (e) {
      return (success: false, error: 'अकाउंट बनाने में त्रुटि: $e', user: null);
    }
  }

  /// Logout current session
  static Future<void> logout() async {
    _cachedCurrentUser = null;
    _cachedUserName = null;
    _isLoggedIn = false;
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();
      await db.rawInsert(
        'INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at) VALUES (?, ?, ?)',
        ['auth_is_logged_in', 'false', now],
      );
      await db.rawInsert(
        'INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at) VALUES (?, ?, ?)',
        ['auth_logged_in_email', '', now],
      );
    } catch (_) {}
  }

  /// Reset password by email
  static Future<bool> resetPassword({required String email, required String newPassword}) async {
    final cleanEmail = email.toLowerCase().trim();
    if (newPassword.trim().length < 6) return false;
    try {
      final db = await DatabaseHelper.instance.database;
      final newHash = hashPassword(newPassword.trim());
      final count = await db.update(
        DatabaseTables.tableAppUsers,
        {'password_hash': newHash},
        where: 'email = ?',
        whereArgs: [cleanEmail],
      );
      return count > 0;
    } catch (_) {
      return false;
    }
  }

  /// Check if user exists
  static Future<bool> userExists(String email) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        DatabaseTables.tableAppUsers,
        where: 'email = ?',
        whereArgs: [email.toLowerCase().trim()],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
