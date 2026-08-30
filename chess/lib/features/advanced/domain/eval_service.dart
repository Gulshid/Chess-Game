import 'dart:isolate';

import '../../ai/domain/evaluator.dart';
import '../../chess_engine/domain/fen.dart';
import '../../chess_engine/domain/models/board_state.dart';
import '../../chess_engine/domain/models/move.dart';
import '../../chess_engine/domain/models/piece.dart';
import '../../chess_engine/domain/move_generator.dart';

/// Powers the analysis board's evaluation bar: "optionally surface an
/// evaluation bar for post-game or analysis contexts" (Phase 6) and
/// "run engine evaluation per move" in the analysis board (Phase 8).
///
/// Scores are always White-relative centipawns (positive = White
/// better), matching [Evaluator]'s own convention, so the eval bar
/// widget can map the raw number straight onto a 0.0-1.0 fill fraction
/// without any sign-juggling per side.
///
/// Same background-isolate reasoning as [AiOpponent]/`GameReviewService`:
/// the analysis board calls this on every navigation step, so it must
/// never block the UI thread even for a fraction of a second.
class EvalService {
  const EvalService._();

  static const int _searchDepth = 3;
  static const int _mateScore = 1000000;

  static Future<int> evaluateFen(String fen) => Isolate.run(() => _evaluate(fen));

  static int _evaluate(String fen) {
    final BoardState state = Fen.parse(fen);
    final int score = _negamax(state, _searchDepth, -_mateScore, _mateScore);
    // _negamax returns a side-to-move-relative score; flip back to the
    // White-relative convention this service promises callers.
    return state.sideToMove == PieceColor.white ? score : -score;
  }

  static int _negamax(BoardState state, int depth, int alpha, int beta) {
    final List<Move> moves = MoveGenerator.legalMoves(state);

    if (moves.isEmpty) {
      final bool inCheck = MoveGenerator.isKingInCheck(state, state.sideToMove);
      return inCheck ? -_mateScore + (10 - depth) : 0;
    }

    if (depth <= 0) {
      final int whiteRelative = Evaluator.evaluate(state);
      return state.sideToMove == PieceColor.white ? whiteRelative : -whiteRelative;
    }

    int best = -_mateScore - 1;
    for (final Move move in moves) {
      final int score = -_negamax(state.applyMove(move), depth - 1, -beta, -alpha);
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }
}
