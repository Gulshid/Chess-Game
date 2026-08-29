import '../../chess_engine/domain/board_utils.dart';
import '../../chess_engine/domain/models/board_state.dart';
import '../../chess_engine/domain/models/piece.dart';
import '../../chess_engine/domain/move_generator.dart';
import 'piece_square_tables.dart';

/// Turns a [BoardState] into a single centipawn score, positive meaning
/// White is better and negative meaning Black is better — the standard
/// evaluation-function convention, kept side-agnostic on purpose so
/// [MinimaxEngine]'s negamax search can flip the sign uniformly per ply
/// instead of branching on color everywhere.
class Evaluator {
  const Evaluator._();

  static const Map<PieceType, int> _materialCentipawns = <PieceType, int>{
    PieceType.pawn: 100,
    PieceType.knight: 320,
    PieceType.bishop: 330,
    PieceType.rook: 500,
    PieceType.queen: 900,
    PieceType.king: 0,
  };

  /// Small per-legal-move bonus. This is intentionally cheap (counts
  /// pseudo-legal moves, not fully-legal ones, to avoid a second legality
  /// pass per node) — mobility only needs to be directionally right to
  /// nudge the search away from cramped positions, not exact.
  static const int _mobilityWeightCentipawns = 2;

  static int evaluate(BoardState state) {
    int score = 0;

    for (int square = 0; square < 64; square++) {
      final Piece? piece = state.squares[square];
      if (piece == null) continue;

      final int material = _materialCentipawns[piece.type]!;
      final int tableSquare =
          piece.color == PieceColor.white ? square : _mirrorVertically(square);
      final int positional = PieceSquareTables.bonusFor(piece.type, tableSquare);

      final int contribution = material + positional;
      score += piece.color == PieceColor.white ? contribution : -contribution;
    }

    final int whiteMobility =
        MoveGenerator.pseudoLegalMoves(_asSideToMove(state, PieceColor.white)).length;
    final int blackMobility =
        MoveGenerator.pseudoLegalMoves(_asSideToMove(state, PieceColor.black)).length;
    score += (whiteMobility - blackMobility) * _mobilityWeightCentipawns;

    return score;
  }

  static int _mirrorVertically(int square) => squareAt(fileOf(square), 7 - rankOf(square));

  /// `pseudoLegalMoves` generates for whichever color is `sideToMove` on
  /// the given state. Evaluation needs *both* sides' mobility from the
  /// same snapshot, so this returns a shallow copy with `sideToMove`
  /// swapped when needed — cheap since `BoardState.copyWith` doesn't
  /// duplicate the square list unless it changes.
  static BoardState _asSideToMove(BoardState state, PieceColor color) =>
      state.sideToMove == color ? state : state.copyWith(sideToMove: color);
}
