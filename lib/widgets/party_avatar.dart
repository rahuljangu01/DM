import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PartyAvatar extends StatelessWidget {
  final String name;
  final String? imagePath;
  final double size;
  final double? fontSize;
  final String? heroTag;
  final bool showCameraBadge;
  final VoidCallback? onCameraTap;
  final VoidCallback? onTap;

  const PartyAvatar({
    super.key,
    required this.name,
    this.imagePath,
    this.size = 38.0,
    this.fontSize,
    this.heroTag,
    this.showCameraBadge = false,
    this.onCameraTap,
    this.onTap,
  });

  // Dynamic luxury gradient palette for avatars based on party name
  static const List<List<Color>> _avatarGradients = [
    [Color(0xFF1E3A8A), Color(0xFF3B82F6)], // Royal Sapphire
    [Color(0xFF065F46), Color(0xFF10B981)], // Emerald Velvet
    [Color(0xFF9A3412), Color(0xFFF97316)], // Sunset Amber
    [Color(0xFF581C87), Color(0xFF9333EA)], // Regal Plum
    [Color(0xFF0E7490), Color(0xFF06B6D4)], // Deep Ocean
    [Color(0xFF9F1239), Color(0xFFF43F5E)], // Ruby Crimson
    [Color(0xFF854D0E), Color(0xFFEAB308)], // Surat Zari Gold
    [Color(0xFF312E81), Color(0xFF6366F1)], // Midnight Indigo
    [Color(0xFF115E59), Color(0xFF14B8A6)], // Vibrant Teal
    [Color(0xFF831843), Color(0xFFEC4899)], // Rose Velvet
  ];

  List<Color> get _gradientForName {
    final clean = name.trim().toLowerCase();
    if (clean.isEmpty) return _avatarGradients[0];
    final sum = clean.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return _avatarGradients[sum % _avatarGradients.length];
  }

  String get _initial {
    final clean = name.trim();
    if (clean.isEmpty) return 'P';
    return clean[0].toUpperCase();
  }

  Widget _buildInitialAvatar(double diameter, double calcFontSize) {
    final gradient = _gradientForName;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initial,
          style: TextStyle(
            fontSize: calcFontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String path, double diameter, Widget fallback) {
    if (kIsWeb || path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:')) {
      return Image.network(
        path,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else {
      try {
        final file = io.File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: diameter,
            height: diameter,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          );
        }
      } catch (_) {}
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final calcFontSize = fontSize ?? (size * 0.42);
    final fallback = _buildInitialAvatar(size, calcFontSize);

    Widget avatarCore;
    final hasImage = imagePath != null && imagePath!.trim().isNotEmpty;

    if (hasImage) {
      avatarCore = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: _buildImageWidget(imagePath!.trim(), size, fallback),
          ),
        ),
      );
    } else {
      avatarCore = fallback;
    }

    if (onTap != null) {
      avatarCore = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: avatarCore,
      );
    }

    if (heroTag != null && heroTag!.isNotEmpty) {
      avatarCore = Hero(
        tag: heroTag!,
        child: avatarCore,
      );
    }

    if (!showCameraBadge) {
      return avatarCore;
    }

    // Camera badge overlay for profile photo upload / change
    final badgeSize = (size * 0.32).clamp(24.0, 36.0);
    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        avatarCore,
        Positioned(
          right: -2,
          bottom: -2,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCameraTap ?? onTap,
              borderRadius: BorderRadius.circular(badgeSize / 2),
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFFDE047)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: badgeSize * 0.55,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
