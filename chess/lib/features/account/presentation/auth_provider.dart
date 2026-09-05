import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../data/firebase_auth_repository.dart';
import '../data/firestore_profile_repository.dart';
import '../data/profile_repository.dart';
import '../domain/rating.dart';
import '../domain/user_profile.dart';

/// The single source of truth for "who is playing" — Phase 9's account
/// layer counterpart to [GameProvider] for game state. Every screen
/// that needs the signed-in identity, profile, or stats goes through
/// this rather than touching [AuthRepository]/[ProfileRepository]
/// directly, for the same DI/testability reason `GameProvider`'s own
/// doc gives for the engine boundary.
///
/// Bootstraps an anonymous session automatically on construction if
/// nothing is signed in yet — the app has always let a player start a
/// local or AI game (and, since Phase 7, an online one) with zero
/// sign-up friction; Phase 9 adds durable profiles/ratings/history on
/// top of that *same* uid rather than gating basic play behind an
/// account screen.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? authRepository, ProfileRepository? profileRepository})
      : _auth = authRepository ?? FirebaseAuthRepository(),
        _profiles = profileRepository ?? FirestoreProfileRepository() {
    _authSub = _auth.authStateChanges.listen(_onAuthChanged);
    _bootstrapGuestSessionIfNeeded();
  }

  final AuthRepository _auth;
  final ProfileRepository _profiles;

  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<UserProfile?>? _profileSub;

  AppUser? _user;
  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;

  AppUser? get user => _user;
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// True once the player has a *permanent* account (email/password),
  /// as opposed to a device-only anonymous guest session.
  bool get hasPermanentAccount => _user != null && !_user!.isAnonymous;

  /// Best available name to show/prefill anywhere the app needs one
  /// (matchmaking's display-name field, the profile screen, etc.) —
  /// falls back gracefully while the profile document is still loading.
  String get displayName => _profile?.displayName ?? 'Player';

  Future<void> _bootstrapGuestSessionIfNeeded() async {
    if (_auth.currentUser != null) return;
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      _error = 'Could not start a session: ${_friendlyError(e)}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _onAuthChanged(AppUser? user) async {
    _user = user;
    await _profileSub?.cancel();

    if (user == null) {
      _profile = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Seed a fresh profile with a reasonable default name — a real
    // display name (email-derived, or later a chosen one) beats a raw
    // uid, but is still just a starting point the player can rename at
    // any time from the profile screen.
    final String seedName = user.isAnonymous
        ? 'Guest ${user.uid.substring(0, user.uid.length.clamp(0, 5))}'
        : (user.email?.split('@').first ?? 'Player');

    try {
      await _profiles.ensureProfile(
        UserProfile.newPlayer(uid: user.uid, displayName: seedName, isAnonymous: user.isAnonymous),
      );
    } catch (e) {
      _error = 'Could not load your profile: ${_friendlyError(e)}';
    }

    _profileSub = _profiles.watchProfile(user.uid).listen((p) {
      _profile = p;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _run(() => _auth.signUpWithEmail(email: email, password: password, displayName: displayName));

  Future<bool> signIn({required String email, required String password}) =>
      _run(() => _auth.signInWithEmail(email: email, password: password));

  /// Upgrades the current guest session to a permanent account without
  /// losing its uid — see [AuthRepository.linkAnonymousToEmail]'s doc.
  Future<bool> upgradeGuestAccount({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _run(() => _auth.linkAnonymousToEmail(
            email: email,
            password: password,
            displayName: displayName,
          ));

  Future<bool> sendPasswordReset(String email) => _run(() => _auth.sendPasswordResetEmail(email));

  /// Signs out of a permanent account and immediately starts a fresh
  /// anonymous session — the app should never be left in a fully
  /// signed-out state where local/AI play is blocked.
  Future<void> signOut() async {
    await _auth.signOut();
    await _bootstrapGuestSessionIfNeeded();
  }

  Future<void> updateDisplayName(String name) async {
    final String? uid = _user?.uid;
    if (uid == null || name.trim().isEmpty) return;
    await _profiles.updateDisplayName(uid: uid, displayName: name.trim());
  }

  Future<void> updateAvatar(String emoji) async {
    final String? uid = _user?.uid;
    if (uid == null) return;
    await _profiles.updateAvatar(uid: uid, avatarEmoji: emoji);
  }

  /// Records one completed *online* game's result — see
  /// [ProfileRepository.recordGameResult]'s doc for why local/AI games
  /// don't call this.
  Future<void> recordGameResult({required MatchResult result, required int opponentRating}) {
    final String? uid = _user?.uid;
    if (uid == null) return Future<void>.value();
    return _profiles.recordGameResult(uid: uid, result: result, opponentRating: opponentRating);
  }

  Future<void> recordPuzzleAttempt({required bool solved, required int puzzleRating}) {
    final String? uid = _user?.uid;
    if (uid == null) return Future<void>.value();
    return _profiles.recordPuzzleAttempt(uid: uid, solved: solved, puzzleRating: puzzleRating);
  }

  Stream<List<UserProfile>> leaderboard({int limit = 50}) => _profiles.watchLeaderboard(limit: limit);

  Future<bool> _run(Future<Object?> Function() action) async {
    _error = null;
    try {
      await action();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' => 'That email is already registered — try signing in instead.',
        'invalid-email' => 'That email address doesn\'t look right.',
        'weak-password' => 'Choose a password with at least 6 characters.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Incorrect email or password.',
        'credential-already-in-use' =>
          'That email already has an account — sign in instead to keep this guest progress separate.',
        _ => error.message ?? 'Something went wrong. Please try again.',
      };
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
