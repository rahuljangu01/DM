import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../core/utils/share_helper.dart';

class InteractiveSlipViewer extends StatelessWidget {
  final String? imagePath;
  final String? imageBase64;
  final String? imageUrl;
  final String title;

  const InteractiveSlipViewer({
    super.key,
    this.imagePath,
    this.imageBase64,
    this.imageUrl,
    this.title = 'चालान / बिल पर्ची',
  });

  static void show(
    BuildContext context, {
    String? imagePath,
    String? imageBase64,
    String? imageUrl,
    String title = 'चालान / बिल पर्ची',
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => InteractiveSlipViewer(
          imagePath: imagePath,
          imageBase64: imageBase64,
          imageUrl: imageUrl,
          title: title,
        ),
      ),
    );
  }

  Future<void> _shareImage(BuildContext context) async {
    try {
      if (imagePath != null && File(imagePath!).existsSync()) {
        await ShareHelper.shareImageWithText(imagePath: imagePath!, text: title);
      } else if (imageBase64 != null && imageBase64!.isNotEmpty) {
        final bytes = base64Decode(imageBase64!);
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/shared_slip_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(bytes);
        await ShareHelper.shareImageWithText(imagePath: file.path, text: title);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('शेयर करने में त्रुटि: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocalFile = imagePath != null && File(imagePath!).existsSync();
    final hasBase64 = imageBase64 != null && imageBase64!.isNotEmpty;
    final canShare = hasLocalFile || hasBase64;

    Widget imageWidget;
    if (hasLocalFile) {
      imageWidget = Image.file(
        File(imagePath!),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildFallbackOrError(),
      );
    } else if (imageUrl != null && imageUrl!.startsWith('http')) {
      imageWidget = Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
        },
        errorBuilder: (context, error, stackTrace) => _buildFallbackOrError(),
      );
    } else if (hasBase64) {
      try {
        final bytes = base64Decode(imageBase64!);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackOrError(),
        );
      } catch (_) {
        imageWidget = _buildFallbackOrError();
      }
    } else if (imagePath != null && imagePath!.isNotEmpty) {
      imageWidget = Image.asset(
        imagePath!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildFallbackOrError(),
      );
    } else {
      imageWidget = _buildFallbackOrError();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (canShare)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              tooltip: 'शेयर करें',
              onPressed: () => _shareImage(context),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 6.0,
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _buildFallbackOrError() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_rounded, size: 48, color: Colors.white38),
          SizedBox(height: 8),
          Text(
            'फोटो लोड नहीं हो सकी',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
