import 'package:chess/features/account/data/auth_repository.dart';
import 'package:chess/features/account/domain/rating.dart';
import 'package:chess/features/account/presentation/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_profile_repository.dart';

/// [AuthProvider] is deliberately built against [AuthRepository] /
/// [ProfileRepository] *interfaces* (see its class doc) specifically so
/// tests like these can hand in fakes instead of needing a real Firebase
/// project — the same "engine, AI, and networking layers are swappable
/// and testable" principle the roadmap's Phase 4 states and this
/// project's provider classes consistently follow.
///
/// The auth -> profile bootstrap chain crosses several real async hops
/// (a broadcast stream event, an awaited `ensureProfile` call, a second
/// stream subscription) so tests poll for the expected state with
/// [_waitUntil] rather than guessing a fixed number of
/// `Future.delayed(Duration.zero)` pumps.
Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeProfileRepository();
  });

  Future<AuthProvider> createAndWaitForBootstrap() async {
    final provider = AuthProvider(authRepository: auth, profileRepository: profiles);
    await _waitUntil(() => provider.profile != null);
    return provider;
  }

  test('bootstraps an anonymous guest session automatically with no prior sign-in', () async {
    final provider = await createAndWaitForBootstrap();
    addTearDown(provider.dispose);

    expect(provider.user, isNotNull);
    expect(provider.user!.isAnonymous, isTrue);
    expect(provider.hasPermanentAccount, isFalse);
    expect(provider.profile!.rating, Rating.startingRating);
    expect(provider.isLoading, isFalse);
  });

  test('sign-up creates a permanent account and profile', () async {
    final provider = await createAndWaitForBootstrap();
    addTearDown(provider.dispose);

    final bool success = await provider.signUp(
      email: 'alice@example.com',
      password: 'hunter22',
      displayName: 'Alice',
    );

    expect(success, isTrue);
    expect(provider.hasPermanentAccount, isTrue);
    expect(provider.user!.email, 'alice@example.com');
  });

  test('sign-in failure surfaces a friendly error message and does not change the session', () async {
    final provider = await createAndWaitForBootstrap();
    addTearDown(provider.dispose);
    final AppUser? guestUser = provider.user;

    auth.failNextWith = FirebaseAuthException(code: 'wrong-password');
    final bool success = await provider.signIn(email: 'nobody@example.com', password: 'wrong');

    expect(success, isFalse);
    expect(provider.error, 'Incorrect email or password.');
    expect(provider.user, guestUser,
        reason: 'a failed sign-in should not disturb the guest session');
  });

  test('upgradeGuestAccount preserves the same uid', () async {
    final provider = await createAndWaitForBootstrap();
    addTearDown(provider.dispose);
    final String guestUid = provider.user!.uid;

    final bool success = await provider.upgradeGuestAccount(
      email: 'bob@example.com',
      password: 'hunter22',
      displayName: 'Bob',
    );

    expect(success, isTrue);
    expect(provider.user!.uid, guestUid);
    expect(provider.hasPermanentAccount, isTrue);
    await _waitUntil(() => provider.profile?.uid == guestUid);
  });

  test('recordGameResult updates the rating and win/loss counters via ProfileRepository', () async {
    final provider = await createAndWaitForBootstrap();
    addTearDown(provider.dispose);

    await provider.recordGameResult(result: MatchResult.win, opponentRating: Rating.startingRating);
    await _waitUntil(() => provider.profile!.gamesPlayed == 1);

    expect(provider.profile!.gamesWon, 1);
    expect(provider.profile!.rating, greaterThan(Rating.startingRating));
  });

  test('recordPuzzleAttempt updates puzzle rating and streak', () async {
    final provider = await createAndWaitForBootstrap();
    addTearDown(provider.dispose);

    await provider.recordPuzzleAttempt(solved: true, puzzleRating: Rating.startingPuzzleRating);
    await _waitUntil(() => provider.profile!.puzzleStreak == 1);

    await provider.recordPuzzleAttempt(solved: false, puzzleRating: Rating.startingPuzzleRating);
    await _waitUntil(() => provider.profile!.puzzlesAttempted == 2);
    expect(provider.profile!.puzzleStreak, 0, reason: 'a failed attempt resets the streak');
  });

  test('signOut ends the permanent session and starts a fresh guest one', () async {
    final provider = await createAndWaitForBootstrap();
    addTearDown(provider.dispose);
    await provider.signUp(email: 'carol@example.com', password: 'hunter22', displayName: 'Carol');
    final String permanentUid = provider.user!.uid;

    await provider.signOut();
    await _waitUntil(() => provider.user != null && provider.user!.uid != permanentUid);

    expect(provider.user!.isAnonymous, isTrue);
  });
}
