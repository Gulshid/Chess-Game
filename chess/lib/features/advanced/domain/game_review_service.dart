import 'dart:isolate';

import '../../ai/domain/evaluator.dart';
import '../../chess_engine/domain/chess_engine.dart';
import '../../chess_engine/domain/fen.dart';
import '../../chess_engine/domain/models/board_state.dart';
import '../../chess_engine/domain/models/move.dart';
import '../../chess_engine/domain/models/piece.dart';
import '../../chess_engine/domain/move_generator.dart';
import 'move_annotation.dart';

/// Post-game analysis: "highlighting blunders/mistakes/good moves (using
/// engine eval deltas)", per the roadmap's Phase 8 quality-of-life
/// section.
///
/// For every move actually played, this compares the position's
/// evaluation after that move against the best evaluation achievable
/// from the same position (found by trying every legal reply), and
/// buckets the gap into a [MoveQuality] via [MoveQuality.fromCentipawnLoss].
///
/// This intentionally does NOT reuse `MinimaxEngine`/`AiOpponent`
/// (Phase 6): those are tuned to pick strong *moves* quickly for an
/// opponent, and don't expose the numeric score a review needs. The
/// search here is a small, self-contained negamax kept local to this
/// feature, at a shallow fixed depth — accurate enough to catch real
/// blunders (hung pieces, missed mate) without the multi-second-per-move
/// budget `AiDifficulty.expert` uses, since a review may need to score
/// 80+ positions in one pass.
class GameReviewService {
  const GameReviewService._();

  /// How many plies of lookahead the review search uses per candidate
  /// move. Kept shallow deliberately — see the class doc.
  static const int _searchDepth = 2;

  /// Replays [moves] from [startingFen] (defaulting to the standard
  /// starting position) and returns one [AnnotatedMove] per ply.
  static Future<List<AnnotatedMove>> review({
    required List<Move> moves,
    String? startingFen,
  }) async {
    if (moves.isEmpty) return const <AnnotatedMove>[];

    // Replay on the main isolate first to capture the FEN before/after
    // each ply and the SAN the engine already knows how to generate —
    // cheap, and needed regardless of the scoring step below.
    final ChessEngine replay =
        startingFen == null ? ChessEngine.initial() : ChessEngine.fromFen(startingFen);

    final List<String> fensBefore = <String>[];
    final List<String> fensAfter = <String>[];
    for (final Move move in moves) {
      fensBefore.add(replay.fen);
      final bool applied = replay.makeMove(move);
      if (!applied) {
        throw StateError('Illegal move ${move.uci} encountered while replaying for review.');
      }
      fensAfter.add(replay.fen);
    }
    final List<String> sanMoves = replay.sanHistory;

    // The actual scoring is CPU-heavy across a whole game, so it runs on
    // a background isolate — same reasoning as `AiOpponent` (Phase 6):
    // this must never freeze the review screen while it churns through
    // every move of the game.
    final List<int> losses = await Isolate.run(
      () => _scoreAllMoves(fensBefore, moves.map((m) => m.uci).toList(growable: false)),
    );

    return List<AnnotatedMove>.generate(moves.length, (int i) {
      return AnnotatedMove(
        plyIndex: i,
        san: sanMoves[i],
        quality: MoveQuality.fromCentipawnLoss(losses[i]),
        centipawnLoss: losses[i],
        fenBefore: fensBefore[i],
        fenAfter: fensAfter[i],
      );
    });
  }

  /// Runs entirely inside the spawned isolate. Only primitive types
  /// (String, int, List of those) cross the isolate boundary, hence
  /// working in FEN/UCI strings rather than [Move]/[BoardState] objects.
  static List<int> _scoreAllMoves(List<String> fensBefore, List<String> playedUci) {
    final List<int> losses = <int>[];
    for (int i = 0; i < fensBefore.length; i++) {
      final BoardState before = Fen.parse(fensBefore[i]);
      final List<Move> legal = MoveGenerator.legalMoves(before);

      int bestScore = -_mateScore - 1;
      int playedScore = -_mateScore - 1;

      for (final Move candidate in legal) {
        final BoardState after = before.applyMove(candidate);
        final int score = -_negamax(after, _searchDepth - 1, -_mateScore, _mateScore);
        if (score > bestScore) bestScore = score;
        if (candidate.uci == playedUci[i]) playedScore = score;
      }

      // Defensive fallback: should always find the played move among
      // the legal moves of its own pre-move position.
      if (playedScore == -_mateScore - 1) playedScore = bestScore;

      final int loss = bestScore - playedScore;
      losses.add(loss < 0 ? 0 : loss);
    }
    return losses;
  }

  static const int _mateScore = 1000000;

  /// Negamax with alpha-beta, scored from the side-to-move's perspective
  /// (positive = good for whoever is about to move in [state]).
  static int _negamax(BoardState state, int depth, int alpha, int beta) {
    final List<Move> moves = MoveGenerator.legalMoves(state);

    if (moves.isEmpty) {
      final bool inCheck = MoveGenerator.isKingInCheck(state, state.sideToMove);
      return inCheck ? -_mateScore + (10 - depth) : 0; // checkmate vs stalemate
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
