import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/localization/language_provider.dart';
import '../core/security/pin_service.dart';
import '../core/security/auth_service.dart';
import '../widgets/ganesha_artwork.dart';
import 'pin_screen.dart';
import 'auth/auth_screen.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool hasPinConfigured;

  const SplashScreen({super.key, this.hasPinConfigured = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  late AnimationController _shimmerController;
  late AnimationController _particleController;
  late AnimationController _progressController;

  bool _hasNavigated = false;
  bool _didPrecache = false;

  @override
  void initState() {
    super.initState();

    // Ensure edge-to-edge dark system bars on mobile immediately
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF03050B),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    // 1. Instant smooth entrance: starts at 85% opacity so frame 1 is instantly visible
    // with no dark screen pause on mobile
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    // 2. Continuous golden shimmer sweep on sacred mantra
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    // 3. Continuous gentle floating golden stardust particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    // 4. Smooth 4.2-second auto-launch progress for effortless entry & peaceful Darshan
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToDashboard();
      }
    });

    _entranceController.forward();
    _progressController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecache) {
      _didPrecache = true;
      precacheImage(const AssetImage('assets/images/ganesh_idol_real.jpg'), context);
      precacheImage(const AssetImage('assets/images/dm_lace_logo.png'), context);
    }
  }

  void _navigateToDashboard() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _progressController.stop();

    final targetRoute = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        if (!AuthService.isLoggedInSync) {
          return const AuthScreen();
        } else if (widget.hasPinConfigured && PinService.isPinEnabled) {
          return const PinScreen(isSettingPin: false);
        } else {
          return const MainNavigationScreen();
        }
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );

    Navigator.of(context).pushReplacement(targetRoute);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF03050B),
      body: GestureDetector(
        onTap: _navigateToDashboard,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // ===================================================================
            // LAYER 1: Deep Royal Velvet & Midnight Navy Gradient Backdrop
            // ===================================================================
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF020309), // Midnight Abyss Top
                      Color(0xFF160726), // Deep Royal Velvet Burgundy
                      Color(0xFF0B1428), // Deep Sapphire Midnight
                      Color(0xFF03050F), // Ground Navy
                    ],
                    stops: [0.0, 0.35, 0.70, 1.0],
                  ),
                ),
              ),
            ),

            // ===================================================================
            // LAYER 2: Sacred Temple Corner Filigree Architectural Ornamentation
            // ===================================================================
            Positioned.fill(
              child: CustomPaint(
                painter: _SacredTempleFiligreePainter(),
              ),
            ),

            // ===================================================================
            // LAYER 3: Ambient Golden Sanctum Radial Breathing Warmth
            // ===================================================================
            Positioned(
              top: MediaQuery.of(context).size.height * 0.10,
              left: 0,
              right: 0,
              height: 420,
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) {
                  final breathe = (math.sin(_particleController.value * 2 * math.pi) + 1.0) / 2.0;
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFF59E0B).withValues(alpha: 0.16 + 0.08 * breathe),
                          const Color(0xFFD4AF37).withValues(alpha: 0.07 + 0.04 * breathe),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.48, 0.88],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ===================================================================
            // LAYER 4: Animated Floating Golden Stardust & Divine Flower Petals (à¤ªà¥à¤·à¥à¤ª à¤µà¤°à¥à¤·à¤¾)
            // ===================================================================
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _GoldenStardustPainter(
                      progress: _particleController.value,
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _PushpaVarshaPainter(
                      progress: _particleController.value,
                    ),
                  );
                },
              ),
            ),

            // ===================================================================
            // LAYER 5: Pure & Elegant Sanctum: Ganesh Ji & Company Logo
            // ===================================================================
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenHeight = constraints.maxHeight;
                    final isShortScreen = screenHeight < 680;

                    final ganeshaSize = isShortScreen ? 200.0 : 260.0;
                    final logoSize = isShortScreen ? 76.0 : 92.0;

                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Spacer(flex: 2),

                                // 1. Lord Ganesha Divine Centerpiece (Grand & Majestic)
                                GaneshaDivineArtwork(size: ganeshaSize),

                                SizedBox(height: isShortScreen ? 18 : 28),

                                // 2. Company Logo & Brand Name
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: logoSize,
                                      height: logoSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const SweepGradient(
                                          colors: [
                                            Color(0xFFFDE047),
                                            Color(0xFFD4AF37),
                                            Color(0xFFFFFBEB),
                                            Color(0xFFB45309),
                                            Color(0xFFFDE047),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFD4AF37).withValues(alpha: 0.50),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.50),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(2.5),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF0F081C),
                                        ),
                                        padding: const EdgeInsets.all(2.0),
                                        child: ClipOval(
                                          child: Image.asset(
                                            'assets/images/dm_lace_logo.png',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ShaderMask(
                                      shaderCallback: (bounds) => const LinearGradient(
                                        colors: [
                                          Color(0xFFFFFFFF),
                                          Color(0xFFFFFBEB),
                                          Color(0xFFFDE047),
                                          Color(0xFFD4AF37),
                                        ],
                                        stops: [0.0, 0.25, 0.65, 1.0],
                                      ).createShader(bounds),
                                      child: Text(
                                        'DM LACE SURAT',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isShortScreen ? 20 : 24,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2.8,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black,
                                              blurRadius: 12,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const Spacer(flex: 3),

                                // 3. Clean Elegant Entry Button
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _navigateToDashboard,
                                    borderRadius: BorderRadius.circular(30),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isShortScreen ? 28 : 34,
                                        vertical: isShortScreen ? 11 : 13,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFFFBEB),
                                            Color(0xFFFDE047),
                                            Color(0xFFD4AF37),
                                            Color(0xFFB45309),
                                          ],
                                          stops: [0.0, 0.35, 0.75, 1.0],
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: const Color(0xFFFFFBEB).withValues(alpha: 0.75),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                                            blurRadius: 18,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        AuthService.isLoggedInSync
                                            ? lang.tr(
                                                en: 'Open Shop Accounts ➔',
                                                hi: 'दुकान हिसाब खोलें ➔',
                                              )
                                            : lang.tr(
                                                en: 'Sign In / Register ➔',
                                                hi: 'खाता लॉगिन / साइन अप ➔',
                                              ),
                                        style: TextStyle(
                                          color: const Color(0xFF0F172A),
                                          fontSize: isShortScreen ? 14 : 15,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                AnimatedBuilder(
                                  animation: _progressController,
                                  builder: (context, _) {
                                    return Container(
                                      width: 90,
                                      height: 2.2,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: _progressController.value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
                                            ),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: isShortScreen ? 4 : 10),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Auspicious Falling Marigold & Rose Flower Petals (à¤ªà¥à¤·à¥à¤ª à¤µà¤°à¥à¤·à¤¾) Painter
class _PushpaVarshaPainter extends CustomPainter {
  final double progress;

  _PushpaVarshaPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(108); // Sacred seed
    for (int i = 0; i < 20; i++) {
      final baseX = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      final speed = 0.35 + rand.nextDouble() * 0.65;
      final petalSize = 5.0 + rand.nextDouble() * 5.0;

      final currentY = (baseY + (progress * size.height * speed)) % size.height;
      final sway = math.sin((progress * 2 * math.pi) + (i * 0.9)) * 20.0;
      final currentX = (baseX + sway) % size.width;
      final rotation = (progress * 2 * math.pi * (i.isEven ? 1 : -1)) + (i * 0.5);

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(rotation);

      final isRose = i % 3 == 0;
      final isMarigold = i % 3 == 1;

      final petalPaint = Paint()
        ..shader = LinearGradient(
          colors: isRose
              ? [const Color(0xFFF43F5E), const Color(0xFFBE123C)] // Fresh Sacred Rose
              : (isMarigold
                  ? [const Color(0xFFFDE047), const Color(0xFFEA580C)] // Golden Marigold
                  : [const Color(0xFFFEF08A), const Color(0xFFD97706)]), // Golden Petal
        ).createShader(Rect.fromCenter(center: Offset.zero, width: petalSize, height: petalSize * 1.5))
        ..style = PaintingStyle.fill;

      // Draw petal path (delicate tapered oval with curved tip)
      final petalPath = Path()
        ..moveTo(0, -petalSize * 0.75)
        ..cubicTo(petalSize * 0.55, -petalSize * 0.4, petalSize * 0.55, petalSize * 0.4, 0, petalSize * 0.75)
        ..cubicTo(-petalSize * 0.55, petalSize * 0.4, -petalSize * 0.55, -petalSize * 0.4, 0, -petalSize * 0.75)
        ..close();

      canvas.drawPath(petalPath, petalPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PushpaVarshaPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Floating Golden Stardust & Celestial Twinkle Sparkles Painter
class _GoldenStardustPainter extends CustomPainter {
  final double progress;

  _GoldenStardustPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 22; i++) {
      final baseX = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      final speed = 0.4 + rand.nextDouble() * 0.8;
      final particleSize = 1.0 + rand.nextDouble() * 2.2;

      final currentY = (baseY - (progress * size.height * speed)) % size.height;
      final sway = math.sin((progress * 2 * math.pi) + (i * 0.7)) * 14.0;
      final currentX = (baseX + sway) % size.width;

      final twinkle = (math.sin((progress * 4 * math.pi) + (i * 1.3)) + 1.0) / 2.0;

      paint.color = Color.lerp(
        const Color(0xFFF59E0B),
        const Color(0xFFFFFBEB),
        twinkle,
      )!.withValues(alpha: 0.15 + 0.55 * twinkle);

      if (i % 5 == 0) {
        // Draw 4-point golden celestial sparkle
        final starSize = 2.0 + 3.0 * twinkle;
        final starPath = Path()
          ..moveTo(currentX, currentY - starSize)
          ..quadraticBezierTo(currentX, currentY, currentX + starSize, currentY)
          ..quadraticBezierTo(currentX, currentY, currentX, currentY + starSize)
          ..quadraticBezierTo(currentX, currentY, currentX - starSize, currentY)
          ..quadraticBezierTo(currentX, currentY, currentX, currentY - starSize);
        canvas.drawPath(starPath, paint);
      } else {
        canvas.drawCircle(Offset(currentX, currentY), particleSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoldenStardustPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Traditional Indian Sacred Temple Filigree Architectural Corner Motifs
class _SacredTempleFiligreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final goldLinePaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final pearlPaint = Paint()
      ..color = const Color(0xFFFFFBEB).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    const cornerSize = 75.0;

    // Top-Left Corner Filigree
    _drawCornerMotif(canvas, 0, 0, 1, 1, cornerSize, goldLinePaint, pearlPaint);

    // Top-Right Corner Filigree
    _drawCornerMotif(canvas, size.width, 0, -1, 1, cornerSize, goldLinePaint, pearlPaint);

    // Bottom-Left Corner Filigree
    _drawCornerMotif(canvas, 0, size.height, 1, -1, cornerSize, goldLinePaint, pearlPaint);

    // Bottom-Right Corner Filigree
    _drawCornerMotif(canvas, size.width, size.height, -1, -1, cornerSize, goldLinePaint, pearlPaint);
  }

  void _drawCornerMotif(
    Canvas canvas,
    double ox,
    double oy,
    double dx,
    double dy,
    double s,
    Paint linePaint,
    Paint dotPaint,
  ) {
    final path = Path()
      ..moveTo(ox + dx * s, oy)
      ..cubicTo(ox + dx * (s * 0.4), oy, ox, oy + dy * (s * 0.4), ox, oy + dy * s)
      ..moveTo(ox + dx * (s * 0.7), oy)
      ..cubicTo(ox + dx * (s * 0.3), oy, ox, oy + dy * (s * 0.3), ox, oy + dy * (s * 0.7));
    canvas.drawPath(path, linePaint);

    canvas.drawCircle(Offset(ox + dx * (s * 0.38), oy + dy * (s * 0.38)), 1.8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
