import '../board_utils.dart';
import 'move.dart';
import 'piece.dart';

/// A fully immutable snapshot of a chess position: piece placement, side to
/// move, castling rights, en passant target, and the two FEN move counters.
///
/// Every move produces a *new* [BoardState] via [applyMove] rather than
/// mutating this one. This makes undo/redo (Phase 4) and game replay
/// (Phase 7/8) trivial: just keep a `List<BoardState>` history and step
/// through it.
///
/// IMPORTANT: [applyMove] assumes the move is already pseudo-legal (a
/// piece of the right color actually exists on `from`, moving to `to` is
/// geometrically valid for that piece, etc). It does NOT check whether the
/// move leaves the mover's own king in check — that legality filter lives
/// in `MoveGenerator.legalMoves`, one layer up. This separation keeps
/// `applyMove` fast and simple: it's a pure "mechanics" function.
class BoardState {
  const BoardState({
    required this.squares,
    required this.sideToMove,
    required this.whiteCanCastleKingSide,
    required this.whiteCanCastleQueenSide,
    required this.blackCanCastleKingSide,
    required this.blackCanCastleQueenSide,
    required this.enPassantSquare,
    required this.halfmoveClock,
    required this.fullmoveNumber,
  });

  /// Length-64 board, index 0 = a1 ... index 63 = h8. See `board_utils.dart`.
  final List<Piece?> squares;

  final PieceColor sideToMove;

  final bool whiteCanCastleKingSide;
  final bool whiteCanCastleQueenSide;
  final bool blackCanCastleKingSide;
  final bool blackCanCastleQueenSide;

  /// The square a pawn can capture *to* via en passant this move, or null.
  /// (This is the square *behind* the pawn that just double-moved — the
  /// same convention FEN uses.)
  final int? enPassantSquare;

  /// Half-moves since the last capture or pawn move (for the 50-move rule).
  final int halfmoveClock;

  /// Full-move number, incremented after Black moves (standard chess
  /// notation convention — starts at 1).
  final int fullmoveNumber;

  /// The standard chess starting position.
  factory BoardState.initial() {
    final List<Piece?> squares = List<Piece?>.filled(64, null);

    const List<PieceType> backRank = <PieceType>[
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];

    for (int file = 0; file < 8; file++) {
      squares[squareAt(file, 0)] = Piece(PieceColor.white, backRank[file]);
      squares[squareAt(file, 1)] = const Piece(PieceColor.white, PieceType.pawn);
      squares[squareAt(file, 6)] = const Piece(PieceColor.black, PieceType.pawn);
      squares[squareAt(file, 7)] = Piece(PieceColor.black, backRank[file]);
    }

    return BoardState(
      squares: List<Piece?>.unmodifiable(squares),
      sideToMove: PieceColor.white,
      whiteCanCastleKingSide: true,
      whiteCanCastleQueenSide: true,
      blackCanCastleKingSide: true,
      blackCanCastleQueenSide: true,
      enPassantSquare: null,
      halfmoveClock: 0,
      fullmoveNumber: 1,
    );
  }

  Piece? pieceAt(int square) => squares[square];

  BoardState copyWith({
    List<Piece?>? squares,
    PieceColor? sideToMove,
    bool? whiteCanCastleKingSide,
    bool? whiteCanCastleQueenSide,
    bool? blackCanCastleKingSide,
    bool? blackCanCastleQueenSide,
    int? enPassantSquare,
    bool clearEnPassantSquare = false,
    int? halfmoveClock,
    int? fullmoveNumber,
  }) {
    return BoardState(
      squares: squares ?? this.squares,
      sideToMove: sideToMove ?? this.sideToMove,
      whiteCanCastleKingSide: whiteCanCastleKingSide ?? this.whiteCanCastleKingSide,
      whiteCanCastleQueenSide: whiteCanCastleQueenSide ?? this.whiteCanCastleQueenSide,
      blackCanCastleKingSide: blackCanCastleKingSide ?? this.blackCanCastleKingSide,
      blackCanCastleQueenSide: blackCanCastleQueenSide ?? this.blackCanCastleQueenSide,
      enPassantSquare: clearEnPassantSquare ? null : (enPassantSquare ?? this.enPassantSquare),
      halfmoveClock: halfmoveClock ?? this.halfmoveClock,
      fullmoveNumber: fullmoveNumber ?? this.fullmoveNumber,
    );
  }

  /// Applies [move] and returns the resulting new state. See class doc for
  /// the pseudo-legal assumption.
  BoardState applyMove(Move move) {
    final List<Piece?> next = List<Piece?>.of(squares);
    final Piece moving = next[move.from]!;
    final bool isPawnMove = moving.type == PieceType.pawn;

    // Default: no en passant target unless this move creates one.
    int? nextEnPassantSquare;

    switch (move.flag) {
      case MoveFlag.quiet:
        next[move.to] = moving;
        next[move.from] = null;
        break;

      case MoveFlag.capture:
        next[move.to] = moving;
        next[move.from] = null;
        break;

      case MoveFlag.doublePawnPush:
        next[move.to] = moving;
        next[move.from] = null;
        // En passant target is the square the pawn "jumped over".
        nextEnPassantSquare = (move.from + move.to) ~/ 2;
        break;

      case MoveFlag.enPassant:
        next[move.to] = moving;
        next[move.from] = null;
        // Captured pawn sits on the same rank as `from`, same file as `to`.
        final int capturedPawnSquare = squareAt(fileOf(move.to), rankOf(move.from));
        next[capturedPawnSquare] = null;
        break;

      case MoveFlag.castleKingSide:
        next[move.to] = moving;
        next[move.from] = null;
        final int rank1 = rankOf(move.from);
        final int rookFrom1 = squareAt(7, rank1);
        final int rookTo1 = squareAt(5, rank1);
        next[rookTo1] = next[rookFrom1];
        next[rookFrom1] = null;
        break;

      case MoveFlag.castleQueenSide:
        next[move.to] = moving;
        next[move.from] = null;
        final int rank2 = rankOf(move.from);
        final int rookFrom2 = squareAt(0, rank2);
        final int rookTo2 = squareAt(3, rank2);
        next[rookTo2] = next[rookFrom2];
        next[rookFrom2] = null;
        break;

      case MoveFlag.promotion:
        next[move.to] = Piece(moving.color, move.promotionType!);
        next[move.from] = null;
        break;

      case MoveFlag.promotionCapture:
        next[move.to] = Piece(moving.color, move.promotionType!);
        next[move.from] = null;
        break;
    }

    // --- Castling rights bookkeeping ---
    bool wk = whiteCanCastleKingSide;
    bool wq = whiteCanCastleQueenSide;
    bool bk = blackCanCastleKingSide;
    bool bq = blackCanCastleQueenSide;

    if (moving.type == PieceType.king) {
      if (moving.color == PieceColor.white) {
        wk = false;
        wq = false;
      } else {
        bk = false;
        bq = false;
      }
    }
    // Moving OR capturing a rook off its home square revokes that side's
    // right permanently, even if a different piece now occupies it.
    if (move.from == 0 || move.to == 0) wq = false; // a1
    if (move.from == 7 || move.to == 7) wk = false; // h1
    if (move.from == 56 || move.to == 56) bq = false; // a8
    if (move.from == 63 || move.to == 63) bk = false; // h8

    // --- Halfmove clock: resets on pawn move or capture ---
    final int nextHalfmove = (isPawnMove || move.isCapture) ? 0 : halfmoveClock + 1;

    // --- Fullmove number: increments after Black's move ---
    final int nextFullmove = sideToMove == PieceColor.black ? fullmoveNumber + 1 : fullmoveNumber;

    return BoardState(
      squares: List<Piece?>.unmodifiable(next),
      sideToMove: sideToMove.opposite,
      whiteCanCastleKingSide: wk,
      whiteCanCastleQueenSide: wq,
      blackCanCastleKingSide: bk,
      blackCanCastleQueenSide: bq,
      enPassantSquare: nextEnPassantSquare,
      halfmoveClock: nextHalfmove,
      fullmoveNumber: nextFullmove,
    );
  }
}
