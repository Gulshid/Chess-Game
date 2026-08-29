import '../../chess_engine/domain/board_utils.dart';
import '../../chess_engine/domain/models/piece.dart';

/// Classic piece-square tables (values in centipawns), one per piece
/// type, encouraging pieces toward historically-strong squares — e.g.
/// knights toward the center and away from the rim, king toward safety
/// behind pawns in the middlegame.
///
/// Tables below are written rank-8-to-rank-1, file-a-to-file-h (the
/// conventional way these tables are printed/read), then converted at
/// load time into this engine's square-index convention (0 = a1 ...
/// 63 = h8, see `board_utils.dart`) via [_fromPrintedTable]. That keeps
/// the literal arrays readable/checkable against any reference table
/// while still indexing correctly against [BoardState.squares].
class PieceSquareTables {
  const PieceSquareTables._();

  static const List<int> _pawnPrinted = <int>[
    0, 0, 0, 0, 0, 0, 0, 0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
  ];

  static const List<int> _knightPrinted = <int>[
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  ];

  static const List<int> _bishopPrinted = <int>[
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
  ];

  static const List<int> _rookPrinted = <int>[
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
  ];

  static const List<int> _queenPrinted = <int>[
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
  ];

  /// King safety table for the middlegame — favors tucking behind pawn
  /// cover; the roadmap doesn't call for a separate endgame king table,
  /// so this project uses one table across the whole game as a
  /// deliberate scope cut (documented here rather than silently
  /// approximated) rather than adding game-phase detection.
  static const List<int> _kingPrinted = <int>[
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 20, 0, 0, 0, 0, 20, 20,
    20, 30, 10, 0, 0, 10, 30, 20,
  ];

  static final List<int> pawn = _fromPrintedTable(_pawnPrinted);
  static final List<int> knight = _fromPrintedTable(_knightPrinted);
  static final List<int> bishop = _fromPrintedTable(_bishopPrinted);
  static final List<int> rook = _fromPrintedTable(_rookPrinted);
  static final List<int> queen = _fromPrintedTable(_queenPrinted);
  static final List<int> king = _fromPrintedTable(_kingPrinted);

  /// Converts a table written top-row-is-rank-8 into one indexed by this
  /// engine's `squareAt(file, rank)` convention.
  static List<int> _fromPrintedTable(List<int> printed) {
    final List<int> out = List<int>.filled(64, 0);
    for (int printedRow = 0; printedRow < 8; printedRow++) {
      final int rank = 7 - printedRow; // printed row 0 is rank 8.
      for (int file = 0; file < 8; file++) {
        out[squareAt(file, rank)] = printed[printedRow * 8 + file];
      }
    }
    return out;
  }

  /// Returns the positional bonus for [type] at [square], from White's
  /// perspective. Callers mirror the square vertically for Black (see
  /// [Evaluator]) since these tables are all White-relative by
  /// construction (a knight on the 1st rank is bad for White regardless
  /// of which color the table is "for").
  static int bonusFor(PieceType type, int square) => switch (type) {
        PieceType.pawn => pawn[square],
        PieceType.knight => knight[square],
        PieceType.bishop => bishop[square],
        PieceType.rook => rook[square],
        PieceType.queen => queen[square],
        PieceType.king => king[square],
      };
}
