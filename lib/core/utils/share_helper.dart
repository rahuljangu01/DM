import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareHelper {
  /// Simple plain text sharing
  static Future<void> shareText(String text, {String? subject}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
        ),
      );
    } catch (_) {
      // Graceful fallback for headless/test environments
    }
  }

  /// Resolve file or asset path into a local File suitable for XFile sharing
  static Future<File?> resolveFileOrAsset(String path) async {
    try {
      if (kIsWeb) return null; // Web platforms rely on browser downloads or text

      final cleanPath = path.trim();
      if (cleanPath.isEmpty) return null;

      // 1. Direct device storage file
      final localFile = File(cleanPath);
      if (await localFile.exists()) {
        return localFile;
      }

      // 2. Bundled Flutter asset (e.g. assets/images/...)
      if (cleanPath.startsWith('assets/')) {
        final byteData = await rootBundle.load(cleanPath);
        final tempDir = await getTemporaryDirectory();
        final fileName = cleanPath.split('/').last;
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(
          byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
        return tempFile;
      }
    } catch (_) {}
    return null;
  }

  /// Share single image/file with message caption (WhatsApp sets text directly as image caption)
  static Future<void> shareImageWithText({
    String? imagePath,
    required String text,
    String? subject,
  }) async {
    try {
      if (imagePath != null && imagePath.trim().isNotEmpty) {
        final resolved = await resolveFileOrAsset(imagePath.trim());
        if (resolved != null && await resolved.exists()) {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(resolved.path)],
              text: text,
              subject: subject,
            ),
          );
          return;
        }
      }
    } catch (_) {}

    // Fallback to text share if image is absent or unresolvable
    await shareText(text, subject: subject);
  }

  /// Share multiple images with text caption
  static Future<void> shareMultipleImagesWithText({
    required List<String> imagePaths,
    required String text,
    String? subject,
  }) async {
    try {
      final List<XFile> xFiles = [];
      for (final p in imagePaths) {
        if (p.trim().isEmpty) continue;
        final resolved = await resolveFileOrAsset(p.trim());
        if (resolved != null && await resolved.exists()) {
          xFiles.add(XFile(resolved.path));
        }
      }

      if (xFiles.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            files: xFiles,
            text: text,
            subject: subject,
          ),
        );
        return;
      }
    } catch (_) {}

    // Fallback to text share
    await shareText(text, subject: subject);
  }
}
