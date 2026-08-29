/// Square indexing convention used throughout the engine:
///
/// A square is an `int` in `[0, 63]`. Index 0 = a1, index 7 = h1,
/// index 56 = a8, index 63 = h8. This is the standard "little-endian
/// rank-file" mapping used by most chess engines, which makes rank/file
/// arithmetic trivial:
///
///   file = square % 8   (0 = a, ... 7 = h)
///   rank = square ~/ 8  (0 = rank 1, ... 7 = rank 8)
library;

int fileOf(int square) => square % 8;

int rankOf(int square) => square ~/ 8;

int squareAt(int file, int rank) => rank * 8 + file;

bool isOnBoard(int file, int rank) => file >= 0 && file < 8 && rank >= 0 && rank < 8;

/// Converts a square index to algebraic notation, e.g. `0 -> 'a1'`, `63 -> 'h8'`.
String squareToAlgebraic(int square) {
  final String file = String.fromCharCode('a'.codeUnitAt(0) + fileOf(square));
  final String rank = (rankOf(square) + 1).toString();
  return '$file$rank';
}

/// Converts algebraic notation (e.g. `'e4'`) to a square index.
/// Throws [FormatException] if the input isn't a valid square.
int algebraicToSquare(String algebraic) {
  if (algebraic.length != 2) {
    throw FormatException('Invalid square: $algebraic');
  }
  final int file = algebraic.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final int rank = int.parse(algebraic[1]) - 1;
  if (!isOnBoard(file, rank)) {
    throw FormatException('Invalid square: $algebraic');
  }
  return squareAt(file, rank);
}
