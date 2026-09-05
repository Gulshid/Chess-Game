import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/rating.dart';
import '../domain/user_profile.dart';
import 'profile_repository.dart';

/// Firestore implementation of [ProfileRepository] — profiles live at
/// `users/{uid}`, one document per player, doubling as the leaderboard
/// collection ("Leaderboards and a simple internal rating system" —
/// Phase 9 groups both under one line item, and one document per player
/// is exactly what makes that possible: [watchLeaderboard] is a plain
/// `orderBy(rating).limit(n)` query over this same collection, no
/// separate aggregation step needed).
///
/// ### Honest limit, matching `FirestoreMultiplayerRepository`'s pattern
/// [recordGameResult] and [recordPuzzleAttempt] read-modify-write the
/// rating from the *client* inside a Firestore transaction. That keeps
/// two concurrent writers (rare, but possible if a player has the app
/// open on two devices) consistent with each other, but it does not
/// stop a modified client from writing an inflated rating directly —
/// the same "no Cloud Functions in this project" trade-off
/// `FirestoreMultiplayerRepository`'s class doc already makes for move
/// legality applies here too, for the same reason.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> get _users => _db.collection('users');

  @override
  Future<UserProfile> ensureProfile(UserProfile profile) async {
    final DocumentReference<Map<String, Object?>> ref = _users.doc(profile.uid);
    return _db.runTransaction<UserProfile>((transaction) async {
      final DocumentSnapshot<Map<String, Object?>> snapshot = await transaction.get(ref);
      if (snapshot.exists) {
        return UserProfile.fromMap(snapshot.id, snapshot.data()!);
      }
      transaction.set(ref, profile.toMap());
      return profile;
    });
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map(
          (s) => s.exists ? UserProfile.fromMap(s.id, s.data()!) : null,
        );
  }

  @override
  Future<void> updateDisplayName({required String uid, required String displayName}) {
    return _users.doc(uid).update(<String, Object?>{'displayName': displayName});
  }

  @override
  Future<void> updateAvatar({required String uid, required String avatarEmoji}) {
    return _users.doc(uid).update(<String, Object?>{'avatarEmoji': avatarEmoji});
  }

  @override
  Future<void> recordGameResult({
    required String uid,
    required MatchResult result,
    required int opponentRating,
  }) async {
    final DocumentReference<Map<String, Object?>> ref = _users.doc(uid);
    await _db.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, Object?>> snapshot = await transaction.get(ref);
      if (!snapshot.exists) return; // No profile yet — nothing to update.
      final UserProfile profile = UserProfile.fromMap(snapshot.id, snapshot.data()!);

      final int newRating = Rating.updateElo(
        playerRating: profile.rating,
        opponentRating: opponentRating,
        result: result,
      );

      transaction.update(ref, <String, Object?>{
        'rating': newRating,
        'gamesPlayed': profile.gamesPlayed + 1,
        'gamesWon': profile.gamesWon + (result == MatchResult.win ? 1 : 0),
        'gamesLost': profile.gamesLost + (result == MatchResult.loss ? 1 : 0),
        'gamesDrawn': profile.gamesDrawn + (result == MatchResult.draw ? 1 : 0),
      });
    });
  }

  @override
  Future<void> recordPuzzleAttempt({
    required String uid,
    required bool solved,
    required int puzzleRating,
  }) async {
    final DocumentReference<Map<String, Object?>> ref = _users.doc(uid);
    await _db.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, Object?>> snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final UserProfile profile = UserProfile.fromMap(snapshot.id, snapshot.data()!);

      final int newRating = Rating.updatePuzzleRating(
        playerPuzzleRating: profile.puzzleRating,
        puzzleRating: puzzleRating,
        solved: solved,
      );
      final int newStreak = solved ? profile.puzzleStreak + 1 : 0;

      transaction.update(ref, <String, Object?>{
        'puzzleRating': newRating,
        'puzzlesAttempted': profile.puzzlesAttempted + 1,
        'puzzlesSolved': profile.puzzlesSolved + (solved ? 1 : 0),
        'puzzleStreak': newStreak,
        'bestPuzzleStreak':
            newStreak > profile.bestPuzzleStreak ? newStreak : profile.bestPuzzleStreak,
      });
    });
  }

  @override
  Stream<List<UserProfile>> watchLeaderboard({int limit = 50}) {
    return _users
        .where('isAnonymous', isEqualTo: false)
        .orderBy('rating', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => UserProfile.fromMap(d.id, d.data())).toList());
  }
}
