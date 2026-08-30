import 'package:flutter/material.dart';

import '../../ai/data/ai_opponent.dart';
import '../../ai/domain/ai_difficulty.dart';
import '../../chess_engine/domain/san.dart';
import '../../../providers/game_provider.dart';

/// "Move hints / 'best move' suggestion (using the AI engine from
/// Phase 6) for practice mode" — Phase 8.
///
/// Deliberately reuses [AiOpponent] (Phase 6) rather than a separate
/// search — a hint and an AI move are the same computation ("what's the
/// best move here"), just surfaced to the human instead of played
/// automatically. Runs at a fixed, fairly strong depth
/// ([AiDifficulty.hard]) regardless of whatever difficulty an active AI
/// opponent is set to, since a hint should show the *best* move
/// available, not an intentionally-weakened one.
///
/// Rather than drawing a bespoke arrow overlay on the board (which would
/// mean reaching into `ChessBoard`'s internals), this highlights the
/// hint by selecting its origin square through [GameProvider.selectSquare]
/// — the board already renders legal-move dots for a selection,
/// including the hinted destination, so the player sees exactly where to
/// look with zero changes to the Phase 5 board widget.
class HintButton extends StatefulWidget {
  const HintButton({super.key, required this.game});

  final GameProvider game;

  @override
  State<HintButton> createState() => _HintButtonState();
}

class _HintButtonState extends State<HintButton> {
  bool _isSearching = false;

  Future<void> _showHint() async {
    if (_isSearching || widget.game.isGameOver) return;
    setState(() => _isSearching = true);

    final move = await AiOpponent.findBestMove(
      fen: widget.game.fen,
      difficulty: AiDifficulty.hard,
    );

    if (!mounted) return;
    setState(() => _isSearching = false);

    if (move == null) return;

    final String san = San.forMove(widget.game.engine.state, move);
    widget.game.selectSquare(move.from);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Hint: $san'), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _isSearching
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.lightbulb_outline),
      tooltip: 'Hint',
      onPressed: widget.game.isGameOver ? null : _showHint,
    );
  }
}
