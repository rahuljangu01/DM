import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../services/audit_service.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';

class PinService {
  static const String _salt = 'DmLaceSurat_Secret_Salt_2026';
  static String? _cachedHash;
  static bool _isLocked = true;
  static DateTime? _lastActivity;
  static int _timeoutMinutes = 5;
      
  /// Hash a 4-digit or 6-digit PIN with salt
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin + _salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Initialize PIN hash from persistent settings
  static void initialize(String? storedHash, {int timeoutMinutes = 5}) {
    _cachedHash = storedHash;
    _timeoutMinutes = timeoutMinutes;
    _isLocked = storedHash != null && storedHash.isNotEmpty;
    recordActivity();
  }

  /// Check whether PIN lock is enabled
  static bool get isPinEnabled => _cachedHash != null && _cachedHash!.isNotEmpty;

  /// Check if app is currently locked
  static bool get isLocked => isPinEnabled && _isLocked;

  /// Set locked state explicitly
  static void setLocked(bool locked) {
    _isLocked = locked;
  }

  /// Record user activity timestamp
  static void recordActivity() {
    _lastActivity = DateTime.now();
  }

  /// Check whether inactivity timeout has elapsed
  static bool checkInactivityLock() {
    if (!isPinEnabled) return false;
    if (_lastActivity == null) {
      _isLocked = true;
      return true;
    }
    final difference = DateTime.now().difference(_lastActivity!);
    if (difference.inMinutes >= _timeoutMinutes) {
      _isLocked = true;
      return true;
    }
    return false;
  }

  /// Verify entered PIN against stored hash
  static bool verifyPin(String enteredPin) {
    if (!isPinEnabled) return true;
    final enteredHash = hashPin(enteredPin);
    final isValid = enteredHash == _cachedHash;
    if (isValid) {
      _isLocked = false;
      recordActivity();
    }
    return isValid;
  }

  /// Updates current PIN hash in memory
  static String setNewPin(String newPin) {
    final newHash = hashPin(newPin);
    _cachedHash = newHash;
    _isLocked = false;
    recordActivity();
    return newHash;
  }

  /// Save new PIN to SQLite database and activate
  static Future<String> savePin(String newPin) async {
    final newHash = setNewPin(newPin);
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        DatabaseTables.tableAppSettings,
        {
          'setting_key': 'app_pin_hash',
          'setting_value': newHash,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        DatabaseTables.tableAppSettings,
        {
          'setting_key': 'app_pin_enabled',
          'setting_value': 'true',
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        DatabaseTables.tableAppSettings,
        {
          'setting_key': 'app_pin_user_configured',
          'setting_value': 'true',
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await AuditService.instance.log(
        entityType: 'SECURITY',
        action: 'PIN_ENABLE',
        details: 'Configured new Salted SHA-256 PIN security lock',
      );
    } catch (_) {}
    return newHash;
  }

  /// Disable PIN lock in memory and persist in SQLite
  static Future<void> disablePin() async {
    _cachedHash = null;
    _isLocked = false;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        DatabaseTables.tableAppSettings,
        {
          'setting_key': 'app_pin_enabled',
          'setting_value': 'false',
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.delete(
        DatabaseTables.tableAppSettings,
        where: 'setting_key = ?',
        whereArgs: ['app_pin_user_configured'],
      );
      await AuditService.instance.log(
        entityType: 'SECURITY',
        action: 'PIN_DISABLE',
        details: 'PIN security protection was deactivated',
      );
    } catch (_) {}
  }

  /// Disable PIN lock (compatibility alias)
  static Future<void> removePin() async {
    await disablePin();
  }
}
