import 'dart:math' as math;
import 'package:flutter/material.dart';

class AuspiciousDivineBanner extends StatefulWidget {
  const AuspiciousDivineBanner({super.key});

  @override
  State<AuspiciousDivineBanner> createState() => _AuspiciousDivineBannerState();
}

class _AuspiciousDivineBannerState extends State<AuspiciousDivineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        // Breathing pulse between 0.0 and 1.0
        final pulse = (math.sin(progress * 2 * math.pi) + 1.0) / 2.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF5B1E05),
                Color(0xFF9A3412),
                Color(0xFFB45309),
                Color(0xFF78350F),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFFD4AF37),
                const Color(0xFFFFFBEB),
                pulse,
              )!,
              width: 1.0 + 0.4 * pulse,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.30 + 0.25 * pulse),
                blurRadius: 8.0 + 6.0 * pulse,
                spreadRadius: 0.5 + 0.5 * pulse,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Left Sparkle
              Opacity(
                opacity: 0.6 + 0.4 * pulse,
                child: const Text('✨', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 5),

              // Animated Golden Shimmer Text
              ShaderMask(
                shaderCallback: (bounds) {
                  // Shimmer gradient sliding from left (-1.0) to right (2.0)
                  final shimmerOffset = progress * 3.0 - 1.0;
                  return LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [
                      (shimmerOffset - 0.3).clamp(0.0, 1.0),
                      shimmerOffset.clamp(0.0, 1.0),
                      (shimmerOffset + 0.3).clamp(0.0, 1.0),
                    ],
                    colors: const [
                      Color(0xFFFDE047), // Deep warm gold
                      Color(0xFFFFFFFF), // Radiant bright white gold flash
                      Color(0xFFFDE047), // Deep warm gold
                    ],
                  ).createShader(bounds);
                },
                // EN: "Lord Ganesha Blessing & Auspicious Prosperity"
                child: const Text(
                  '👑 ॥ श्री गणेशाय नमः ॥ • ॥ शुभ-लाभ ॥ 👑',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              const SizedBox(width: 5),
              // Right Sparkle
              Opacity(
                opacity: 0.6 + 0.4 * (1.0 - pulse),
                child: const Text('✨', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        );
      },
    );
  }
}
