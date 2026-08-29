/// Color of a chess piece / side to move.
enum PieceColor {
  white,
  black;

  PieceColor get opposite =>
      this == PieceColor.white ? PieceColor.black : PieceColor.white;
}

/// The six chess piece types.
enum PieceType {
  pawn,
  knight,
  bishop,
  rook,
  queen,
  king;

  /// Standard material value in centipawns-of-a-pawn units (pawn = 1).
  /// King is 0 because it is never captured/traded.
  int get value => switch (this) {
        PieceType.pawn => 1,
        PieceType.knight => 3,
        PieceType.bishop => 3,
        PieceType.rook => 5,
        PieceType.queen => 9,
        PieceType.king => 0,
      };
}

/// An immutable chess piece: a color + type pair.
///
/// Two pieces are equal if their color and type match — this lets
/// `Piece(PieceColor.white, PieceType.pawn) == Piece(PieceColor.white, PieceType.pawn)`
/// work correctly in tests and board comparisons.
class Piece {
  const Piece(this.color, this.type);

  final PieceColor color;
  final PieceType type;

  /// FEN character for this piece: uppercase for white, lowercase for black.
  /// e.g. white knight -> 'N', black pawn -> 'p'.
  String get fenChar {
    final String letter = switch (type) {
      PieceType.pawn => 'p',
      PieceType.knight => 'n',
      PieceType.bishop => 'b',
      PieceType.rook => 'r',
      PieceType.queen => 'q',
      PieceType.king => 'k',
    };
    return color == PieceColor.white ? letter.toUpperCase() : letter;
  }

  /// Parses a single FEN board character into a [Piece], or returns null
  /// if the character isn't a valid piece letter (e.g. a digit or '/').
  static Piece? fromFenChar(String char) {
    final PieceColor color =
        char == char.toUpperCase() ? PieceColor.white : PieceColor.black;
    final PieceType? type = switch (char.toLowerCase()) {
      'p' => PieceType.pawn,
      'n' => PieceType.knight,
      'b' => PieceType.bishop,
      'r' => PieceType.rook,
      'q' => PieceType.queen,
      'k' => PieceType.king,
      _ => null,
    };
    if (type == null) return null;
    return Piece(color, type);
  }

  @override
  bool operator ==(Object other) =>
      other is Piece && other.color == color && other.type == type;

  @override
  int get hashCode => Object.hash(color, type);

  @override
  String toString() => fenChar;
}
