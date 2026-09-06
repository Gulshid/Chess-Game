import 'package:chess/features/chess_engine/domain/board_utils.dart';
import 'package:chess/features/chess_engine/domain/models/piece.dart';
import 'package:chess/features/multiplayer/domain/online_game.dart';
import 'package:chess/features/multiplayer/domain/online_game_status.dart';
import 'package:chess/features/multiplayer/domain/time_control.dart';
import 'package:chess/features/multiplayer/presentation/online_game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_multiplayer_repository.dart';

/// Stream delivery — both the fake's broadcast [StreamController] and,
/// in production, a real Firestore `snapshots()` stream — is
/// asynchronous, never synchronous during the call that triggered it.
/// [OnlineGameScreen] already accounts for this in production (it shows
/// a loading spinner while `onlineGame == null`), so tests poll for the
/// expected state the same way rather than asserting immediately after
/// construction or after a `repo.simulate*`/`repo.emitGame` call.
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

OnlineGame _freshGame({required String whiteUid, required String blackUid}) {
  final int now = DateTime.now().millisecondsSinceEpoch;
  return OnlineGame(
    id: 'game-1',
    whiteUid: whiteUid,
    blackUid: blackUid,
    whiteName: 'White Player',
    blackName: 'Black Player',
    fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    uciMoveHistory: const <String>[],
    sanMoveHistory: const <String>[],
    status: OnlineGameStatus.active,
    timeControl: TimeControl.blitz5,
    // Generous remaining time so the 250ms clock ticker (see
    // `OnlineGameProvider`'s constructor) never accidentally claims a
    // timeout mid-test.
    whiteTimeRemainingMs: 300000,
    blackTimeRemainingMs: 300000,
    lastMoveAtEpochMs: now,
    createdAtEpochMs: now,
  );
}

void main() {
  group('as the white player', () {
    late FakeMultiplayerRepository repo;
    late OnlineGameProvider provider;

    setUp(() async {
      repo = FakeMultiplayerRepository(
        initialGame: _freshGame(whiteUid: 'me', blackUid: 'opponent'),
        uid: 'me',
      );
      provider = OnlineGameProvider(repository: repo, gameId: 'game-1', myUid: 'me');
      await _waitUntil(() => provider.onlineGame != null);
    });

    tearDown(() {
      provider.dispose();
      repo.close();
    });

    test('resolves myColor and isMyTurn correctly at game start', () {
      expect(provider.myColor, PieceColor.white);
      expect(provider.isMyTurn, isTrue);
      expect(provider.opponentName, 'Black Player');
    });

    test('a legal move on my turn is applied locally and pushed to the server', () {
      provider.selectSquare(algebraicToSquare('e2'));
      final bool applied = provider.moveSelectedTo(algebraicToSquare('e4'));

      expect(applied, isTrue);
      expect(provider.sanHistory, <String>['e4']);
      expect(repo.calls, contains('submitMove:e2e4'));
    });

    test("the opponent's move arriving from the server is applied incrementally", () async {
      repo.simulateOpponentMove(
        uciMove: 'e2e4',
        sanMove: 'e4',
        resultingFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
      );
      await _waitUntil(() => provider.sanHistory.isNotEmpty);

      expect(provider.sanHistory, <String>['e4']);
      expect(provider.sideToMove, PieceColor.black);
    });

    test('cannot submit a move once it is no longer my turn', () async {
      // White's own move (e.g. played from a second device) syncs in —
      // it is now black's turn, so this provider (white) must not be
      // able to move even if something (a stale board redraw) lets a
      // black piece get selected.
      repo.simulateOpponentMove(
        uciMove: 'e2e4',
        sanMove: 'e4',
        resultingFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
      );
      await _waitUntil(() => !provider.isMyTurn);

      provider.selectSquare(algebraicToSquare('e7'));
      final bool applied = provider.moveSelectedTo(algebraicToSquare('e5'));

      expect(applied, isFalse);
      expect(repo.calls, isNot(contains('submitMove:e7e5')));
    });

    test('resign calls through to the repository', () async {
      await provider.resign();
      expect(repo.calls, contains('resign'));
    });

    test('offerDraw calls through to the repository', () async {
      await provider.offerDraw();
      expect(repo.calls, contains('offerDraw'));
    });

    test('respondToDrawOffer forwards accept/decline to the repository', () async {
      await provider.respondToDrawOffer(true);
      expect(repo.calls, contains('respondToDrawOffer:true'));
    });

    test('drawOfferedByOpponent is true only when the offer came from the other uid', () async {
      expect(provider.drawOfferedByOpponent, isFalse);
      repo.emitGame((g) => g.copyWith(drawOfferedByUid: 'opponent'));
      await _waitUntil(() => provider.onlineGame?.drawOfferedByUid == 'opponent');

      expect(provider.drawOfferedByOpponent, isTrue);
      expect(provider.drawOfferedByMe, isFalse);
    });

    test('drawOfferedByMe is true when I made the offer', () async {
      repo.emitGame((g) => g.copyWith(drawOfferedByUid: 'me'));
      await _waitUntil(() => provider.onlineGame?.drawOfferedByUid == 'me');

      expect(provider.drawOfferedByMe, isTrue);
      expect(provider.drawOfferedByOpponent, isFalse);
    });

    test('connectionStatus is connected with no stale presence data', () {
      expect(provider.connectionStatus, ConnectionStatus.connected);
    });

    test('dispose cancels the subscription and leaves the game', () {
      // Uses its own local repo/provider rather than the shared ones
      // from `setUp` — those are already disposed again by this
      // group's `tearDown`, and disposing a `ChangeNotifier` twice
      // throws (see `AuthProvider._disposed`'s doc for the same class
      // of dispose-safety concern this project now guards against).
      final localRepo = FakeMultiplayerRepository(
        initialGame: _freshGame(whiteUid: 'me', blackUid: 'opponent'),
        uid: 'me',
      );
      final localProvider =
          OnlineGameProvider(repository: localRepo, gameId: 'game-1', myUid: 'me');

      localProvider.dispose();

      expect(localRepo.calls, contains('leaveGame'));
      localRepo.close();
    });
  });

  group('as the black player', () {
    test('cannot move until white has moved', () async {
      final repo = FakeMultiplayerRepository(
        initialGame: _freshGame(whiteUid: 'opponent', blackUid: 'me'),
        uid: 'me',
      );
      final provider = OnlineGameProvider(repository: repo, gameId: 'game-1', myUid: 'me');
      addTearDown(provider.dispose);
      addTearDown(repo.close);
      await _waitUntil(() => provider.onlineGame != null);

      expect(provider.myColor, PieceColor.black);
      expect(provider.isMyTurn, isFalse);

      provider.selectSquare(algebraicToSquare('e7'));
      final bool applied = provider.moveSelectedTo(algebraicToSquare('e5'));

      expect(applied, isFalse);
      expect(repo.calls, isNot(contains('submitMove:e7e5')));
    });

    test("can move once white's move has synced", () async {
      final repo = FakeMultiplayerRepository(
        initialGame: _freshGame(whiteUid: 'opponent', blackUid: 'me'),
        uid: 'me',
      );
      final provider = OnlineGameProvider(repository: repo, gameId: 'game-1', myUid: 'me');
      addTearDown(provider.dispose);
      addTearDown(repo.close);
      await _waitUntil(() => provider.onlineGame != null);

      repo.simulateOpponentMove(
        uciMove: 'e2e4',
        sanMove: 'e4',
        resultingFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
      );
      await _waitUntil(() => provider.isMyTurn);

      provider.selectSquare(algebraicToSquare('e7'));
      final bool applied = provider.moveSelectedTo(algebraicToSquare('e5'));

      expect(applied, isTrue);
      expect(repo.calls, contains('submitMove:e7e5'));
    });
  });

  group('a uid that is neither player (spectator)', () {
    test('myColor and isMyTurn are safely null/false', () async {
      final repo = FakeMultiplayerRepository(
        initialGame: _freshGame(whiteUid: 'p1', blackUid: 'p2'),
        uid: 'spectator',
      );
      final provider = OnlineGameProvider(repository: repo, gameId: 'game-1', myUid: 'spectator');
      addTearDown(provider.dispose);
      addTearDown(repo.close);
      await _waitUntil(() => provider.onlineGame != null);

      expect(provider.myColor, isNull);
      expect(provider.isMyTurn, isFalse);
    });
  });
}
