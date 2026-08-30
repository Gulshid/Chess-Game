/// How much a played move gave up relative to the engine's best move in
/// that position, classified the way every mainstream game-review
/// feature buckets centipawn loss (Chess.com/Lichess use the same rough
/// thresholds — there's no official standard, but these are the
/// conventional cutoffs).
enum MoveQuality {
  best,
  good,
  inaccuracy,
  mistake,
  blunder;

  String get label => switch (this) {
        MoveQuality.best => 'Best',
        MoveQuality.good => 'Good',
        MoveQuality.inaccuracy => 'Inaccuracy',
        MoveQuality.mistake => 'Mistake',
        MoveQuality.blunder => 'Blunder',
      };

  /// Buckets a centipawn loss (always >= 0; how much worse the position
  /// became for the mover than the best available move) into a quality.
  static MoveQuality fromCentipawnLoss(int loss) {
    if (loss <= 10) return MoveQuality.best;
    if (loss <= 40) return MoveQuality.good;
    if (loss <= 90) return MoveQuality.inaccuracy;
    if (loss <= 200) return MoveQuality.mistake;
    return MoveQuality.blunder;
  }
}

/// One row of a game review: the move that was played, in SAN, what it
/// cost the mover in centipawns compared to the engine's best move in
/// that position, and the resulting classification.
class AnnotatedMove {
  const AnnotatedMove({
    required this.plyIndex,
    required this.san,
    required this.quality,
    required this.centipawnLoss,
    required this.fenBefore,
    required this.fenAfter,
  });

  /// Zero-based ply index (0 = White's first move, 1 = Black's first
  /// move, ...) — matches the index into `ChessEngine.moveHistory`.
  final int plyIndex;
  final String san;
  final MoveQuality quality;
  final int centipawnLoss;
  final String fenBefore;
  final String fenAfter;

  bool get isWhiteMove => plyIndex.isEven;
}
