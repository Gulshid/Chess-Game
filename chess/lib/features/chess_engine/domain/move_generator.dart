import 'board_utils.dart';
import 'models/board_state.dart';
import 'models/move.dart';
import 'models/piece.dart';

/// Knight move offsets expressed as (file delta, rank delta).
const List<List<int>> _knightOffsets = <List<int>>[
  [1, 2], [2, 1], [2, -1], [1, -2],
  [-1, -2], [-2, -1], [-2, 1], [-1, 2],
];

/// King move offsets (one step in any of the 8 directions).
const List<List<int>> _kingOffsets = <List<int>>[
  [1, 0], [1, 1], [0, 1], [-1, 1],
  [-1, 0], [-1, -1], [0, -1], [1, -1],
];

const List<List<int>> _bishopDirections = <List<int>>[
  [1, 1], [1, -1], [-1, 1], [-1, -1],
];

const List<List<int>> _rookDirections = <List<int>>[
  [1, 0], [-1, 0], [0, 1], [0, -1],
];

final List<List<int>> _queenDirections = <List<int>>[
  ..._bishopDirections,
  ..._rookDirections,
];

const List<PieceType> _promotionTypes = <PieceType>[
  PieceType.queen,
  PieceType.rook,
  PieceType.bishop,
  PieceType.knight,
];

/// Generates pseudo-legal and legal moves for a [BoardState], and provides
/// the attack-detection primitives (`isSquareAttacked`) that both castling
/// rules and check/checkmate detection depend on.
///
/// Design note: pseudo-legal generation and legality filtering are kept as
/// two separate passes (rather than one combined pass) deliberately — it
/// mirrors how virtually every chess engine is structured, and it means
/// `pseudoLegalMoves` can be unit-tested / perft-tested independently of
/// the "does this leave my king in check" filter.
class MoveGenerator {
  const MoveGenerator._();

  /// All pseudo-legal moves for [state.sideToMove]. "Pseudo-legal" means
  /// geometrically valid but NOT yet filtered for leaving the king in
  /// check — use [legalMoves] for that.
  static List<Move> pseudoLegalMoves(BoardState state) {
    final List<Move> moves = <Move>[];
    final PieceColor us = state.sideToMove;

    for (int square = 0; square < 64; square++) {
      final Piece? piece = state.squares[square];
      if (piece == null || piece.color != us) continue;

      switch (piece.type) {
        case PieceType.pawn:
          _generatePawnMoves(state, square, us, moves);
          break;
        case PieceType.knight:
          _generateOffsetMoves(state, square, us, _knightOffsets, moves);
          break;
        case PieceType.bishop:
          _generateSlidingMoves(state, square, us, _bishopDirections, moves);
          break;
        case PieceType.rook:
          _generateSlidingMoves(state, square, us, _rookDirections, moves);
          break;
        case PieceType.queen:
          _generateSlidingMoves(state, square, us, _queenDirections, moves);
          break;
        case PieceType.king:
          _generateOffsetMoves(state, square, us, _kingOffsets, moves);
          _generateCastlingMoves(state, square, us, moves);
          break;
      }
    }

    return moves;
  }

  /// Filters [pseudoLegalMoves] down to moves that don't leave the mover's
  /// own king in check. This is the function the rest of the engine
  /// (ChessEngine, UI, AI) should actually call.
  static List<Move> legalMoves(BoardState state) {
    final PieceColor us = state.sideToMove;
    final List<Move> pseudo = pseudoLegalMoves(state);
    final List<Move> legal = <Move>[];

    for (final Move move in pseudo) {
      final BoardState after = state.applyMove(move);
      final int? kingSquare = findKingSquare(after, us);
      // A missing king should never happen in a real game, but guard
      // defensively rather than throwing during move generation.
      if (kingSquare == null || !isSquareAttacked(after, kingSquare, us.opposite)) {
        legal.add(move);
      }
    }

    return legal;
  }

  static bool isKingInCheck(BoardState state, PieceColor color) {
    final int? kingSquare = findKingSquare(state, color);
    if (kingSquare == null) return false;
    return isSquareAttacked(state, kingSquare, color.opposite);
  }

  static int? findKingSquare(BoardState state, PieceColor color) {
    for (int square = 0; square < 64; square++) {
      final Piece? piece = state.squares[square];
      if (piece != null && piece.color == color && piece.type == PieceType.king) {
        return square;
      }
    }
    return null;
  }

  /// True if [square] is attacked by any piece of [byColor] in [state].
  /// This does not care whose turn it is — it's a pure geometric check,
  /// which is exactly what's needed for both check detection and castling
  /// legality (you can't castle through or into check).
  static bool isSquareAttacked(BoardState state, int square, PieceColor byColor) {
    final int file = fileOf(square);
    final int rank = rankOf(square);

    // Pawn attacks: a pawn of `byColor` attacks `square` if it sits one
    // diagonal step "behind" it from that pawn's perspective.
    final int pawnRankDelta = byColor == PieceColor.white ? -1 : 1;
    for (final int fileDelta in const <int>[-1, 1]) {
      final int f = file + fileDelta;
      final int r = rank + pawnRankDelta;
      if (isOnBoard(f, r)) {
        final Piece? p = state.squares[squareAt(f, r)];
        if (p != null && p.color == byColor && p.type == PieceType.pawn) {
          return true;
        }
      }
    }

    // Knight attacks.
    for (final List<int> offset in _knightOffsets) {
      final int f = file + offset[0];
      final int r = rank + offset[1];
      if (isOnBoard(f, r)) {
        final Piece? p = state.squares[squareAt(f, r)];
        if (p != null && p.color == byColor && p.type == PieceType.knight) {
          return true;
        }
      }
    }

    // King attacks (adjacent squares).
    for (final List<int> offset in _kingOffsets) {
      final int f = file + offset[0];
      final int r = rank + offset[1];
      if (isOnBoard(f, r)) {
        final Piece? p = state.squares[squareAt(f, r)];
        if (p != null && p.color == byColor && p.type == PieceType.king) {
          return true;
        }
      }
    }

    // Sliding attacks: bishop/queen on diagonals, rook/queen on files/ranks.
    bool slidingAttack(List<List<int>> directions, Set<PieceType> attackerTypes) {
      for (final List<int> dir in directions) {
        int f = file + dir[0];
        int r = rank + dir[1];
        while (isOnBoard(f, r)) {
          final Piece? p = state.squares[squareAt(f, r)];
          if (p != null) {
            if (p.color == byColor && attackerTypes.contains(p.type)) {
              return true;
            }
            break; // blocked, stop scanning this direction
          }
          f += dir[0];
          r += dir[1];
        }
      }
      return false;
    }

    if (slidingAttack(_bishopDirections, const {PieceType.bishop, PieceType.queen})) {
      return true;
    }
    if (slidingAttack(_rookDirections, const {PieceType.rook, PieceType.queen})) {
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------
  // Private generation helpers
  // ---------------------------------------------------------------------

  static void _generateOffsetMoves(
    BoardState state,
    int from,
    PieceColor us,
    List<List<int>> offsets,
    List<Move> out,
  ) {
    final int file = fileOf(from);
    final int rank = rankOf(from);
    for (final List<int> offset in offsets) {
      final int f = file + offset[0];
      final int r = rank + offset[1];
      if (!isOnBoard(f, r)) continue;
      final int to = squareAt(f, r);
      final Piece? target = state.squares[to];
      if (target == null) {
        out.add(Move(from: from, to: to));
      } else if (target.color != us) {
        out.add(Move(from: from, to: to, flag: MoveFlag.capture));
      }
      // else: own piece, blocked — no move.
    }
  }

  static void _generateSlidingMoves(
    BoardState state,
    int from,
    PieceColor us,
    List<List<int>> directions,
    List<Move> out,
  ) {
    final int file = fileOf(from);
    final int rank = rankOf(from);
    for (final List<int> dir in directions) {
      int f = file + dir[0];
      int r = rank + dir[1];
      while (isOnBoard(f, r)) {
        final int to = squareAt(f, r);
        final Piece? target = state.squares[to];
        if (target == null) {
          out.add(Move(from: from, to: to));
        } else {
          if (target.color != us) {
            out.add(Move(from: from, to: to, flag: MoveFlag.capture));
          }
          break; // blocked either way — stop scanning this direction
        }
        f += dir[0];
        r += dir[1];
      }
    }
  }

  static void _generatePawnMoves(
    BoardState state,
    int from,
    PieceColor us,
    List<Move> out,
  ) {
    final int file = fileOf(from);
    final int rank = rankOf(from);
    final int forward = us == PieceColor.white ? 1 : -1;
    final int startRank = us == PieceColor.white ? 1 : 6;
    final int promotionRank = us == PieceColor.white ? 7 : 0;

    void addForwardOrPromotion(int to, MoveFlag flag) {
      if (rankOf(to) == promotionRank) {
        for (final PieceType promo in _promotionTypes) {
          out.add(Move(
            from: from,
            to: to,
            flag: flag == MoveFlag.capture ? MoveFlag.promotionCapture : MoveFlag.promotion,
            promotionType: promo,
          ));
        }
      } else {
        out.add(Move(from: from, to: to, flag: flag));
      }
    }

    // Single push.
    final int oneStepRank = rank + forward;
    if (isOnBoard(file, oneStepRank)) {
      final int oneStep = squareAt(file, oneStepRank);
      if (state.squares[oneStep] == null) {
        addForwardOrPromotion(oneStep, MoveFlag.quiet);

        // Double push, only from the starting rank and only if both
        // intervening squares are empty.
        if (rank == startRank) {
          final int twoStepRank = rank + 2 * forward;
          final int twoStep = squareAt(file, twoStepRank);
          if (state.squares[twoStep] == null) {
            out.add(Move(from: from, to: twoStep, flag: MoveFlag.doublePawnPush));
          }
        }
      }
    }

    // Diagonal captures (including en passant).
    for (final int fileDelta in const <int>[-1, 1]) {
      final int captureFile = file + fileDelta;
      final int captureRank = rank + forward;
      if (!isOnBoard(captureFile, captureRank)) continue;
      final int to = squareAt(captureFile, captureRank);
      final Piece? target = state.squares[to];

      if (target != null && target.color != us) {
        addForwardOrPromotion(to, MoveFlag.capture);
      } else if (target == null && state.enPassantSquare == to) {
        out.add(Move(from: from, to: to, flag: MoveFlag.enPassant));
      }
    }
  }

  static void _generateCastlingMoves(
    BoardState state,
    int kingSquare,
    PieceColor us,
    List<Move> out,
  ) {
    final int rank = us == PieceColor.white ? 0 : 7;
    // King must be on its home square (defensive check — normally implied
    // by castling rights already being false otherwise).
    if (kingSquare != squareAt(4, rank)) return;

    final bool inCheck = isSquareAttacked(state, kingSquare, us.opposite);
    if (inCheck) return; // Can't castle out of check.

    final bool canKingSide =
        us == PieceColor.white ? state.whiteCanCastleKingSide : state.blackCanCastleKingSide;
    final bool canQueenSide =
        us == PieceColor.white ? state.whiteCanCastleQueenSide : state.blackCanCastleQueenSide;

    if (canKingSide) {
      final int f = squareAt(5, rank);
      final int g = squareAt(6, rank);
      final bool pathClear = state.squares[f] == null && state.squares[g] == null;
      final bool pathSafe =
          !isSquareAttacked(state, f, us.opposite) && !isSquareAttacked(state, g, us.opposite);
      if (pathClear && pathSafe) {
        out.add(Move(from: kingSquare, to: g, flag: MoveFlag.castleKingSide));
      }
    }

    if (canQueenSide) {
      final int d = squareAt(3, rank);
      final int c = squareAt(2, rank);
      final int b = squareAt(1, rank);
      final bool pathClear =
          state.squares[d] == null && state.squares[c] == null && state.squares[b] == null;
      final bool pathSafe =
          !isSquareAttacked(state, d, us.opposite) && !isSquareAttacked(state, c, us.opposite);
      if (pathClear && pathSafe) {
        out.add(Move(from: kingSquare, to: c, flag: MoveFlag.castleQueenSide));
      }
    }
  }
}
