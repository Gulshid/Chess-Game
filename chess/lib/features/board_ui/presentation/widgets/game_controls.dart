import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../providers/game_provider.dart';

/// The row of icon-button game controls: undo, flip board, resign,
/// offer draw, and new game.
///
/// Resign and draw-offer have no online opponent to notify yet (that's
/// Phase 7), so here they simply end the local game — resign counts as
/// a loss for [game.sideToMove], and "offer draw" against the current
/// setup (local pass-and-play, or Phase 6's AI) is accepted immediately
/// since there's no human on the other end to decline it.
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          icon: Icons.undo,
          label: 'Undo',
          enabled: game.canUndo,
          onPressed: game.undo,
        ),
        _ControlButton(
          icon: Icons.redo,
          label: 'Redo',
          enabled: game.canRedo,
          onPressed: game.redo,
        ),
        _ControlButton(
          icon: Icons.swap_vert,
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
        ),
        _ControlButton(
          icon: Icons.refresh,
          label: 'New',
          enabled: true,
          onPressed: onNewGame,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: enabled ? onPressed : null,
          tooltip: label,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: enabled ? Colors.white70 : Colors.white24,
          ),
        ),
      ],
    );
  }
}
