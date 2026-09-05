import 'package:firebase_auth/firebase_auth.dart';

import 'auth_repository.dart';

/// Firebase Auth implementation of [AuthRepository] — anonymous +
/// email/password, which the roadmap's Phase 9 lists as one of three
/// options ("email, Google, Apple Sign-In"). Google and Apple Sign-In
/// are deliberately not implemented here: both need per-platform native
/// configuration this project can't verify from Dart alone (an OAuth
/// client ID + SHA-1 fingerprint registered in the Firebase console for
/// Google; a Sign in with Apple capability + Services ID for Apple) —
/// see `PHASE9_SETUP.md` for exactly what each would need and where to
/// add it. Email/password needs no such per-platform setup beyond
/// Firebase Auth being enabled, so it's the one implemented directly;
/// the [AuthRepository] interface is what lets Google/Apple providers
/// be added later as new methods on this same class without touching
/// [AuthProvider] or any screen.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    return AppUser(uid: user.uid, email: user.email, isAnonymous: user.isAnonymous);
  }

  @override
  Stream<AppUser?> get authStateChanges => _auth.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<AppUser> signInAnonymously() async {
    final User? existing = _auth.currentUser;
    if (existing != null) return _toAppUser(existing)!;
    final UserCredential credential = await _auth.signInAnonymously();
    return _toAppUser(credential.user)!;
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final UserCredential credential =
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await credential.user?.updateDisplayName(displayName);
    return _toAppUser(credential.user)!;
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    final UserCredential credential =
        await _auth.signInWithEmailAndPassword(email: email, password: password);
    return _toAppUser(credential.user)!;
  }

  @override
  Future<AppUser> linkAnonymousToEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final User? current = _auth.currentUser;
    if (current == null || !current.isAnonymous) {
      throw StateError('linkAnonymousToEmail requires a signed-in anonymous session.');
    }
    final AuthCredential credential =
        EmailAuthProvider.credential(email: email, password: password);
    final UserCredential linked = await current.linkWithCredential(credential);
    await linked.user?.updateDisplayName(displayName);
    return _toAppUser(linked.user)!;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) => _auth.sendPasswordResetEmail(email: email);

  @override
  Future<void> signOut() => _auth.signOut();
}
