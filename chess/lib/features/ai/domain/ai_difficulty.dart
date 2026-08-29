/// Selectable AI opponent strength.
///
/// The roadmap's Phase 6 lists two implementation paths: bridge Stockfish
/// over UCI (strongest, but needs a native binary per platform via
/// platform channels, or a WASM build for web), or "build a custom
/// engine using minimax with alpha-beta pruning, iterative deepening,
/// and a piece-square-table evaluation function ... for full control."
/// This project takes the second path deliberately: the rest of the app
/// is pure Dart with zero native dependencies (see `ChessEngine`'s class
/// doc), and a custom engine keeps that property — same Dart code runs
/// unmodified on Android, iOS, web, and desktop with no binaries to ship
/// or WASM build step to maintain. `MinimaxEngine` in this same folder
/// is that engine; difficulty here just tunes how hard it looks.
enum AiDifficulty {
  beginner,
  easy,
  medium,
  hard,
  expert;

  /// Maximum search depth (in plies) iterative deepening will reach for
  /// this difficulty, if the time budget doesn't cut it off first.
  int get maxDepth => switch (this) {
        AiDifficulty.beginner => 2,
        AiDifficulty.easy => 3,
        AiDifficulty.medium => 4,
        AiDifficulty.hard => 5,
        AiDifficulty.expert => 6,
      };

  /// Wall-clock budget for a single move. Iterative deepening returns the
  /// best move found by the last depth that completed inside this
  /// window, so raising this (rather than [maxDepth] alone) is the
  /// other lever for strength — it's what lets `expert` actually reach
  /// deeper depths in tactically sharp positions instead of a depth
  /// that's merely a slow version of `hard`.
  Duration get thinkTime => switch (this) {
        AiDifficulty.beginner => const Duration(milliseconds: 200),
        AiDifficulty.easy => const Duration(milliseconds: 500),
        AiDifficulty.medium => const Duration(seconds: 1),
        AiDifficulty.hard => const Duration(seconds: 2, milliseconds: 500),
        AiDifficulty.expert => const Duration(seconds: 5),
      };

  /// Beginner/easy deliberately blend in a little randomness among
  /// near-equal top moves (see `MinimaxEngine`) so the AI doesn't play
  /// the exact same "best" line every game at low strength — real
  /// beginners aren't perfectly consistent either.
  bool get addsMoveVariety => this == AiDifficulty.beginner || this == AiDifficulty.easy;

  String get label => switch (this) {
        AiDifficulty.beginner => 'Beginner',
        AiDifficulty.easy => 'Easy',
        AiDifficulty.medium => 'Medium',
        AiDifficulty.hard => 'Hard',
        AiDifficulty.expert => 'Expert',
      };
}
