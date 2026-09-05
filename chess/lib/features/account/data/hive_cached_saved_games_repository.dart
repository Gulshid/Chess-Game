import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../domain/saved_game.dart';
import 'saved_games_repository.dart';

/// Decorates a cloud [SavedGamesRepository] (normally
/// [FirestoreSavedGamesRepository]) with a local Hive-backed cache, so
/// game history is readable offline — Phase 9's "local caching (Hive/
/// Drift) for offline access" applied to saved games specifically (see
/// `HiveSettingsRepository` for the same package used for local-only
/// settings).
///
/// Strategy: [watchGames] emits the cached list immediately (so the
/// saved-games screen never shows a blank loading state for a returning
/// player, online or not), then re-emits whenever the cloud stream
/// delivers a fresher snapshot — and writes that fresher snapshot back
/// into the cache as it goes. [saveGame] writes to the cache first
/// (so a just-finished game shows up in the list immediately even on a
/// flaky connection) and then to the cloud; a cloud failure is swallowed
/// rather than surfaced, matching the "cloud sync is best-effort, the
/// cache is the source of truth for what the UI shows right now" model
/// — a background retry/outbox queue is a documented follow-up, not
/// implemented here, the same honest-gap treatment
/// `FirestoreMultiplayerRepository` gives its own known limits.
class HiveCachedSavedGamesRepository implements SavedGamesRepository {
  HiveCachedSavedGamesRepository({required SavedGamesRepository cloud, Box<String>? box})
      : _cloud = cloud,
        _box = box;

  final SavedGamesRepository _cloud;
  Box<String>? _box;

  static const String boxName = 'saved_games_cache';

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(boxName);
  }

  String _cacheKey(String uid) => 'games:$uid';

  Future<List<SavedGame>> _readCache(String uid) async {
    final Box<String> box = await _openBox();
    final String? raw = box.get(_cacheKey(uid));
    if (raw == null) return const <SavedGame>[];
    try {
      final List<Object?> decoded = jsonDecode(raw) as List<Object?>;
      return decoded
          .cast<Map<String, Object?>>()
          .map((m) => SavedGame.fromMap(m['id'] as String, m))
          .toList();
    } catch (_) {
      return const <SavedGame>[]; // Corrupt/old-format cache entry — ignore it.
    }
  }

  Future<void> _writeCache(String uid, List<SavedGame> games) async {
    final Box<String> box = await _openBox();
    final List<Map<String, Object?>> encoded = games
        .map((g) => <String, Object?>{'id': g.id, ...g.toMap()})
        .toList();
    await box.put(_cacheKey(uid), jsonEncode(encoded));
  }

  @override
  Future<void> saveGame(String uid, SavedGame game) async {
    final List<SavedGame> current = await _readCache(uid);
    final List<SavedGame> updated = <SavedGame>[
      game,
      ...current.where((g) => g.id != game.id),
    ];
    await _writeCache(uid, updated);

    try {
      await _cloud.saveGame(uid, game);
    } catch (_) {
      // Best-effort cloud sync — see class doc. The cache write above
      // already succeeded, so the game isn't lost from the player's
      // point of view even if this call fails.
    }
  }

  @override
  Stream<List<SavedGame>> watchGames(String uid) {
    late final StreamController<List<SavedGame>> controller;
    StreamSubscription<List<SavedGame>>? cloudSub;

    controller = StreamController<List<SavedGame>>(
      onListen: () async {
        controller.add(await _readCache(uid));
        cloudSub = _cloud.watchGames(uid).listen(
          (games) async {
            await _writeCache(uid, games);
            if (!controller.isClosed) controller.add(games);
          },
          onError: (_) {
            // Offline or the cloud read failed — the cache emission
            // above already gave the UI something to show.
          },
        );
      },
      onCancel: () => cloudSub?.cancel(),
    );

    return controller.stream;
  }

  @override
  Future<void> deleteGame(String uid, String gameId) async {
    final List<SavedGame> current = await _readCache(uid);
    await _writeCache(uid, current.where((g) => g.id != gameId).toList());
    try {
      await _cloud.deleteGame(uid, gameId);
    } catch (_) {
      // Best-effort — see class doc.
    }
  }
}
