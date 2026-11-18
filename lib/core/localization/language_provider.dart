import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';

enum AppLanguage {
  english,
  hindi,
}

class LanguageProvider extends ChangeNotifier {
  static final LanguageProvider _instance = LanguageProvider._internal();
  factory LanguageProvider() => _instance;
  LanguageProvider._internal();

  AppLanguage _currentLanguage = AppLanguage.english;

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isHindi => _currentLanguage == AppLanguage.hindi;
  bool get isEnglish => _currentLanguage == AppLanguage.english;

  /// Initialize and load saved language preference from SQLite
  Future<void> init() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        DatabaseTables.tableAppSettings,
        where: 'setting_key = ?',
        whereArgs: ['app_language'],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        final val = rows.first['setting_value'] as String?;
        if (val == 'hi') {
          _currentLanguage = AppLanguage.hindi;
        } else {
          _currentLanguage = AppLanguage.english;
        }
      } else {
        // Default language is English as requested
        _currentLanguage = AppLanguage.english;
      }
      notifyListeners();
    } catch (_) {
      _currentLanguage = AppLanguage.english;
    }
  }

  /// Change application language dynamically and persist to database
  Future<void> setLanguage(AppLanguage lang) async {
    if (_currentLanguage == lang) return;
    _currentLanguage = lang;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final langCode = lang == AppLanguage.hindi ? 'hi' : 'en';

      await db.insert(
        DatabaseTables.tableAppSettings,
        {
          'setting_key': 'app_language',
          'setting_value': langCode,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: null, // Let SQLite replace on conflict
      );
    } catch (_) {
      try {
        final db = await DatabaseHelper.instance.database;
        final langCode = lang == AppLanguage.hindi ? 'hi' : 'en';
        await db.rawInsert('''
          INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at)
          VALUES ('app_language', ?, ?)
        ''', [langCode, DateTime.now().toIso8601String()]);
      } catch (_) {}
    }
  }

  /// Get translated text by key
  String tr({required String en, required String hi}) {
    return _currentLanguage == AppLanguage.hindi ? hi : en;
  }
}
