import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'backup_service.dart';

class CloudAuthService {
  static const String cloudName = 'a9zkyw5b';
  static const String uploadPreset = 'dm_slips';
  static const String _uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/raw/upload';
  static const String _downloadBaseUrl = 'https://res.cloudinary.com/$cloudName/raw/upload';

  @visibleForTesting
  static http.Client? testClient;

  /// Sanitize email for Cloudinary public_id
  static String sanitizeEmail(String email) {
    return email
        .toLowerCase()
        .trim()
        .replaceAll('@', '_')
        .replaceAll('.', '_')
        .replaceAll('+', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  /// Save user credentials and profile to the online cloud database
  static Future<bool> saveUserToCloud(Map<String, dynamic> userMap, {http.Client? client}) async {
    final email = userMap['email'] as String? ?? '';
    if (email.isEmpty) return false;

    final sanitized = sanitizeEmail(email);
    final publicId = 'user_$sanitized';
    final httpClient = client ?? testClient;

    try {
      final jsonPayload = jsonEncode({
        'id': userMap['id'],
        'name': userMap['name'],
        'email': email.toLowerCase().trim(),
        'password_hash': userMap['password_hash'],
        'phone': userMap['phone'],
        'shop_name': userMap['shop_name'] ?? 'DM LACE SURAT',
        'created_at': userMap['created_at'] ?? DateTime.now().toIso8601String(),
        'last_login_at': DateTime.now().toIso8601String(),
      });

      final base64Content = base64Encode(utf8.encode(jsonPayload));
      final fileDataUri = 'data:text/plain;base64,$base64Content';

      final res = httpClient != null
          ? await httpClient.post(
              Uri.parse(_uploadUrl),
              body: {
                'file': fileDataUri,
                'upload_preset': uploadPreset,
                'public_id': publicId,
              },
            ).timeout(const Duration(seconds: 8))
          : await http.post(
              Uri.parse(_uploadUrl),
              body: {
                'file': fileDataUri,
                'upload_preset': uploadPreset,
                'public_id': publicId,
              },
            ).timeout(const Duration(seconds: 8));

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      if (kDebugMode) print('CloudAuthService.saveUserToCloud error: $e');
      return false;
    }
  }

  /// Fetch user credentials from the online cloud database
  static Future<Map<String, dynamic>?> fetchUserFromCloud(String email, {http.Client? client}) async {
    if (email.trim().isEmpty) return null;
    final sanitized = sanitizeEmail(email);
    final publicId = 'user_$sanitized';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = '$_downloadBaseUrl/$publicId?t=$timestamp';
    final httpClient = client ?? testClient;

    try {
      final res = httpClient != null
          ? await httpClient.get(Uri.parse(url)).timeout(const Duration(seconds: 6))
          : await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      if (kDebugMode) print('CloudAuthService.fetchUserFromCloud error: $e');
    }
    return null;
  }

  /// Backup full shop database (bills, parties, items) to the cloud under user's email
  static Future<bool> saveBackupToCloud(String email) async {
    if (email.trim().isEmpty) return false;
    final sanitized = sanitizeEmail(email);
    final publicId = 'backup_$sanitized';

    try {
      final backupJson = await BackupService().createBackupJson();
      final base64Content = base64Encode(utf8.encode(backupJson));
      final fileDataUri = 'data:text/plain;base64,$base64Content';

      final res = await http.post(
        Uri.parse(_uploadUrl),
        body: {
          'file': fileDataUri,
          'upload_preset': uploadPreset,
          'public_id': publicId,
        },
      ).timeout(const Duration(seconds: 12));

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      if (kDebugMode) print('CloudAuthService.saveBackupToCloud error: $e');
      return false;
    }
  }

  /// Restore full shop database from cloud if available
  static Future<bool> restoreBackupFromCloud(String email) async {
    if (email.trim().isEmpty) return false;
    final sanitized = sanitizeEmail(email);
    final publicId = 'backup_$sanitized';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = '$_downloadBaseUrl/$publicId?t=$timestamp';

    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final backupService = BackupService();
        final success = await backupService.restoreBackup(res.body);
        return success;
      }
    } catch (e) {
      if (kDebugMode) print('CloudAuthService.restoreBackupFromCloud error: $e');
    }
    return false;
  }
}
