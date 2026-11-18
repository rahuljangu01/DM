import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A magnificent, ultra-high-definition, deeply animated divine artwork of Lord Ganesha (श्री विनायक).
/// Designed exclusively for DM Lace Surat.
/// Features:
/// - Real photo of Lord Ganesha idol (intricate Mumbai street festival idol) inside the sanctum
/// - Clockwise Surya Sunburst Mandala with 32 alternating rays and golden orbs
/// - Counter-clockwise Surat Lace & Pearl Mandala with 24 intricate lace scallops
/// - 8 Orbiting celestial starlight sparkles dancing along mathematical paths
/// - Twin auspicious Aarti Diyas with realistic double-layer flickering flames
/// - Multi-tone royal golden sweep frame with pearl bead accents
/// - Breathing celestial golden aura expansion
class GaneshaDivineArtwork extends StatefulWidget {
  final double size;

  const GaneshaDivineArtwork({
    super.key,
    this.size = 230,
  });

  @override
  State<GaneshaDivineArtwork> createState() => _GaneshaDivineArtworkState();
}

class _GaneshaDivineArtworkState extends State<GaneshaDivineArtwork>
    with TickerProviderStateMixin {
  late AnimationController _clockwiseRotation;
  late AnimationController _counterRotation;
  late AnimationController _breathingPulse;
  late AnimationController _sparkleOrbit;
  late AnimationController _flameFlicker;

  @override
  void initState() {
    super.initState();
    // 1. Slow, majestic 24-second clockwise sunburst rotation
    _clockwiseRotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    // 2. Counter-clockwise 18-second intricate lace halo rotation
    _counterRotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    // 3. Divine breathing pulse (2800ms) for celestial aura expansion
    _breathingPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    // 4. Orbiting celestial starlight particles (9s cycle)
    _sparkleOrbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();

    // 5. Realistic flickering Aarti diya flames (450ms)
    _flameFlicker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _clockwiseRotation.dispose();
    _counterRotation.dispose();
    _breathingPulse.dispose();
    _sparkleOrbit.dispose();
    _flameFlicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sanctumDiameter = widget.size * 0.74;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _clockwiseRotation,
        _counterRotation,
        _breathingPulse,
        _sparkleOrbit,
        _flameFlicker,
      ]),
      builder: (context, _) {
        final pulse = _breathingPulse.value;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Background Animated Mandalas & Rays
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _GaneshaBackgroundPainter(
                  clockwise: _clockwiseRotation.value,
                  counter: _counterRotation.value,
                  pulse: pulse,
                  orbit: _sparkleOrbit.value,
                ),
              ),

              // 2. Real Photo of Lord Ganesha clipped in Divine Circular Sanctum
              Container(
                width: sanctumDiameter,
                height: sanctumDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35 + 0.15 * pulse),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.60),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/ganesh_idol_real.jpg',
                        fit: BoxFit.cover,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) {
                            return child;
                          }
                          return Container(
                            color: const Color(0xFF140822),
                            child: const Center(
                              child: Text(
                                'ॐ',
                                style: TextStyle(
                                  fontSize: 48,
                                  color: Color(0xFFFDE047),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          // Graceful fallback for headless test environments
                          return Container(
                            color: const Color(0xFF1E102E),
                            child: const Center(
                              child: Text(
                                'ॐ',
                                style: TextStyle(
                                  fontSize: 48,
                                  color: Color(0xFFFDE047),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Sacred Golden Ambient Vignette & Warmth
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFFB45309).withValues(alpha: 0.10 + 0.05 * pulse),
                              const Color(0xFF07040D).withValues(alpha: 0.42),
                            ],
                            stops: const [0.60, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Foreground Royal Golden Border Frame & Twin Sacred Diyas
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _GaneshaForegroundPainter(
                  pulse: pulse,
                  flame: _flameFlicker.value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Paints the outer rotating mandalas, sunburst rays, and orbiting sparkles
class _GaneshaBackgroundPainter extends CustomPainter {
  final double clockwise;
  final double counter;
  final double pulse;
  final double orbit;

  _GaneshaBackgroundPainter({
    required this.clockwise,
    required this.counter,
    required this.pulse,
    required this.orbit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final radius = size.width / 2.0;

    // LAYER 1: Deep Celestial Golden Aura (दिव्य अलौकिक आभामंडल)
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF59E0B).withValues(alpha: 0.45 + 0.18 * pulse),
          const Color(0xFFD97706).withValues(alpha: 0.28 + 0.12 * pulse),
          const Color(0xFF78350F).withValues(alpha: 0.14 + 0.06 * pulse),
          Colors.transparent,
        ],
        stops: const [0.26, 0.58, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));

    canvas.drawCircle(Offset(cx, cy), radius, auraPaint);

    // LAYER 2: Orbiting Sacred Golden Starlight Sparkles
    for (int i = 0; i < 8; i++) {
      final sparkleAngle = (orbit * 2 * math.pi) + (i * (2 * math.pi / 8));
      final orbitRadius = radius * (0.88 + 0.08 * math.sin(sparkleAngle * 2 + pulse));
      final sx = cx + math.cos(sparkleAngle) * orbitRadius;
      final sy = cy + math.sin(sparkleAngle) * orbitRadius;
      final sparkleScale = (math.sin(sparkleAngle * 3 + pulse * math.pi) + 1.0) / 2.0;

      final sparklePaint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFDE047),
          const Color(0xFFFFFBEB),
          sparkleScale,
        )!.withValues(alpha: 0.40 + 0.60 * sparkleScale)
        ..style = PaintingStyle.fill;

      final starSize = 2.2 + 2.8 * sparkleScale;
      final starPath = Path()
        ..moveTo(sx, sy - starSize)
        ..lineTo(sx + starSize * 0.35, sy - starSize * 0.35)
        ..lineTo(sx + starSize, sy)
        ..lineTo(sx + starSize * 0.35, sy + starSize * 0.35)
        ..lineTo(sx, sy + starSize)
        ..lineTo(sx - starSize * 0.35, sy + starSize * 0.35)
        ..lineTo(sx - starSize, sy)
        ..lineTo(sx - starSize * 0.35, sy - starSize * 0.35)
        ..close();
      canvas.drawPath(starPath, sparklePaint);
    }

    // LAYER 3: Outer Counter-Rotating Surat Lace Scallop Ring (18s)
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-counter * 2 * math.pi);

    final laceRingRadius = radius * 0.90;
    final laceScallopPaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.38 + 0.18 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;

    for (int i = 0; i < 24; i++) {
      final angle = (i * 2 * math.pi) / 24;
      final nextAngle = ((i + 1) * 2 * math.pi) / 24;
      final midAngle = (angle + nextAngle) / 2.0;

      final x1 = math.cos(angle) * (laceRingRadius - 8);
      final y1 = math.sin(angle) * (laceRingRadius - 8);
      final xm = math.cos(midAngle) * laceRingRadius;
      final ym = math.sin(midAngle) * laceRingRadius;
      final x2 = math.cos(nextAngle) * (laceRingRadius - 8);
      final y2 = math.sin(nextAngle) * (laceRingRadius - 8);

      final scallop = Path()
        ..moveTo(x1, y1)
        ..quadraticBezierTo(xm, ym, x2, y2);
      canvas.drawPath(scallop, laceScallopPaint);

      final pearlPaint = Paint()
        ..color = const Color(0xFFFFFBEB).withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(xm, ym), 1.6, pearlPaint);
    }
    canvas.restore();

    // LAYER 4: Inner Clockwise-Rotating Golden Sunburst (24s, 32 Surya Rays)
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(clockwise * 2 * math.pi);

    final rayPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFFBEB), Color(0xFFFBBF24), Color(0xFFD97706)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * 0.86))
      ..strokeWidth = size.width * 0.012
      ..strokeCap = StrokeCap.round;

    final rayDotPaint = Paint()
      ..color = const Color(0xFFFDE047).withValues(alpha: 0.85 + 0.15 * pulse)
      ..style = PaintingStyle.fill;

    final sunRadius = radius * 0.86;
    for (int i = 0; i < 32; i++) {
      final angle = (i * 2 * math.pi) / 32;
      final isMajor = i % 4 == 0;
      final isMedium = i % 2 == 0;
      final innerR = sunRadius - (isMajor ? 16 : (isMedium ? 10 : 6));
      final outerR = sunRadius;

      final x1 = math.cos(angle) * innerR;
      final y1 = math.sin(angle) * innerR;
      final x2 = math.cos(angle) * outerR;
      final y2 = math.sin(angle) * outerR;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), rayPaint);
      if (isMajor) {
        canvas.drawCircle(Offset(x2, y2), 2.6, rayDotPaint);
      }
    }

    final ringPaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset.zero, sunRadius - 16, ringPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GaneshaBackgroundPainter oldDelegate) {
    return oldDelegate.clockwise != clockwise ||
        oldDelegate.counter != counter ||
        oldDelegate.pulse != pulse ||
        oldDelegate.orbit != orbit;
  }
}

/// Paints the foreground royal golden frame border and the twin flickering Aarti Diyas
class _GaneshaForegroundPainter extends CustomPainter {
  final double pulse;
  final double flame;

  _GaneshaForegroundPainter({
    required this.pulse,
    required this.flame,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final sanctumRadius = (size.width / 2.0) * 0.74;

    // Multi-Tone Royal Golden Sweep Frame Border
    final frameBorder = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFDE047),
          Color(0xFFD4AF37),
          Color(0xFFFFFBEB),
          Color(0xFFB45309),
          Color(0xFFFDE047),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: sanctumRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6;
    canvas.drawCircle(Offset(cx, cy), sanctumRadius, frameBorder);

    // Inner Delicate Filigree Ring with Gold Beads
    final innerRing = Paint()
      ..color = const Color(0xFFFFFBEB).withValues(alpha: 0.75 + 0.20 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(cx, cy), sanctumRadius - 4, innerRing);

    // Gold Bead Accents around the frame (36 Auspicious Pearls)
    final beadPaint = Paint()
      ..color = const Color(0xFFFDE047).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    for (int b = 0; b < 36; b++) {
      final beadAngle = (b * 2 * math.pi) / 36;
      final bx = cx + math.cos(beadAngle) * (sanctumRadius - 4);
      final by = cy + math.sin(beadAngle) * (sanctumRadius - 4);
      canvas.drawCircle(Offset(bx, by), 1.1, beadPaint);
    }

    // Twin Sacred Aarti Diyas (शुभ मंगल दीप - बाएँ व दाएँ)
    final diyaY = cy + sanctumRadius * 0.58;
    final diyaLeftX = cx - sanctumRadius * 0.78;
    final diyaRightX = cx + sanctumRadius * 0.78;
    final diyaW = size.width * 0.095;

    _drawDiya(canvas, diyaLeftX, diyaY, diyaW, flame);
    _drawDiya(canvas, diyaRightX, diyaY, diyaW, 1.0 - flame);
  }

  void _drawDiya(Canvas canvas, double x, double y, double w, double flicker) {
    // 1. Brass Diya Bowl (पीतल का दीया)
    final diyaPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFDE047), Color(0xFFD97706), Color(0xFF78350F)],
      ).createShader(Rect.fromLTWH(x - w / 2, y, w, w * 0.5))
      ..style = PaintingStyle.fill;

    final diyaPath = Path()
      ..moveTo(x - w * 0.5, y)
      ..quadraticBezierTo(x, y + w * 0.46, x + w * 0.5, y)
      ..quadraticBezierTo(x, y + w * 0.16, x - w * 0.5, y);
    canvas.drawPath(diyaPath, diyaPaint);

    // Diya Stand
    final standPath = Path()
      ..moveTo(x - w * 0.22, y + w * 0.35)
      ..lineTo(x - w * 0.35, y + w * 0.52)
      ..lineTo(x + w * 0.35, y + w * 0.52)
      ..lineTo(x + w * 0.22, y + w * 0.35)
      ..close();
    canvas.drawPath(standPath, diyaPaint);

    // 2. Animated Radiant Flame Glow
    final flameH = w * (0.95 + 0.30 * flicker);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFEF4444).withValues(alpha: 0.45 + 0.20 * flicker),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(x, y - flameH * 0.5), radius: w * 0.9));
    canvas.drawCircle(Offset(x, y - flameH * 0.5), w * 0.9, glowPaint);

    // 3. Sacred Golden Fire Flame (अग्नि शिखा)
    final flamePath = Path()
      ..moveTo(x - w * 0.24, y)
      ..cubicTo(
        x - w * 0.32, y - flameH * 0.45,
        x + (flicker - 0.5) * 3, y - flameH,
        x, y - flameH,
      )
      ..cubicTo(
        x + (flicker - 0.5) * 3, y - flameH,
        x + w * 0.32, y - flameH * 0.45,
        x + w * 0.24, y,
      )
      ..close();

    final flameShader = RadialGradient(
      colors: const [
        Color(0xFFFFFBEB), // White-hot core
        Color(0xFFFBBF24), // Pure gold flame
        Color(0xFFDC2626), // Saffron ruby tip
      ],
      stops: const [0.15, 0.55, 1.0],
    ).createShader(Rect.fromCenter(center: Offset(x, y - flameH * 0.45), width: w * 0.6, height: flameH));

    canvas.drawPath(flamePath, Paint()..shader = flameShader);
  }

  @override
  bool shouldRepaint(covariant _GaneshaForegroundPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.flame != flame;
  }
}
