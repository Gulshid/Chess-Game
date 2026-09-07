import 'package:flutter/material.dart';

import '../core/constant/app_colors.dart';
import '../core/constant/app_constants.dart';
import 'start_screen.dart';

/// The app's very first screen: an animated brand moment before landing
/// on [StartScreen]. Previously the app opened directly on the start
/// screen with no launch identity at all — this gives it one.
///
/// Purely a presentation-layer addition: it doesn't touch app
/// bootstrapping (Firebase/Hive init still happen in `main()` before
/// `runApp`), it just occupies the first couple of seconds on screen
/// with something intentional instead of nothing.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _markScale;
  late final Animation<double> _markOpacity;
  late final Animation<double> _markRotation;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _sweepProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    _markScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.12).chain(CurveTween(curve: Curves.easeOutBack)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.55)));

    _markOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
    );

    _markRotation = Tween<double>(begin: -0.15, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.35, 0.7, curve: Curves.easeOutCubic)),
    );
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.7, curve: Curves.easeIn),
    );

    _taglineOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.85, curve: Curves.easeIn),
    );

    _sweepProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 1.0, curve: Curves.easeInOutCubic),
    );

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 450), _goToStart);
      }
    });
  }

  void _goToStart() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => const StartScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Layered radial-gradient backdrop, deepening from a
              // faint violet glow behind the mark out to the app's near-
              // black base color.
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.2),
                    radius: 1.1,
                    colors: [Color(0xFF232B52), AppColors.scaffoldBackground],
                  ),
                ),
              ),
              // A soft diagonal light sweep that travels across the
              // screen once as the mark and title settle in.
              Positioned.fill(
                child: ClipRect(
                  child: CustomPaint(
                    painter: _SweepPainter(progress: _sweepProgress.value),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _markOpacity.value,
                      child: Transform.rotate(
                        angle: _markRotation.value,
                        child: Transform.scale(
                          scale: _markScale.value,
                          child: const _CrownMark(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SlideTransition(
                      position: _titleSlide,
                      child: Opacity(
                        opacity: _titleOpacity.value,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: AppColors.goldGradient,
                          ).createShader(bounds),
                          child: Text(
                            AppConstants.appName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: _taglineOpacity.value,
                      child: Text(
                        'Think three moves ahead.',
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 0.4,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _taglineOpacity.value,
                  child: Center(
                    child: SizedBox(
                      width: 120,
                      height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The splash mark: a stylized crown/king silhouette in a gold circular
/// badge. Drawn with a [CustomPainter] rather than an icon glyph so it
/// has a genuine "brand mark" silhouette instead of a generic Material
/// icon.
class _CrownMark extends StatelessWidget {
  const _CrownMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.goldGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.45),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: CustomPaint(painter: _KingGlyphPainter()),
    );
  }
}

class _KingGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()
      ..color = const Color(0xFF0B0E1A)
      ..style = PaintingStyle.fill;

    final double w = size.width;
    final double h = size.height;
    final Path crown = Path();
    // Simple five-point crown silhouette + cross, scaled to `size`.
    crown.moveTo(w * 0.10, h * 0.62);
    crown.lineTo(w * 0.14, h * 0.30);
    crown.lineTo(w * 0.30, h * 0.46);
    crown.lineTo(w * 0.50, h * 0.20);
    crown.lineTo(w * 0.70, h * 0.46);
    crown.lineTo(w * 0.86, h * 0.30);
    crown.lineTo(w * 0.90, h * 0.62);
    crown.close();
    canvas.drawPath(crown, fill);

    // Base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.10, h * 0.62, w * 0.80, h * 0.14),
        const Radius.circular(3),
      ),
      fill,
    );

    // Cross above the crown.
    final Paint stroke = Paint()
      ..color = const Color(0xFF0B0E1A)
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.5, h * 0.02), Offset(w * 0.5, h * 0.18), stroke);
    canvas.drawLine(Offset(w * 0.42, h * 0.08), Offset(w * 0.58, h * 0.08), stroke);
  }

  @override
  bool shouldRepaint(covariant _KingGlyphPainter oldDelegate) => false;
}

/// A single diagonal light band that sweeps left-to-right once,
/// driven by [progress] (0 to 1).
class _SweepPainter extends CustomPainter {
  _SweepPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double bandWidth = size.width * 0.5;
    final double travel = size.width + bandWidth;
    final double x = -bandWidth + travel * progress;

    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(x, 0, bandWidth, size.height));

    canvas.save();
    canvas.transform(Matrix4.skewX(-0.35).storage);
    canvas.drawRect(Rect.fromLTWH(x, -size.height, bandWidth, size.height * 3), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SweepPainter oldDelegate) => oldDelegate.progress != progress;
}
