import 'dart:async';

import 'package:chess/features/multiplayer/data/multiplayer_repository.dart';
import 'package:chess/features/multiplayer/domain/online_game.dart';
import 'package:chess/features/multiplayer/domain/online_game_status.dart';
import 'package:chess/features/multiplayer/domain/time_control.dart';

/// In-memory [MultiplayerRepository] for tests — exactly the "hand in a
/// fake implementation instead of hitting real Firestore" use case
/// [MultiplayerRepository]'s own class doc calls out.
///
/// Keeps a single in-memory [OnlineGame] per instance (this project only
/// ever has one game screen open at a time) and a broadcast stream so
/// [OnlineGameProvider] can subscribe to it the same way it subscribes
/// to a real Firestore snapshot stream. Every mutating call
/// (`submitMove`, `resign`, ...) updates the stored game and re-emits it,
/// so a test can drive a full turn cycle just by calling the same
/// methods a real screen would.
///
/// Every call is also recorded in [calls] so tests can assert on *what*
/// was sent to the "server" (e.g. "did resigning actually call
/// `resign`") without needing a mocking framework.
class FakeMultiplayerRepository implements MultiplayerRepository {
  FakeMultiplayerRepository({required OnlineGame initialGame, this.uid = 'me'})
      : _game = initialGame {
    _controller = StreamController<OnlineGame>.broadcast();
  }

  @override
  String get currentUid => uid;

  final String uid;
  OnlineGame _game;
  late final StreamController<OnlineGame> _controller;

  /// Method-name log for call-count/argument assertions in tests.
  final List<String> calls = <String>[];

  OnlineGame get currentGame => _game;

  void _emit(OnlineGame game) {
    _game = game;
    _controller.add(game);
  }

  /// Simulates the *opponent's* next move arriving from the server —
  /// tests use this to drive [OnlineGameProvider]'s incremental-sync
  /// path without a second real client.
  void simulateOpponentMove({
    required String uciMove,
    required String sanMove,
    required String resultingFen,
  }) {
    _emit(_game.copyWith(
      uciMoveHistory: <String>[..._game.uciMoveHistory, uciMove],
      sanMoveHistory: <String>[..._game.sanMoveHistory, sanMove],
      fen: resultingFen,
      lastMoveAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Simulates an arbitrary server-side update (a draw offer arriving, a
  /// status change, presence heartbeats, etc.) without needing a
  /// dedicated `simulate*` method for every field — tests transform the
  /// current in-memory game and this re-emits it exactly like
  /// [simulateOpponentMove] does for moves specifically.
  void emitGame(OnlineGame Function(OnlineGame current) transform) {
    _emit(transform(_game));
  }

  @override
  Future<void> ensureSignedIn() async {}

  @override
  Future<OnlineGame> createPrivateGame({
    required TimeControl timeControl,
    required String displayName,
    required int rating,
  }) async {
    calls.add('createPrivateGame');
    return _game;
  }

  @override
  Future<OnlineGame> joinPrivateGame({
    required String code,
    required String displayName,
    required int rating,
  }) async {
    calls.add('joinPrivateGame');
    return _game;
  }

  @override
  Future<OnlineGame> findQuickMatch({
    required TimeControl timeControl,
    required String displayName,
    required int rating,
  }) async {
    calls.add('findQuickMatch');
    return _game;
  }

  @override
  Future<void> cancelQuickMatch() async {
    calls.add('cancelQuickMatch');
  }

  @override
  Future<String?> findCodeForGame(String gameId) async => null;

  @override
  Stream<OnlineGame> watchGame(String gameId) {
    // Real repositories emit the current value immediately on listen
    // (a Firestore `snapshots()` stream does this) — mirrored here via
    // `Stream.multi` so `OnlineGameProvider`'s constructor-time
    // subscription sees the initial game synchronously, exactly like
    // production.
    return Stream<OnlineGame>.multi((controller) {
      controller.add(_game);
      final StreamSubscription<OnlineGame> sub = _controller.stream.listen(controller.add);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> submitMove({
    required String gameId,
    required String uciMove,
    required String sanMove,
    required String resultingFen,
    required int remainingMs,
  }) async {
    calls.add('submitMove:$uciMove');
    _emit(_game.copyWith(
      uciMoveHistory: <String>[..._game.uciMoveHistory, uciMove],
      sanMoveHistory: <String>[..._game.sanMoveHistory, sanMove],
      fen: resultingFen,
      lastMoveAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  @override
  Future<void> resign({required String gameId}) async {
    calls.add('resign');
    final bool iAmWhite = _game.whiteUid == uid;
    _emit(_game.copyWith(
      status: iAmWhite ? OnlineGameStatus.blackWon : OnlineGameStatus.whiteWon,
      endReason: GameEndReason.resignation,
    ));
  }

  @override
  Future<void> offerDraw({required String gameId}) async {
    calls.add('offerDraw');
    _emit(_game.copyWith(drawOfferedByUid: uid));
  }

  @override
  Future<void> respondToDrawOffer({required String gameId, required bool accept}) async {
    calls.add('respondToDrawOffer:$accept');
    if (accept) {
      _emit(_game.copyWith(
        status: OnlineGameStatus.draw,
        endReason: GameEndReason.drawAgreement,
        clearDrawOffer: true,
      ));
    } else {
      _emit(_game.copyWith(clearDrawOffer: true));
    }
  }

  @override
  Future<void> claimTimeout({required String gameId, required OnlineGameStatus winner}) async {
    calls.add('claimTimeout:${winner.name}');
    _emit(_game.copyWith(status: winner, endReason: GameEndReason.timeout));
  }

  @override
  Future<void> reportGameOver({
    required String gameId,
    required OnlineGameStatus status,
    required GameEndReason reason,
  }) async {
    calls.add('reportGameOver:${status.name}');
    _emit(_game.copyWith(status: status, endReason: reason));
  }

  @override
  Future<void> sendHeartbeat({required String gameId}) async {
    calls.add('sendHeartbeat');
  }

  @override
  Future<void> leaveGame({required String gameId}) async {
    calls.add('leaveGame');
  }

  Future<void> close() => _controller.close();
}
