import '../board_utils.dart';
import 'piece.dart';

/// Distinguishes the special-case moves that need extra handling when
/// applied to a [BoardState] (see `BoardState.applyMove`).
enum MoveFlag {
  quiet,
  doublePawnPush,
  capture,
  enPassant,
  castleKingSide,
  castleQueenSide,
  promotion,
  promotionCapture,
}

/// A single chess move: a from-square, a to-square, and any special
/// handling required (capture, castling, en passant, promotion).
///
/// Moves are produced by `MoveGenerator` and consumed by
/// `BoardState.applyMove`. This class intentionally carries no
/// board-lookup logic itself — it's a plain data holder so it stays cheap
/// to create in bulk during move generation.
class Move {
  const Move({
    required this.from,
    required this.to,
    this.flag = MoveFlag.quiet,
    this.promotionType,
  }) : assert(
          (flag == MoveFlag.promotion || flag == MoveFlag.promotionCapture) ==
              (promotionType != null),
          'promotionType must be set if and only if flag is a promotion flag',
        );

  final int from;
  final int to;
  final MoveFlag flag;

  /// The piece type a pawn promotes to. Only non-null for promotion moves.
  final PieceType? promotionType;

  bool get isCapture =>
      flag == MoveFlag.capture ||
      flag == MoveFlag.enPassant ||
      flag == MoveFlag.promotionCapture;

  bool get isPromotion =>
      flag == MoveFlag.promotion || flag == MoveFlag.promotionCapture;

  bool get isCastle =>
      flag == MoveFlag.castleKingSide || flag == MoveFlag.castleQueenSide;

  /// UCI-style long algebraic representation, e.g. `e2e4`, `e7e8q`.
  /// Useful for engine interop (Phase 6 Stockfish bridge) and debugging.
  String get uci {
    final String promo = switch (promotionType) {
      PieceType.queen => 'q',
      PieceType.rook => 'r',
      PieceType.bishop => 'b',
      PieceType.knight => 'n',
      _ => '',
    };
    return '${squareToAlgebraic(from)}${squareToAlgebraic(to)}$promo';
  }

  @override
  bool operator ==(Object other) =>
      other is Move &&
      other.from == from &&
      other.to == to &&
      other.flag == flag &&
      other.promotionType == promotionType;

  @override
  int get hashCode => Object.hash(from, to, flag, promotionType);

  @override
  String toString() => uci;
}
