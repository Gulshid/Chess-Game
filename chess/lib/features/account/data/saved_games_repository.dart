import '../domain/saved_game.dart';

/// What the app needs from a game-history backend — "Cloud save for
/// game history and puzzle progress, with local caching (Hive/Drift)
/// for offline access" (Phase 9).
abstract class SavedGamesRepository {
  Future<void> saveGame(String uid, SavedGame game);

  /// Most-recent-first. Reads from the local cache immediately (if
  /// present) and refreshes from the cloud when connectivity allows —
  /// see [HiveCachedSavedGamesRepository] for how the two are combined.
  Stream<List<SavedGame>> watchGames(String uid);

  Future<void> deleteGame(String uid, String gameId);
}
