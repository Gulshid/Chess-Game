import 'dart:isolate';
import 'dart:math';

import '../../chess_engine/domain/fen.dart';
import '../../chess_engine/domain/models/move.dart';
import '../../chess_engine/domain/move_generator.dart';
import '../domain/ai_difficulty.dart';
import '../domain/minimax_engine.dart';

/// Public entry point the app calls to get the AI's move for a position.
///
/// Runs the actual search on a separate isolate via [Isolate.run] —
/// alpha-beta search at `expert` depth can take multiple seconds of pure
/// CPU work, and running that on the UI isolate would freeze animations,
/// input, and everything else for the whole thing (the roadmap calls
/// this out explicitly under Phase 11: "background isolate for engine
/// calls so UI never freezes"). [GameProvider] is the only caller —
/// board widgets never touch this class directly.
///
/// [Move] itself can't cross the isolate boundary (only a fixed set of
/// primitive types are isolate-transferable), so the worker returns the
/// move's UCI string and this class re-resolves it against the same
/// position's legal moves on the calling side.
class AiOpponent {
  const AiOpponent._();

  static Future<Move?> findBestMove({
    required String fen,
    required AiDifficulty difficulty,
  }) async {
    final int? seed = difficulty.addsMoveVariety ? Random().nextInt(1 << 31) : null;

    final String? uci = await Isolate.run(
      () => _searchInIsolate(fen, difficulty.maxDepth, difficulty.thinkTime, seed),
    );

    if (uci == null) return null;

    final state = Fen.parse(fen);
    final List<Move> legal = MoveGenerator.legalMoves(state);
    for (final Move m in legal) {
      if (m.uci == uci) return m;
    }
    return null; // Defensive: position/engine mismatch, shouldn't happen.
  }

  static String? _searchInIsolate(
    String fen,
    int maxDepth,
    Duration thinkTime,
    int? varietySeed,
  ) {
    final state = Fen.parse(fen);
    final DateTime deadline = DateTime.now().add(thinkTime);
    final Move? move = MinimaxEngine.findBestMove(
      state,
      maxDepth: maxDepth,
      deadline: deadline,
      addVariety: varietySeed != null,
      random: varietySeed != null ? Random(varietySeed) : null,
    );
    return move?.uci;
  }
}
