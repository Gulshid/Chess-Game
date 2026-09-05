import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/saved_game.dart';
import 'saved_games_repository.dart';

/// Firestore implementation of [SavedGamesRepository] — games live at
/// `users/{uid}/saved_games/{gameId}`, a sub-collection rather than a
/// top-level one keyed by uid. That makes "all of this player's games"
/// a plain sub-collection read with no `where('uid', ...)` filter (and
/// therefore no composite index to manage), and lets Firestore security
/// rules scope access with a single `request.auth.uid == uid` path
/// match — see `PHASE9_SETUP.md` for the actual rules.
class FirestoreSavedGamesRepository implements SavedGamesRepository {
  FirestoreSavedGamesRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> _gamesFor(String uid) =>
      _db.collection('users').doc(uid).collection('saved_games');

  @override
  Future<void> saveGame(String uid, SavedGame game) {
    return _gamesFor(uid).doc(game.id).set(game.toMap());
  }

  @override
  Stream<List<SavedGame>> watchGames(String uid) {
    return _gamesFor(uid)
        .orderBy('playedAtEpochMs', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => SavedGame.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<void> deleteGame(String uid, String gameId) {
    return _gamesFor(uid).doc(gameId).delete();
  }
}
