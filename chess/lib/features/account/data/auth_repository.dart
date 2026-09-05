/// A signed-in identity, independent of which auth provider produced
/// it — everything above [AuthRepository] (in particular
/// [AuthProvider]) works against this, never against a Firebase
/// `User` directly, for the same swappable-backend reason
/// `MultiplayerRepository` gives for [OnlineGame] vs. a raw Firestore
/// document.
class AppUser {
  const AppUser({required this.uid, required this.email, required this.isAnonymous});

  final String uid;

  /// Null for an anonymous guest session.
  final String? email;
  final bool isAnonymous;
}

/// What the app needs from an authentication backend.
///
/// Kept separate from [ProfileRepository] on purpose: authentication
/// (who is this device/session) and profile data (what is this
/// player's name/rating/stats) are different concerns with different
/// lifecycles — [AuthRepository.signInAnonymously] can succeed with
/// zero Firestore reads, and unit tests that only care about profile
/// logic shouldn't need to fake sign-in flows to get there.
abstract class AuthRepository {
  /// Emits the current [AppUser] (or null when signed out) immediately
  /// on listen, then again on every sign-in/out/link.
  Stream<AppUser?> get authStateChanges;

  AppUser? get currentUser;

  /// Starts (or resumes) an anonymous guest session — the zero-friction
  /// default so a first-time player can start a local or AI game
  /// (and, per pre-Phase-9 `FirestoreMultiplayerRepository`, an online
  /// one) without any sign-up screen at all.
  Future<AppUser> signInAnonymously();

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppUser> signInWithEmail({required String email, required String password});

  /// Upgrades the *current anonymous* session to a permanent
  /// email/password account, preserving [AppUser.uid] — and therefore
  /// every stat, rating, and saved game already written under it (see
  /// `ProfileRepository`'s doc for why the uid is the document key).
  /// This is what lets a guest who's been playing casually decide later
  /// to "keep" their progress, instead of losing it the moment they
  /// create a real account.
  ///
  /// Throws if [currentUser] isn't currently anonymous, or if [email]
  /// is already in use by another account (Firebase's own
  /// `credential-already-in-use` case) — callers should offer
  /// [signInWithEmail] instead in that case and accept that the guest
  /// progress under the old uid can't be merged automatically.
  Future<AppUser> linkAnonymousToEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}
