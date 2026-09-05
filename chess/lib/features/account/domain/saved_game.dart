/// How a [SavedGame] was played — drives the label/icon shown in
/// [SavedGamesScreen] and which fields ([opponentLabel] etc.) are
/// meaningful for it.
enum SavedGameSource {
  local,
  ai,
  online,
  puzzle;

  static SavedGameSource fromWire(String? value) => SavedGameSource.values.firstWhere(
        (s) => s.name == value,
        orElse: () => SavedGameSource.local,
      );
}

/// Outcome from *this account's* point of view — simpler for the saved-
/// games list to render than re-deriving "did I win" from
/// [SavedGame.pgnResult] + which color this player was every time.
enum SavedGameOutcome {
  win,
  loss,
  draw,
  unknown;

  static SavedGameOutcome fromWire(String? value) => SavedGameOutcome.values.firstWhere(
        (o) => o.name == value,
        orElse: () => SavedGameOutcome.unknown,
      );
}

/// One completed (or in-progress-and-exited) game, persisted so a
/// player can revisit it later — Phase 9's "Cloud save for game history
/// ... with local caching for offline access."
///
/// Stored as full PGN text plus a few denormalized fields (outcome,
/// opponent label) that the list screen needs without re-parsing PGN
/// for every row. This mirrors the same "store what the UI reads most
/// often, not just the minimal normalized form" choice
/// `OnlineGame.toMap` documents for the live-game document.
class SavedGame {
  const SavedGame({
    required this.id,
    required this.pgn,
    required this.source,
    required this.outcome,
    required this.opponentLabel,
    required this.playerColorWasWhite,
    required this.moveCount,
    required this.playedAtEpochMs,
  });

  final String id;
  final String pgn;
  final SavedGameSource source;
  final SavedGameOutcome outcome;

  /// e.g. "AI · Hard", "vs. Alex", "Local 2-player", "Puzzle #premate-12".
  final String opponentLabel;
  final bool playerColorWasWhite;
  final int moveCount;
  final int playedAtEpochMs;

  factory SavedGame.fromMap(String id, Map<String, Object?> map) {
    return SavedGame(
      id: id,
      pgn: map['pgn'] as String? ?? '',
      source: SavedGameSource.fromWire(map['source'] as String?),
      outcome: SavedGameOutcome.fromWire(map['outcome'] as String?),
      opponentLabel: map['opponentLabel'] as String? ?? 'Opponent',
      playerColorWasWhite: map['playerColorWasWhite'] as bool? ?? true,
      moveCount: (map['moveCount'] as num?)?.toInt() ?? 0,
      playedAtEpochMs:
          (map['playedAtEpochMs'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'pgn': pgn,
        'source': source.name,
        'outcome': outcome.name,
        'opponentLabel': opponentLabel,
        'playerColorWasWhite': playerColorWasWhite,
        'moveCount': moveCount,
        'playedAtEpochMs': playedAtEpochMs,
      };
}
