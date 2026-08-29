import 'dart:math';

import '../../chess_engine/domain/models/board_state.dart';
import '../../chess_engine/domain/models/move.dart';
import '../../chess_engine/domain/models/piece.dart';
import '../../chess_engine/domain/move_generator.dart';
import 'evaluator.dart';

/// Thrown internally to unwind the recursion the instant the time budget
/// for this move is spent, from however deep the search currently is.
/// Caught only by [MinimaxEngine.findBestMove]'s iterative-deepening
/// loop — never escapes the engine.
class _SearchTimeUp implements Exception {
  const _SearchTimeUp();
}

/// A checkmate score, offset by remaining depth so the engine prefers a
/// forced mate in 2 over a forced mate in 5 (and, symmetrically, delays
/// an inevitable mate against it as long as possible rather than
/// resigning into the fastest loss).
const int _mateScore = 1000000;

/// Custom minimax/negamax search with alpha-beta pruning and iterative
/// deepening — the Phase 6 "full control" alternative to bridging
/// Stockfish (see [AiDifficulty]'s class doc for why this project takes
/// that path). Operates directly on [BoardState] + [MoveGenerator]
/// rather than through [ChessEngine], since the engine facade's move
/// history / SAN / repetition bookkeeping is pure overhead for a search
/// that visits thousands of positions it immediately discards.
class MinimaxEngine {
  const MinimaxEngine._();

  /// Searches from [root] and returns the best move found, or null if
  /// [root] has no legal moves (checkmate/stalemate — callers shouldn't
  /// invoke this in that case, but it's handled defensively).
  ///
  /// Iterative deepening runs depth 1, then 2, then 3, ... up to
  /// [maxDepth], stopping early if [deadline] passes. Each completed
  /// depth's result overwrites the previous one, so the search always
  /// has *a* legal answer ready even if it's interrupted mid-depth —
  /// only a fully-finished depth's move is ever returned.
  static Move? findBestMove(
    BoardState root, {
    required int maxDepth,
    required DateTime deadline,
    bool addVariety = false,
    Random? random,
  }) {
    final List<Move> rootMoves = MoveGenerator.legalMoves(root);
    if (rootMoves.isEmpty) return null;
    if (rootMoves.length == 1) return rootMoves.first;

    Move bestMove = rootMoves.first;
    List<_ScoredMove> lastCompletedRanking = <_ScoredMove>[
      _ScoredMove(rootMoves.first, 0),
    ];

    for (int depth = 1; depth <= maxDepth; depth++) {
      try {
        final List<_ScoredMove> ranked = _searchRoot(root, depth, deadline);
        ranked.sort((a, b) => b.score.compareTo(a.score));
        lastCompletedRanking = ranked;
        bestMove = ranked.first.move;
      } on _SearchTimeUp {
        break;
      }
    }

    if (addVariety && lastCompletedRanking.length > 1) {
      final int topScore = lastCompletedRanking.first.score;
      // "Near-equal" = within half a pawn of the best move, matching how
      // a club-level player treats a handful of moves as basically
      // interchangeable rather than always finding the engine-exact best.
      final List<Move> nearBest = lastCompletedRanking
          .where((sm) => (topScore - sm.score) <= 50)
          .map((sm) => sm.move)
          .toList();
      final Random rng = random ?? Random();
      bestMove = nearBest[rng.nextInt(nearBest.length)];
    }

    return bestMove;
  }

  static List<_ScoredMove> _searchRoot(BoardState root, int depth, DateTime deadline) {
    final List<Move> moves = _orderedMoves(root, MoveGenerator.legalMoves(root));
    final List<_ScoredMove> results = <_ScoredMove>[];

    int alpha = -_mateScore - 1;
    const int beta = _mateScore + 1;

    for (final Move move in moves) {
      final BoardState next = root.applyMove(move);
      final int score = -_negamax(next, depth - 1, -beta, -alpha, deadline);
      results.add(_ScoredMove(move, score));
      if (score > alpha) alpha = score;
    }

    return results;
  }

  static int _negamax(
    BoardState state,
    int depth,
    int alpha,
    int beta,
    DateTime deadline,
  ) {
    if (DateTime.now().isAfter(deadline)) throw const _SearchTimeUp();

    final List<Move> moves = MoveGenerator.legalMoves(state);

    if (moves.isEmpty) {
      final bool inCheck = MoveGenerator.isKingInCheck(state, state.sideToMove);
      if (!inCheck) return 0; // Stalemate.
      // Checkmate against the side to move: as bad as possible, but
      // nearer mates score more negative than farther ones so the
      // search (one ply up, via negation) prefers forcing the quicker
      // mate and, when losing, prefers surviving longer.
      return -_mateScore - depth;
    }

    if (depth == 0) {
      final int white = Evaluator.evaluate(state);
      return state.sideToMove == PieceColor.white ? white : -white;
    }

    final List<Move> ordered = _orderedMoves(state, moves);
    int best = -_mateScore - 1;

    for (final Move move in ordered) {
      final BoardState next = state.applyMove(move);
      final int score = -_negamax(next, depth - 1, -beta, -alpha, deadline);
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break; // Alpha-beta cutoff.
    }

    return best;
  }

  /// MVV-LVA (Most Valuable Victim - Least Valuable Attacker) move
  /// ordering: try captures of high-value pieces with low-value pieces
  /// first, then promotions, then everything else. Search a good move
  /// early and alpha-beta prunes far more of the tree — this is a much
  /// bigger performance lever than it looks for how little code it is.
  static List<Move> _orderedMoves(BoardState state, List<Move> moves) {
    int scoreOf(Move m) {
      int s = 0;
      if (m.isCapture) {
        final PieceType? victimType = state.pieceAt(m.to)?.type;
        final PieceType attackerType = state.pieceAt(m.from)!.type;
        final int victimValue = victimType?.value ?? 1; // en passant: pawn.
        s += 1000 + victimValue * 10 - attackerType.value;
      }
      if (m.isPromotion) s += 900;
      return s;
    }

    final List<Move> copy = List<Move>.of(moves);
    copy.sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
    return copy;
  }
}

class _ScoredMove {
  const _ScoredMove(this.move, this.score);
  final Move move;
  final int score;
}
