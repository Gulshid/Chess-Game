import 'board_utils.dart';
import 'models/board_state.dart';
import 'models/piece.dart';

/// Parses and generates Forsyth-Edwards Notation (FEN) strings.
///
/// FEN support is included from Phase 2 (not deferred to a later "nice to
/// have" phase) because Phase 7 (resuming multiplayer games), Phase 8
/// (analysis board / puzzle positions), and even Phase 2's own perft tests
/// all need to load arbitrary positions, not just the starting one.
class Fen {
  const Fen._();

  /// Parses a full FEN string into a [BoardState].
  ///
  /// Throws [FormatException] if the FEN is structurally invalid.
  static BoardState parse(String fen) {
    final List<String> fields = fen.trim().split(RegExp(r'\s+'));
    if (fields.length < 4) {
      throw FormatException('FEN must have at least 4 fields: $fen');
    }

    final List<Piece?> squares = List<Piece?>.filled(64, null);
    final List<String> ranks = fields[0].split('/');
    if (ranks.length != 8) {
      throw FormatException('FEN board must have 8 ranks: $fen');
    }

    // FEN ranks are listed from rank 8 down to rank 1.
    for (int i = 0; i < 8; i++) {
      final int rank = 7 - i;
      int file = 0;
      for (final String char in ranks[i].split('')) {
        final int? emptyCount = int.tryParse(char);
        if (emptyCount != null) {
          file += emptyCount;
        } else {
          final Piece? piece = Piece.fromFenChar(char);
          if (piece == null) {
            throw FormatException('Invalid piece character "$char" in FEN: $fen');
          }
          if (file > 7) {
            throw FormatException('Rank overflow in FEN: $fen');
          }
          squares[squareAt(file, rank)] = piece;
          file++;
        }
      }
    }

    final PieceColor sideToMove = fields[1] == 'w' ? PieceColor.white : PieceColor.black;

    final String castling = fields[2];
    final bool whiteKingSide = castling.contains('K');
    final bool whiteQueenSide = castling.contains('Q');
    final bool blackKingSide = castling.contains('k');
    final bool blackQueenSide = castling.contains('q');

    final int? enPassantSquare = fields[3] == '-' ? null : algebraicToSquare(fields[3]);

    final int halfmoveClock = fields.length > 4 ? int.parse(fields[4]) : 0;
    final int fullmoveNumber = fields.length > 5 ? int.parse(fields[5]) : 1;

    return BoardState(
      squares: List<Piece?>.unmodifiable(squares),
      sideToMove: sideToMove,
      whiteCanCastleKingSide: whiteKingSide,
      whiteCanCastleQueenSide: whiteQueenSide,
      blackCanCastleKingSide: blackKingSide,
      blackCanCastleQueenSide: blackQueenSide,
      enPassantSquare: enPassantSquare,
      halfmoveClock: halfmoveClock,
      fullmoveNumber: fullmoveNumber,
    );
  }

  /// Generates the full FEN string for [state].
  static String generate(BoardState state) {
    final StringBuffer boardBuffer = StringBuffer();
    for (int rank = 7; rank >= 0; rank--) {
      int emptyCount = 0;
      for (int file = 0; file < 8; file++) {
        final Piece? piece = state.squares[squareAt(file, rank)];
        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            boardBuffer.write(emptyCount);
            emptyCount = 0;
          }
          boardBuffer.write(piece.fenChar);
        }
      }
      if (emptyCount > 0) boardBuffer.write(emptyCount);
      if (rank > 0) boardBuffer.write('/');
    }

    final String side = state.sideToMove == PieceColor.white ? 'w' : 'b';

    final StringBuffer castling = StringBuffer();
    if (state.whiteCanCastleKingSide) castling.write('K');
    if (state.whiteCanCastleQueenSide) castling.write('Q');
    if (state.blackCanCastleKingSide) castling.write('k');
    if (state.blackCanCastleQueenSide) castling.write('q');
    final String castlingStr = castling.isEmpty ? '-' : castling.toString();

    final String enPassant =
        state.enPassantSquare == null ? '-' : squareToAlgebraic(state.enPassantSquare!);

    return '$boardBuffer $side $castlingStr $enPassant '
        '${state.halfmoveClock} ${state.fullmoveNumber}';
  }
}
