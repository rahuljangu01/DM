import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() async {
  final proc = await Process.start('adb', [
    '-s',
    'adb-10BD2A1J060005K-0deTd3._adb-tls-connect._tcp',
    'exec-out',
    'run-as',
    'com.dmlace.surat.dm_lace_surat',
    'cat',
    'app_flutter/dm_lace_surat.db',
  ]);
  final bytes = <int>[];
  await for (final chunk in proc.stdout) {
    bytes.addAll(chunk);
  }
  await proc.exitCode;
  final dbFile = File(r'D:\DM\phone_clean.db');
  await dbFile.writeAsBytes(bytes);

  final db = sqlite3.open(dbFile.path);
  try {
    print("Parties: ${db.select('SELECT COUNT(*) as c FROM parties;').first['c']}");
    print("Documents: ${db.select('SELECT COUNT(*) as c FROM documents;').first['c']}");
    print("Transactions: ${db.select('SELECT COUNT(*) as c FROM transactions;').first['c']}");
    print("Catalog: ${db.select('SELECT COUNT(*) as c FROM inventory_items;').first['c']}");
    final settings = db.select('SELECT setting_key, setting_value FROM app_settings;');
    for (final s in settings) {
      print("${s['setting_key']} = ${s['setting_value']}");
    }
  } catch (e) {
    print("Error: $e");
  } finally {
    db.dispose();
  }
}
