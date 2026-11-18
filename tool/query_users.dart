import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final files = [
    r'C:\Users\Admin\Documents\dm_lace_surat.db',
    r'D:\DM\phone_clean.db',
  ];

  for (final path in files) {
    print('\n======================================');
    print('Checking: $path');
    final f = File(path);
    if (!f.existsSync()) {
      print('File does not exist');
      continue;
    }
    final db = sqlite3.open(path);
    try {
      final users = db.select('SELECT id, name, email, phone, shop_name, created_at, last_login_at FROM app_users;');
      print('Users count: ${users.length}');
      for (final u in users) {
        print('  User: $u');
      }
    } catch (e) {
      print('  Error reading app_users: $e');
    }
    try {
      final authSettings = db.select("SELECT setting_key, setting_value FROM app_settings WHERE setting_key LIKE '%auth%' OR setting_key LIKE '%user%';");
      for (final s in authSettings) {
        print("  ${s['setting_key']} = ${s['setting_value']}");
      }
    } catch (e) {
      print('  Error reading app_settings: $e');
    } finally {
      db.dispose();
    }
  }
}
