import 'dart:math' as math;

/// Match result from the rated player's point of view, for
/// [Rating.updateElo]'s `score` parameter.
enum MatchResult {
  win(1.0),
  draw(0.5),
  loss(0.0);

  const MatchResult(this.score);
  final double score;
}

/// Standard Elo rating math — the "simplified Elo-style" system the
/// roadmap calls for in both Phase 8 ("Puzzle rating system") and
/// Phase 9 ("a simple internal rating system (Elo or Glicko-2) for
/// ranked play"). Elo, not Glicko-2: Glicko-2 additionally tracks a
/// rating *deviation* and *volatility* per player and needs a periodic
/// batch update step across the whole rating pool to converge properly,
/// which is real infrastructure (a scheduled job) this project doesn't
/// have — see `FirestoreMultiplayerRepository`'s class doc for the same
/// "documented trade-off, not silently skipped" treatment of a
/// server-infrastructure gap. Plain Elo updates a single number
/// per-game, client-side, which fits this project's zero-Cloud-
/// Functions footprint.
class Rating {
  const Rating._();

  static const int startingRating = 1200;
  static const int startingPuzzleRating = 1000;

  /// The [k-factor](https://en.wikipedia.org/wiki/Elo_rating_system#The_K-factor_in_chess)
  /// controls how far a single result moves the rating. 32 is the
  /// standard "provisional/club player" value most casual chess
  /// platforms use — high enough that a new player's rating finds its
  /// level in a few dozen games, without the wild single-game swings a
  /// much larger k-factor would cause.
  static const int defaultKFactor = 32;

  /// Puzzles use a slightly smaller k-factor than [defaultKFactor]:
  /// puzzle sessions happen far more often than full games, so a
  /// smaller per-attempt swing still lets the rating move meaningfully
  /// over a session without bouncing around on every single puzzle.
  static const int puzzleKFactor = 24;

  /// Returns the updated rating for a player rated [playerRating] who
  /// just played an opponent (or, for puzzles, a puzzle) rated
  /// [opponentRating] and got [result].
  static int updateElo({
    required int playerRating,
    required int opponentRating,
    required MatchResult result,
    int kFactor = defaultKFactor,
  }) {
    final double expectedScore =
        1 / (1 + math.pow(10, (opponentRating - playerRating) / 400));
    final double delta = kFactor * (result.score - expectedScore);
    return (playerRating + delta).round();
  }

  /// Convenience wrapper for puzzle attempts: the puzzle's own
  /// [Puzzle.rating] stands in for "opponent rating", and solving vs.
  /// failing maps onto win/loss (there's no draw outcome for a puzzle).
  static int updatePuzzleRating({
    required int playerPuzzleRating,
    required int puzzleRating,
    required bool solved,
  }) {
    return updateElo(
      playerRating: playerPuzzleRating,
      opponentRating: puzzleRating,
      result: solved ? MatchResult.win : MatchResult.loss,
      kFactor: puzzleKFactor,
    );
  }
}
