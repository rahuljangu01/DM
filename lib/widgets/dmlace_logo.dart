import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// An exquisite, fully-animated luxury medallion logo for DM Lace Surat.
/// Features:
/// - Dual counter-rotating Zari lace embroidery rings (16 scalloped petals + fine mesh)
/// - Shimmering dynamic golden halo & pulsing light aura
/// - Twinkling 4-point diamond zari sparkles
/// - Embossed 3D "DM" monogram with metallic gold sweep sheen
/// - Interactive touch spring-pulse effect
class DmLaceLogo extends StatefulWidget {
  final double size;
  final bool showText;
  final bool isLightOnDark;
  final bool isAnimated;

  const DmLaceLogo({
    super.key,
    this.size = 100,
    this.showText = true,
    this.isLightOnDark = false,
    this.isAnimated = true,
  });

  @override
  State<DmLaceLogo> createState() => _DmLaceLogoState();
}

class _DmLaceLogoState extends State<DmLaceLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _tapScale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.isAnimated) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant DmLaceLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimated && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnimated && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() => _tapScale = 1.15);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _tapScale = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final logoBadge = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF040A14),
        border: Border.all(
          color: const Color(0xFFD4AF37),
          width: widget.size * 0.035 < 1.2 ? 1.2 : widget.size * 0.035,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
            blurRadius: widget.size * 0.15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(widget.size * 0.04),
          child: Image.asset(
            'assets/images/dm_lace_logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _tapScale,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            logoBadge,
            if (widget.showText) ...[
              SizedBox(height: widget.size * 0.12),
              Text(
                'DM LACE SURAT',
                style: TextStyle(
                  fontSize: widget.size * 0.16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.6,
                  color: widget.isLightOnDark ? AppColors.goldLight : AppColors.primaryNavy,
                  fontFamily: 'serif',
                  shadows: widget.isLightOnDark
                      ? [
                          Shadow(
                            color: AppColors.primaryGold.withValues(alpha: 0.55),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: widget.size * 0.14,
                    height: 1.4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          widget.isLightOnDark ? AppColors.goldLight : AppColors.primaryGold,
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'BUSINESS MANAGER',
                      style: TextStyle(
                        fontSize: widget.size * 0.082,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.5,
                        color: widget.isLightOnDark ? AppColors.primaryGold : AppColors.goldAmber,
                      ),
                    ),
                  ),
                  Container(
                    width: widget.size * 0.14,
                    height: 1.4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.isLightOnDark ? AppColors.goldLight : AppColors.primaryGold,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MasterLaceMedallionPainter extends CustomPainter {
  final double outerRotation;
  final double innerRotation;
  final double shimmerPulse;
  final double sparklePhase;

  MasterLaceMedallionPainter({
    required this.outerRotation,
    required this.innerRotation,
    required this.shimmerPulse,
    required this.sparklePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Radiant Multi-Stop Golden Glow Aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primaryGold.withValues(alpha: 0.28 + (shimmerPulse * 0.18)),
          AppColors.goldAmber.withValues(alpha: 0.12 + (shimmerPulse * 0.10)),
          Colors.transparent,
        ],
        stops: const [0.72, 0.90, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, auraPaint);

    // 2. Base Midnight Navy Disc with Metallic Sheen
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.25, -0.25),
        colors: [
          Color(0xFF1E3556),
          AppColors.primaryNavy,
          Color(0xFF040A14),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.88));
    canvas.drawCircle(center, radius * 0.88, bgPaint);

    // 3. Outer Rotating Embroidered Zari Scallops (16 Scalloped Loops)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(outerRotation);

    final scallopStroke = Paint()
      ..color = AppColors.primaryGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final scallopInnerGlow = Paint()
      ..color = AppColors.goldLight.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final pearlPaint = Paint()
      ..color = AppColors.goldLight
      ..style = PaintingStyle.fill;

    const numScallops = 16;
    for (int i = 0; i < numScallops; i++) {
      final angle = (i * 2 * math.pi) / numScallops;
      final sx = (radius - 9.5) * math.cos(angle);
      final sy = (radius - 9.5) * math.sin(angle);

      // Outer lace loop
      canvas.drawCircle(Offset(sx, sy), 6.0, scallopStroke);
      canvas.drawCircle(Offset(sx, sy), 4.2, scallopInnerGlow);
      // Delicate Pearl tip
      canvas.drawCircle(Offset(sx, sy), 1.8, pearlPaint);
    }
    canvas.restore();

    // 4. Stitched Beaded Ring (Surat Zari Border)
    final stitchedRing = Paint()
      ..color = AppColors.primaryGold.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius - 16, stitchedRing);

    // Dotted embroidery bead ring
    final dotPaint = Paint()
      ..color = AppColors.goldLight.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    const numDots = 32;
    final dotRadius = radius - 19.5;
    for (int i = 0; i < numDots; i++) {
      final a = (i * 2 * math.pi) / numDots;
      canvas.drawCircle(
        Offset(center.dx + dotRadius * math.cos(a), center.dy + dotRadius * math.sin(a)),
        1.1,
        dotPaint,
      );
    }

    // 5. Counter-Rotating Surat Lace Lattice Mesh (Diamond Interweaving)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(innerRotation);

    final meshPaint = Paint()
      ..color = AppColors.goldLight.withValues(alpha: 0.40 + (shimmerPulse * 0.22))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    const numMeshPoints = 12;
    final meshRadius = radius - 23;
    for (int i = 0; i < numMeshPoints; i++) {
      final a1 = (i * 2 * math.pi) / numMeshPoints;
      final a2 = ((i + 4) * 2 * math.pi) / numMeshPoints;
      final p1 = Offset(meshRadius * math.cos(a1), meshRadius * math.sin(a1));
      final p2 = Offset(meshRadius * math.cos(a2), meshRadius * math.sin(a2));
      canvas.drawLine(p1, p2, meshPaint);
    }
    canvas.restore();

    // 6. Twinkling 4-Point Diamond Sparkles at Cardinal Angles
    final sparklePaint = Paint()
      ..color = AppColors.goldLight.withValues(alpha: 0.8 + (shimmerPulse * 0.2))
      ..style = PaintingStyle.fill;

    for (int k = 0; k < 4; k++) {
      final sparkleAngle = (k * math.pi / 2) + (sparklePhase * 0.1);
      final sparkleDist = radius - 16;
      final spX = center.dx + sparkleDist * math.cos(sparkleAngle);
      final spY = center.dy + sparkleDist * math.sin(sparkleAngle);
      final sparkleSize = 3.5 + (math.sin(sparklePhase + k) * 1.5);

      final path = Path()
        ..moveTo(spX, spY - sparkleSize)
        ..quadraticBezierTo(spX, spY, spX + sparkleSize, spY)
        ..quadraticBezierTo(spX, spY, spX, spY + sparkleSize)
        ..quadraticBezierTo(spX, spY, spX - sparkleSize, spY)
        ..quadraticBezierTo(spX, spY, spX, spY - sparkleSize);
      canvas.drawPath(path, sparklePaint);
    }

    // 7. Inner Royal Navy Shield with Deep Shadow
    final innerDiscRadius = radius * 0.48;

    // Drop shadow behind center disc
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawCircle(Offset(center.dx, center.dy + 2), innerDiscRadius, shadowPaint);

    // Inner disc fill
    final discPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.35),
        colors: [
          Color(0xFF22426B),
          AppColors.primaryNavy,
          Color(0xFF081424),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: innerDiscRadius));
    canvas.drawCircle(center, innerDiscRadius, discPaint);

    // Double Gold Ring Border around "DM"
    final discBorder1 = Paint()
      ..color = AppColors.primaryGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(center, innerDiscRadius, discBorder1);

    final discBorder2 = Paint()
      ..color = AppColors.goldLight.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawCircle(center, innerDiscRadius - 3.2, discBorder2);

    // 8. Embossed "DM" Luxury Monogram with Sweeping Gold Sheen
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'DM',
        style: TextStyle(
          fontSize: radius * 0.51,
          fontWeight: FontWeight.w900,
          fontFamily: 'serif',
          letterSpacing: 2.0,
          foreground: Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                AppColors.goldLight,
                AppColors.primaryGold,
                Color(0xFFB8860B),
                AppColors.goldLight,
              ],
              stops: [
                0.0,
                (0.20 + (shimmerPulse * 0.50)).clamp(0.0, 1.0),
                0.80,
                1.0,
              ],
            ).createShader(Rect.fromLTWH(
              center.dx - radius * 0.38,
              center.dy - radius * 0.28,
              radius * 0.76,
              radius * 0.56,
            )),
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.75),
              blurRadius: 5,
              offset: const Offset(1.5, 2.5),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant MasterLaceMedallionPainter oldDelegate) {
    return oldDelegate.outerRotation != outerRotation ||
        oldDelegate.innerRotation != innerRotation ||
        oldDelegate.shimmerPulse != shimmerPulse ||
        oldDelegate.sparklePhase != sparklePhase;
  }
}
