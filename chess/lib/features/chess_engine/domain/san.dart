import 'board_utils.dart';
import 'models/board_state.dart';
import 'models/move.dart';
import 'models/piece.dart';
import 'move_generator.dart';

/// Generates Standard Algebraic Notation (SAN) strings for moves — the
/// `Nf3`, `O-O`, `exd8=Q+`, `Qh4#` style notation used in move-history
/// panels (Phase 5) and PGN export (Phase 8).
///
/// SAN can only be computed correctly with knowledge of the *position the
/// move was played in* (to disambiguate two pieces that could reach the
/// same square, e.g. `Nbd7` vs `Nfd7`) and the *resulting* position (to
/// know whether to append `+` or `#`). Both of those come from
/// `MoveGenerator`, so this class stays in the domain layer alongside it
/// rather than living in the UI.
class San {
  const San._();

  /// Returns the SAN string for [move], played from position [before].
  /// [move] is assumed to already be legal in [before] — this is a
  /// formatting function, not a validator.
  static String forMove(BoardState before, Move move) {
    if (move.isCastle) {
      final String base = move.flag == MoveFlag.castleKingSide ? 'O-O' : 'O-O-O';
      return base + _checkOrMateSuffix(before, move);
    }

    final Piece moving = before.pieceAt(move.from)!;
    final StringBuffer san = StringBuffer();

    if (moving.type == PieceType.pawn) {
      if (move.isCapture) {
        san.write(_fileLetter(fileOf(move.from)));
        san.write('x');
      }
      san.write(squareToAlgebraic(move.to));
      if (move.isPromotion) {
        san.write('=');
        san.write(_pieceLetter(move.promotionType!));
      }
    } else {
      san.write(_pieceLetter(moving.type));
      san.write(_disambiguation(before, move, moving));
      if (move.isCapture) san.write('x');
      san.write(squareToAlgebraic(move.to));
    }

    san.write(_checkOrMateSuffix(before, move));
    return san.toString();
  }

  static String _pieceLetter(PieceType type) => switch (type) {
        PieceType.knight => 'N',
        PieceType.bishop => 'B',
        PieceType.rook => 'R',
        PieceType.queen => 'Q',
        PieceType.king => 'K',
        PieceType.pawn => '',
      };

  static String _fileLetter(int file) => String.fromCharCode('a'.codeUnitAt(0) + file);

  /// Standard SAN disambiguation: among the *other* legal moves in this
  /// position that move a piece of the same type to the same destination,
  /// use the origin file if that's enough to distinguish; otherwise the
  /// origin rank; otherwise (rare — three+ pieces converging) the full
  /// origin square.
  static String _disambiguation(BoardState before, Move move, Piece moving) {
    final List<Move> allLegal = MoveGenerator.legalMoves(before);
    final List<Move> ambiguousWith = allLegal.where((Move other) {
      if (other.to != move.to || other.from == move.from) return false;
      final Piece? otherPiece = before.pieceAt(other.from);
      return otherPiece != null &&
          otherPiece.type == moving.type &&
          otherPiece.color == moving.color;
    }).toList();

    if (ambiguousWith.isEmpty) return '';

    final bool shareFile =
        ambiguousWith.any((Move m) => fileOf(m.from) == fileOf(move.from));
    final bool shareRank =
        ambiguousWith.any((Move m) => rankOf(m.from) == rankOf(move.from));

    if (!shareFile) return _fileLetter(fileOf(move.from));
    if (!shareRank) return (rankOf(move.from) + 1).toString();
    return squareToAlgebraic(move.from);
  }

  static String _checkOrMateSuffix(BoardState before, Move move) {
    final BoardState after = before.applyMove(move);
    final PieceColor opponent = before.sideToMove.opposite;
    if (!MoveGenerator.isKingInCheck(after, opponent)) return '';
    final bool hasReply = MoveGenerator.legalMoves(after).isNotEmpty;
    return hasReply ? '+' : '#';
  }
}
