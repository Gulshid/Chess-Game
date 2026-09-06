import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// How the just-finished game relates to whoever is looking at this
/// dialog. [GameScreen] derives this the same way it already derives
/// `SavedGameOutcome` for history — see its `_saveFinishedGameOnce` doc
/// for the "local 2-player has no single 'me'" reasoning that also
/// applies here; that case (and any other non-win/non-loss ending) is
/// [neutral].
enum GameOverOutcome { win, loss, draw, neutral }

/// The roadmap's Phase 11 "Micro-animations: … victory/defeat screens,
/// confetti or subtle celebration on win" line item, replacing the
/// plain `AlertDialog` [GameScreen] used to show for every game ending
/// alike. Scales and fades in on open, and a win additionally gets a
/// brief burst of falling confetti behind the message — built with a
/// `CustomPainter` rather than a package so it needs no new dependency
/// or asset. A loss or draw intentionally stays understated (no
/// confetti, muted color) so the celebration reads as specific to
/// actually winning, not just "a game ended."
///
/// This only builds presentation — call sites still own *when* to show
/// it and what happens after (new game, review, etc.) via [actions],
/// exactly like the `AlertDialog` it replaces.
class GameOverDialog extends StatefulWidget {
  const GameOverDialog({
    super.key,
    required this.headline,
    required this.outcome,
    required this.actions,
  });

  /// The human-readable result, e.g. "White wins by checkmate" — callers
  /// already compute this (see `GameScreen._statusHeadline`); this
  /// widget only decides how to present it, not what it says.
  final String headline;
  final GameOverOutcome outcome;

  /// Same role as `AlertDialog.actions` — typically "Close", "New game",
  /// "Review this game".
  final List<Widget> actions;

  @override
  State<GameOverDialog> createState() => _GameOverDialogState();
}

class _GameOverDialogState extends State<GameOverDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _accentColor(BuildContext context) => switch (widget.outcome) {
        GameOverOutcome.win => const Color(0xFF00C853),
        GameOverOutcome.loss => const Color(0xFFE53935),
        GameOverOutcome.draw => const Color(0xFFFFC107),
        GameOverOutcome.neutral => Theme.of(context).colorScheme.primary,
      };

  IconData _icon() => switch (widget.outcome) {
        GameOverOutcome.win => Icons.emoji_events,
        GameOverOutcome.loss => Icons.sentiment_dissatisfied,
        GameOverOutcome.draw => Icons.handshake,
        GameOverOutcome.neutral => Icons.flag,
      };

  @override
  Widget build(BuildContext context) {
    final Color accent = _accentColor(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.scale(scale: 0.85 + 0.15 * _scale.value, child: child),
        );
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.outcome == GameOverOutcome.win)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => CustomPaint(
                      painter: _ConfettiPainter(progress: _controller.value, accent: accent),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon(), color: accent, size: 56.sp),
                  SizedBox(height: 16.h),
                  Text(
                    widget.headline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 20.h),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: widget.actions,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short burst of falling confetti rectangles, drawn once per frame of
/// [GameOverDialog]'s own open animation rather than looping forever —
/// the roadmap calls for "confetti or subtle celebration on win," not a
/// persistent distraction sitting on top of the result the player is
/// trying to read.
///
/// Deliberately a hand-rolled [CustomPainter] instead of a confetti
/// package: this is a fixed, tiny set of pre-seeded particles animated
/// by a single [progress] value already owned by the dialog, so pulling
/// in a whole particle-system dependency (with its own controller/
/// disposal lifecycle to wire up) would be more machinery than the
/// effect needs.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  static const int _particleCount = 24;
  static final List<_ConfettiParticle> _particles = _buildParticles();

  static List<_ConfettiParticle> _buildParticles() {
    final Random random = Random(7); // Fixed seed: a stable, repeatable burst.
    return List<_ConfettiParticle>.generate(_particleCount, (_) {
      return _ConfettiParticle(
        startX: random.nextDouble(),
        fallDistance: 0.5 + random.nextDouble() * 0.5,
        drift: (random.nextDouble() - 0.5) * 0.3,
        size: 4 + random.nextDouble() * 5,
        hueShift: random.nextDouble(),
        rotationSpeed: (random.nextDouble() - 0.5) * 6,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final Paint paint = Paint();

    for (final _ConfettiParticle p in _particles) {
      final double fallProgress = Curves.easeOut.transform(progress);
      final double dx = (p.startX + p.drift * fallProgress) * size.width;
      final double dy = p.fallDistance * fallProgress * size.height * 0.5;
      final double opacity = (1 - progress).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      paint.color = Color.lerp(accent, Colors.white, p.hueShift)!.withValues(alpha: opacity * 0.85);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotationSpeed * fallProgress);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 1.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}

class _ConfettiParticle {
  const _ConfettiParticle({
    required this.startX,
    required this.fallDistance,
    required this.drift,
    required this.size,
    required this.hueShift,
    required this.rotationSpeed,
  });

  final double startX;
  final double fallDistance;
  final double drift;
  final double size;
  final double hueShift;
  final double rotationSpeed;
}
