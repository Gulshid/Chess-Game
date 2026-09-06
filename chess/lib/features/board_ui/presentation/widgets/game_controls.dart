import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constant/app_colors.dart';
import '../../../../providers/game_provider.dart';

/// The row of icon-button game controls: undo, flip board, resign,
/// offer draw, and new game.
///
/// Rendered as a floating rounded bar (matching the rest of the app's
/// "surface card" language) instead of bare `IconButton`s sitting
/// directly on the scaffold background, with "New game" picked out in
/// gold as the one primary action in the row.
class GameControls extends StatelessWidget {
  const GameControls({
    super.key,
    required this.game,
    required this.onFlipBoard,
    required this.onNewGame,
    this.onResign,
    this.onOfferDraw,
  });

  final GameProvider game;
  final VoidCallback onFlipBoard;
  final VoidCallback onNewGame;
  final VoidCallback? onResign;
  final VoidCallback? onOfferDraw;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ControlButton(
              icon: Icons.undo_rounded,
              label: 'Undo',
              enabled: game.canUndo,
              onPressed: game.undo,
            ),
            _ControlButton(
              icon: Icons.redo_rounded,
              label: 'Redo',
              enabled: game.canRedo,
              onPressed: game.redo,
            ),
            _ControlButton(
              icon: Icons.swap_vert_rounded,
              label: 'Flip',
              enabled: true,
              onPressed: onFlipBoard,
            ),
            _ControlButton(
              icon: Icons.handshake_outlined,
              label: 'Draw',
              enabled: !game.isGameOver && onOfferDraw != null,
              onPressed: onOfferDraw,
            ),
            _ControlButton(
              icon: Icons.flag_outlined,
              label: 'Resign',
              enabled: !game.isGameOver && onResign != null,
              onPressed: onResign,
              dangerTint: true,
            ),
            _ControlButton(
              icon: Icons.refresh_rounded,
              label: 'New',
              enabled: true,
              onPressed: onNewGame,
              accentTint: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.accentTint = false,
    this.dangerTint = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;
  final bool accentTint;
  final bool dangerTint;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color tint = widget.accentTint
        ? AppColors.gold
        : widget.dangerTint
            ? AppColors.danger
            : Colors.white;
    final Color color = widget.enabled ? tint : Colors.white24;

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.enabled && (widget.accentTint || widget.dangerTint)
                    ? tint.withOpacity(0.14)
                    : Colors.transparent,
              ),
              child: Icon(widget.icon, color: color, size: 22),
            ),
            SizedBox(height: 2.h),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: widget.enabled ? Colors.white70 : Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
