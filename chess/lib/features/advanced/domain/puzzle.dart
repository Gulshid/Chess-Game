/// A single tactics puzzle: a position to solve plus its solution line.
///
/// [solutionUci] is the *full* forced sequence starting with the
/// opponent's setup move (puzzles are conventionally presented one ply
/// after the actual game position, so the player always solves as the
/// side to move in [fen]) — even indices (0, 2, 4, ...) are the moves
/// the player must find; odd indices are the automatic opponent replies
/// the puzzle screen plays back for them. This mirrors how Lichess's
/// puzzle format works, which the roadmap names directly as the
/// reference dataset ("Lichess puzzle dataset, which is open and free").
class Puzzle {
  const Puzzle({
    required this.id,
    required this.fen,
    required this.solutionUci,
    required this.rating,
    required this.themes,
  });

  final String id;
  final String fen;
  final List<String> solutionUci;
  final int rating;
  final List<String> themes;

  /// The move the player needs to find right now, given how many correct
  /// moves ([solvedPlyCount]) they've already played.
  String? nextPlayerMove(int solvedPlyCount) {
    if (solvedPlyCount >= solutionUci.length) return null;
    return solutionUci[solvedPlyCount];
  }

  bool get isMateThemed => themes.contains('mate');
}
