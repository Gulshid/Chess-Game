import '../domain/rating.dart';
import '../domain/user_profile.dart';

/// What the app needs from a profile/stats/leaderboard backend. See
/// [AuthRepository]'s doc for why this is a separate interface from
/// authentication itself.
abstract class ProfileRepository {
  /// Creates [profile] if `users/{profile.uid}` doesn't exist yet;
  /// otherwise leaves the existing document untouched. Called right
  /// after every sign-in (see `AuthProvider`) so a brand-new uid always
  /// has a profile document before any screen tries to read one, while
  /// a returning player's stats are never clobbered back to defaults.
  Future<UserProfile> ensureProfile(UserProfile profile);

  Stream<UserProfile?> watchProfile(String uid);

  Future<void> updateDisplayName({required String uid, required String displayName});

  Future<void> updateAvatar({required String uid, required String avatarEmoji});

  /// Applies one completed *online* game's result to [uid]'s rating and
  /// win/loss/draw counters, using [Rating.updateElo] against
  /// [opponentRating]. Local and AI games don't call this — see
  /// [UserProfile.rating]'s doc: the rating is specifically for ranked
  /// online play, where both sides' identities (and therefore ratings)
  /// are known.
  Future<void> recordGameResult({
    required String uid,
    required MatchResult result,
    required int opponentRating,
  });

  /// Applies one puzzle attempt to [uid]'s puzzle rating, solved/
  /// attempted counters, and streak.
  Future<void> recordPuzzleAttempt({
    required String uid,
    required bool solved,
    required int puzzleRating,
  });

  /// Top players by [UserProfile.rating], excluding anonymous guests
  /// (see [UserProfile.isAnonymous]'s doc) — "Leaderboards" (Phase 9).
  Stream<List<UserProfile>> watchLeaderboard({int limit = 50});
}
