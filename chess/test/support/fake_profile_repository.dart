import 'dart:async';

import 'package:chess/features/account/data/profile_repository.dart';
import 'package:chess/features/account/domain/rating.dart';
import 'package:chess/features/account/domain/user_profile.dart';

/// In-memory [ProfileRepository] — one `Map<uid, UserProfile>` plus a
/// per-uid broadcast stream, standing in for Firestore's
/// `users/{uid}` document + `snapshots()` the way
/// [FirestoreProfileRepository] models it for real.
class FakeProfileRepository implements ProfileRepository {
  final Map<String, UserProfile> _profiles = <String, UserProfile>{};
  final Map<String, StreamController<UserProfile?>> _controllers =
      <String, StreamController<UserProfile?>>{};

  StreamController<UserProfile?> _controllerFor(String uid) =>
      _controllers.putIfAbsent(uid, () => StreamController<UserProfile?>.broadcast());

  void _put(UserProfile profile) {
    _profiles[profile.uid] = profile;
    _controllerFor(profile.uid).add(profile);
  }

  @override
  Future<UserProfile> ensureProfile(UserProfile profile) async {
    final UserProfile? existing = _profiles[profile.uid];
    if (existing != null) return existing;
    _put(profile);
    return profile;
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return Stream<UserProfile?>.multi((controller) {
      controller.add(_profiles[uid]);
      final StreamSubscription<UserProfile?> sub =
          _controllerFor(uid).stream.listen(controller.add);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> updateDisplayName({required String uid, required String displayName}) async {
    final UserProfile? p = _profiles[uid];
    if (p != null) _put(p.copyWith(displayName: displayName));
  }

  @override
  Future<void> updateAvatar({required String uid, required String avatarEmoji}) async {
    final UserProfile? p = _profiles[uid];
    if (p != null) _put(p.copyWith(avatarEmoji: avatarEmoji));
  }

  @override
  Future<void> recordGameResult({
    required String uid,
    required MatchResult result,
    required int opponentRating,
  }) async {
    final UserProfile? p = _profiles[uid];
    if (p == null) return;
    _put(p.copyWith(
      rating: Rating.updateElo(playerRating: p.rating, opponentRating: opponentRating, result: result),
      gamesPlayed: p.gamesPlayed + 1,
      gamesWon: p.gamesWon + (result == MatchResult.win ? 1 : 0),
      gamesLost: p.gamesLost + (result == MatchResult.loss ? 1 : 0),
      gamesDrawn: p.gamesDrawn + (result == MatchResult.draw ? 1 : 0),
    ));
  }

  @override
  Future<void> recordPuzzleAttempt({
    required String uid,
    required bool solved,
    required int puzzleRating,
  }) async {
    final UserProfile? p = _profiles[uid];
    if (p == null) return;
    final int newStreak = solved ? p.puzzleStreak + 1 : 0;
    _put(p.copyWith(
      puzzleRating: Rating.updatePuzzleRating(
        playerPuzzleRating: p.puzzleRating,
        puzzleRating: puzzleRating,
        solved: solved,
      ),
      puzzlesAttempted: p.puzzlesAttempted + 1,
      puzzlesSolved: p.puzzlesSolved + (solved ? 1 : 0),
      puzzleStreak: newStreak,
      bestPuzzleStreak: newStreak > p.bestPuzzleStreak ? newStreak : p.bestPuzzleStreak,
    ));
  }

  @override
  Stream<List<UserProfile>> watchLeaderboard({int limit = 50}) {
    final List<UserProfile> ranked = _profiles.values.where((p) => !p.isAnonymous).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return Stream<List<UserProfile>>.value(ranked.take(limit).toList());
  }
}
