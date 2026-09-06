import 'dart:async';

import 'package:chess/features/account/data/auth_repository.dart';

/// In-memory [AuthRepository] — no Firebase involved at all, so
/// [AuthProvider] tests run as plain, fast unit tests. Mirrors the real
/// [FirebaseAuthRepository]'s anonymous/email/link/sign-out behavior
/// closely enough to exercise [AuthProvider]'s logic (bootstrapping a
/// guest session, upgrading it, friendly-error mapping) without a
/// network call.
class FakeAuthRepository implements AuthRepository {
  final StreamController<AppUser?> _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;
  int _nextUid = 0;

  /// Registered "accounts" — email -> password, for [signInWithEmail] /
  /// [signUpWithEmail] to check against.
  final Map<String, String> _passwordsByEmail = <String, String>{};
  final Map<String, String> _uidByEmail = <String, String>{};

  /// Throws this on the next call, then clears itself — lets a test
  /// simulate a specific failure (e.g. wrong password) for exactly one
  /// call without needing a mocking framework.
  Object? failNextWith;

  Object? _consumeFailure() {
    final Object? f = failNextWith;
    failNextWith = null;
    return f;
  }

  String _newUid() => 'uid${_nextUid++}';

  void _setCurrent(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser> signInAnonymously() async {
    final Object? failure = _consumeFailure();
    if (failure != null) throw failure;
    if (_current != null) return _current!;
    final AppUser user = AppUser(uid: _newUid(), email: null, isAnonymous: true);
    _setCurrent(user);
    return user;
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final Object? failure = _consumeFailure();
    if (failure != null) throw failure;
    if (_passwordsByEmail.containsKey(email)) {
      throw StateError('email-already-in-use');
    }
    final String uid = _newUid();
    _passwordsByEmail[email] = password;
    _uidByEmail[email] = uid;
    final AppUser user = AppUser(uid: uid, email: email, isAnonymous: false);
    _setCurrent(user);
    return user;
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    final Object? failure = _consumeFailure();
    if (failure != null) throw failure;
    if (_passwordsByEmail[email] != password) {
      throw StateError('wrong-password');
    }
    final AppUser user = AppUser(uid: _uidByEmail[email]!, email: email, isAnonymous: false);
    _setCurrent(user);
    return user;
  }

  @override
  Future<AppUser> linkAnonymousToEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final Object? failure = _consumeFailure();
    if (failure != null) throw failure;
    final AppUser? current = _current;
    if (current == null || !current.isAnonymous) {
      throw StateError('linkAnonymousToEmail requires an anonymous session.');
    }
    if (_passwordsByEmail.containsKey(email)) {
      throw StateError('credential-already-in-use');
    }
    _passwordsByEmail[email] = password;
    _uidByEmail[email] = current.uid; // Same uid preserved — see interface doc.
    final AppUser user = AppUser(uid: current.uid, email: email, isAnonymous: false);
    _setCurrent(user);
    return user;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final Object? failure = _consumeFailure();
    if (failure != null) throw failure;
  }

  @override
  Future<void> signOut() async {
    _setCurrent(null);
  }

  Future<void> close() => _controller.close();
}
