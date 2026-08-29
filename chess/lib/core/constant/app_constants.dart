/// Cross-cutting constants used across features.
///
/// Kept deliberately small in Phase 1 — board-theme colors, piece asset
/// paths, and animation durations are added in Phase 5 once the board UI
/// work begins.
class AppConstants {
  const AppConstants._();

  static const String appName = 'Flutter Chess';

  /// Standard starting position in Forsyth-Edwards Notation.
  static const String startingFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
}
