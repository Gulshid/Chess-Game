/// Lifecycle of an online game document.
enum OnlineGameStatus {
  /// Created (privately, or a matchmaking ticket), waiting for a second
  /// player to join before the clock starts.
  waitingForOpponent,

  active,
  whiteWon,
  blackWon,
  draw,

  /// Either player left before the game properly started, or both
  /// players disconnected long enough that the game is considered dead
  /// rather than resumable.
  aborted;

  bool get isOver =>
      this == OnlineGameStatus.whiteWon ||
      this == OnlineGameStatus.blackWon ||
      this == OnlineGameStatus.draw ||
      this == OnlineGameStatus.aborted;

  static OnlineGameStatus fromWire(String value) =>
      OnlineGameStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => OnlineGameStatus.active,
      );
}

/// Why a game ended, for the result banner — separate from
/// [OnlineGameStatus] itself (which only says *who* won) since "resigned"
/// vs "checkmate" vs "timeout" vs "draw by agreement" all render
/// different text but map to the same white/black/draw outcome.
enum GameEndReason {
  checkmate,
  resignation,
  timeout,
  drawAgreement,
  stalemate,
  insufficientMaterial,
  threefoldRepetition,
  fiftyMoveRule,
  abandonment;

  static GameEndReason? fromWire(String? value) {
    if (value == null) return null;
    for (final GameEndReason r in GameEndReason.values) {
      if (r.name == value) return r;
    }
    return null;
  }
}
