import 'dart:convert';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/upi_qr_account.dart';

class UpiQrService {
  static const String _settingKey = 'upi_qr_accounts';

  static final List<UpiQrAccount> _defaultAccounts = [
    const UpiQrAccount(
      id: 'default_shop',
      title: 'दुकान काउंटर (Shop Counter)',
      upiId: 'dmlace@upi',
      accountHolderName: 'DM LACE SURAT',
      bankName: 'HDFC Bank',
      isPrimary: true,
      note: 'दुकान पर पेमेंट के लिए',
    ),
    const UpiQrAccount(
      id: 'default_current',
      title: 'फर्म चालू खाता (Current A/c)',
      upiId: 'dmlacesurat@icici',
      accountHolderName: 'DM LACE SURAT',
      bankName: 'ICICI Bank',
      isPrimary: false,
      note: 'व्यापारिक / बड़ा पेमेंट',
    ),
  ];

  /// Get all configured UPI QR accounts
  static Future<List<UpiQrAccount>> getAccounts() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        DatabaseTables.tableAppSettings,
        where: 'setting_key = ?',
        whereArgs: [_settingKey],
      );

      if (rows.isNotEmpty) {
        final jsonStr = rows.first['setting_value'] as String?;
        if (jsonStr != null && jsonStr.trim().isNotEmpty) {
          final List decoded = jsonDecode(jsonStr);
          final accounts = decoded.map((e) => UpiQrAccount.fromMap(e as Map<String, dynamic>)).toList();
          if (accounts.isNotEmpty) {
            // Ensure at least one is primary
            if (!accounts.any((a) => a.isPrimary)) {
              accounts[0] = accounts[0].copyWith(isPrimary: true);
            }
            return accounts;
          }
        }
      }

      // Check legacy 'shop_upi' from settings if available
      final legacyRows = await db.query(
        DatabaseTables.tableAppSettings,
        where: 'setting_key IN (?, ?)',
        whereArgs: ['shop_upi', 'shop_name'],
      );
      String legacyUpi = 'dmlace@upi';
      String legacyName = 'DM LACE SURAT';
      for (final r in legacyRows) {
        if (r['setting_key'] == 'shop_upi') legacyUpi = r['setting_value'] as String;
        if (r['setting_key'] == 'shop_name') legacyName = r['setting_value'] as String;
      }

      final initial = [
        UpiQrAccount(
          id: 'acc_shop_1',
          title: 'दुकान काउंटर (Shop Counter)',
          upiId: legacyUpi,
          accountHolderName: legacyName,
          bankName: 'HDFC Bank',
          isPrimary: true,
          note: 'काउंटर पेमेंट',
        ),
        UpiQrAccount(
          id: 'acc_current_2',
          title: 'फर्म चालू खाता (Current A/c)',
          upiId: legacyUpi.contains('@') ? '${legacyUpi.split('@')[0]}current@icici' : 'dmlacesurat@icici',
          accountHolderName: legacyName,
          bankName: 'ICICI Bank',
          isPrimary: false,
          note: 'फर्म RTGS/UPI',
        ),
      ];

      // Save defaults to DB
      await saveAccounts(initial);
      return initial;
    } catch (_) {
      return _defaultAccounts;
    }
  }

  /// Get the active primary UPI account
  static Future<UpiQrAccount> getPrimaryAccount() async {
    final accounts = await getAccounts();
    return accounts.firstWhere((a) => a.isPrimary, orElse: () => accounts.first);
  }

  /// Save full list of accounts
  static Future<void> saveAccounts(List<UpiQrAccount> accounts) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final jsonStr = jsonEncode(accounts.map((a) => a.toMap()).toList());

      await db.rawInsert('''
        INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at)
        VALUES (?, ?, datetime('now'))
      ''', [_settingKey, jsonStr]);

      // Also sync primary upi to 'shop_upi' for legacy readers
      final primary = accounts.firstWhere((a) => a.isPrimary, orElse: () => accounts.first);
      await db.rawInsert('''
        INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at)
        VALUES (?, ?, datetime('now'))
      ''', ['shop_upi', primary.upiId]);
    } catch (_) {}
  }

  /// Add a new account
  static Future<void> addAccount(UpiQrAccount account) async {
    var accounts = await getAccounts();
    if (account.isPrimary) {
      accounts = accounts.map((a) => a.copyWith(isPrimary: false)).toList();
    }
    accounts.add(account);
    await saveAccounts(accounts);
  }

  /// Update an existing account
  static Future<void> updateAccount(UpiQrAccount updated) async {
    var accounts = await getAccounts();
    if (updated.isPrimary) {
      accounts = accounts.map((a) => a.id == updated.id ? updated : a.copyWith(isPrimary: false)).toList();
    } else {
      accounts = accounts.map((a) => a.id == updated.id ? updated : a).toList();
      // Ensure at least one remains primary
      if (!accounts.any((a) => a.isPrimary)) {
        accounts[0] = accounts[0].copyWith(isPrimary: true);
      }
    }
    await saveAccounts(accounts);
  }

  /// Delete an account (at least 1 must remain)
  static Future<bool> deleteAccount(String id) async {
    final accounts = await getAccounts();
    if (accounts.length <= 1) return false; // Cannot delete the only account

    final filtered = accounts.where((a) => a.id != id).toList();
    if (!filtered.any((a) => a.isPrimary)) {
      filtered[0] = filtered[0].copyWith(isPrimary: true);
    }
    await saveAccounts(filtered);
    return true;
  }

  /// Set an account as primary
  static Future<void> setPrimaryAccount(String id) async {
    final accounts = await getAccounts();
    final updated = accounts.map((a) => a.copyWith(isPrimary: a.id == id)).toList();
    await saveAccounts(updated);
  }
}
