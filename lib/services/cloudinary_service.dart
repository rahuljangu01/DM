import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';

class CloudinaryUploadResult {
  final bool success;
  final String? url;
  final String? publicId;
  final String? errorMessage;

  const CloudinaryUploadResult({
    required this.success,
    this.url,
    this.publicId,
    this.errorMessage,
  });
}

class CloudinaryService {
  static const String keyCloudName = 'cloudinary_cloud_name';
  static const String keyUploadPreset = 'cloudinary_upload_preset';

  // Configured default Cloudinary credentials for DM Lace Surat
  static const String defaultCloudName = 'a9zkyw5b';
  static const String defaultUploadPreset = 'dm_slips';

  final DatabaseHelper _dbHelper;

  CloudinaryService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<String> getCloudName() async {
    final db = await _dbHelper.database;
    final res = await db.query(
      DatabaseTables.tableAppSettings,
      where: 'setting_key = ?',
      whereArgs: [keyCloudName],
    );
    if (res.isNotEmpty) {
      final val = (res.first['setting_value'] as String?)?.trim() ?? '';
      if (val.isNotEmpty) return val;
    }
    return defaultCloudName;
  }

  Future<String> getUploadPreset() async {
    final db = await _dbHelper.database;
    final res = await db.query(
      DatabaseTables.tableAppSettings,
      where: 'setting_key = ?',
      whereArgs: [keyUploadPreset],
    );
    if (res.isNotEmpty) {
      final val = (res.first['setting_value'] as String?)?.trim() ?? '';
      if (val.isNotEmpty) return val;
    }
    return defaultUploadPreset;
  }

  Future<void> saveConfig({
    required String cloudName,
    required String uploadPreset,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.execute(
      'INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at) VALUES (?, ?, ?);',
      [keyCloudName, cloudName.trim(), now],
    );
    await db.execute(
      'INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at) VALUES (?, ?, ?);',
      [keyUploadPreset, uploadPreset.trim(), now],
    );
  }

  /// Upload a local image file to Cloudinary and return the direct HTTPS URL
  Future<CloudinaryUploadResult> uploadImageFile(File file, {String? tag}) async {
    try {
      if (!file.existsSync()) {
        return const CloudinaryUploadResult(success: false, errorMessage: 'File not found');
      }

      final cloudName = await getCloudName();
      final uploadPreset = await getUploadPreset();

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'slips';
      if (tag != null && tag.isNotEmpty) {
        request.fields['tags'] = tag;
      }

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String?;
        final publicId = data['public_id'] as String?;
        return CloudinaryUploadResult(
          success: true,
          url: secureUrl,
          publicId: publicId,
        );
      } else {
        String msg = 'Upload failed: ${response.statusCode}';
        try {
          final errData = jsonDecode(response.body);
          if (errData['error']?['message'] != null) {
            msg = errData['error']['message'];
          }
        } catch (_) {}
        return CloudinaryUploadResult(success: false, errorMessage: msg);
      }
    } catch (e) {
      if (kDebugMode) print('Cloudinary upload error: $e');
      return CloudinaryUploadResult(success: false, errorMessage: e.toString());
    }
  }

  /// Upload raw image bytes to Cloudinary
  Future<CloudinaryUploadResult> uploadBytes(Uint8List bytes, {String? filename, String? tag}) async {
    try {
      final cloudName = await getCloudName();
      final uploadPreset = await getUploadPreset();

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'slips';
      if (tag != null && tag.isNotEmpty) {
        request.fields['tags'] = tag;
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename ?? 'slip_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String?;
        final publicId = data['public_id'] as String?;
        return CloudinaryUploadResult(
          success: true,
          url: secureUrl,
          publicId: publicId,
        );
      } else {
        return CloudinaryUploadResult(success: false, errorMessage: 'Failed ${response.statusCode}');
      }
    } catch (e) {
      return CloudinaryUploadResult(success: false, errorMessage: e.toString());
    }
  }
}
