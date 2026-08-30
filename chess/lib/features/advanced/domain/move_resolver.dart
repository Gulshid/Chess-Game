import '../../chess_engine/domain/models/board_state.dart';
import '../../chess_engine/domain/models/move.dart';
import '../../chess_engine/domain/move_generator.dart';
import '../../chess_engine/domain/san.dart';

/// Resolves a textual move (SAN, as found in a PGN, or UCI, as found in
/// puzzle solutions / multiplayer wire format) into the concrete [Move]
/// object the engine needs, by matching it against the legal moves of a
/// given position.
///
/// This lives in `features/advanced` rather than `chess_engine/domain`
/// because it is a *consumer* of the engine's public move-generation +
/// SAN facilities, not a rule of chess itself — Phase 2/3's engine
/// contract (`ChessEngine`, `San`) stays untouched, exactly as the
/// roadmap warns against reopening those phases.
class MoveResolver {
  const MoveResolver._();

  /// Finds the legal move in [position] whose SAN (ignoring a trailing
  /// `+`/`#`/`!`/`?` annotation glyphs some PGN exporters add) matches
  /// [san]. Returns null if no legal move matches.
  static Move? fromSan(BoardState position, String san) {
    final String normalized = _stripAnnotations(san);
    final List<Move> legal = MoveGenerator.legalMoves(position);
    for (final Move move in legal) {
      if (_stripAnnotations(San.forMove(position, move)) == normalized) {
        return move;
      }
    }
    return null;
  }

  /// Finds the legal move in [position] whose UCI string (e.g. `e2e4`,
  /// `e7e8q`) matches [uci].
  static Move? fromUci(BoardState position, String uci) {
    final List<Move> legal = MoveGenerator.legalMoves(position);
    for (final Move move in legal) {
      if (move.uci == uci) return move;
    }
    return null;
  }

  static String _stripAnnotations(String san) {
    return san.replaceAll(RegExp(r'[+#!?]+$'), '');
  }
}
