import 'dart:async';

import '../../../providers/game_provider.dart';
import '../../advanced/domain/move_resolver.dart';
import '../../chess_engine/domain/chess_engine.dart';
import '../../chess_engine/domain/game_status.dart';
import '../../chess_engine/domain/models/move.dart';
import '../../chess_engine/domain/models/piece.dart';
import '../data/multiplayer_repository.dart';
import '../domain/online_game.dart';
import '../domain/online_game_status.dart';

enum ConnectionStatus { connected, opponentDisconnected, reconnecting }

/// Drives a live online game: mirrors the Firestore [OnlineGame] stream
/// into a local [ChessEngine] the existing board widgets already know
/// how to render, and pushes locally-made moves back out to the server.
///
/// Subclasses [GameProvider] rather than composing it — see that class's
/// own doc comment: "that boundary is what lets Phase 6 (AI) and Phase 7
/// (multiplayer) plug in new move sources later without any board-widget
/// code changing." This is that plug-in. [ChessBoard], [GameControls],
/// [CapturedPiecesTray], and [MoveHistoryPanel] all work against it with
/// zero modifications — see `OnlineGameScreen` for how it's registered
/// (as `GameProvider`, not a separate type) so those widgets find it via
/// their existing `Consumer<GameProvider>` lookups.
///
/// ### Sync strategy
/// Remote updates are applied incrementally — for each UCI move present
/// in the server's history but not yet in [engine.moveHistory], resolve
/// it to a [Move] and call the inherited [makeMove]. This (rather than
/// [GameProvider.loadFen]-ing the server's FEN directly) is deliberate:
/// `loadFen` rebuilds the engine from scratch with empty move/SAN
/// history, which would blank the move-list panel and captured-pieces
/// tray every time *either* player moves. Incremental application keeps
/// full history, exactly like a live local game.
class OnlineGameProvider extends GameProvider {
  OnlineGameProvider({
    required MultiplayerRepository repository,
    required String gameId,
    required String myUid,
  })  : _repository = repository,
        _gameId = gameId,
        _myUid = myUid,
        super(engine: ChessEngine.initial()) {
    _subscription = repository.watchGame(gameId).listen(_onRemoteUpdate, onError: (_) {
      _streamStatus = ConnectionStatus.reconnecting;
      notifyListeners();
    });
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _repository.sendHeartbeat(gameId: _gameId);
    });
    _clockTicker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tickClocks());
  }

  final MultiplayerRepository _repository;
  final String _gameId;
  final String _myUid;

  late final StreamSubscription<OnlineGame> _subscription;
  late final Timer _heartbeatTimer;
  late final Timer _clockTicker;

  OnlineGame? _onlineGame;
  ConnectionStatus _streamStatus = ConnectionStatus.connected;
  static const Duration _presenceStaleAfter = Duration(seconds: 30);

  /// Locally-ticked display values, corrected to the server's numbers on
  /// every snapshot (see [_onRemoteUpdate]) so a slow/late listener never
  /// lets a clock drift visibly wrong.
  int _whiteDisplayMs = 0;
  int _blackDisplayMs = 0;
  bool _timeoutClaimed = false;

  OnlineGame? get onlineGame => _onlineGame;

  /// Combines two independent signals into one status the UI can show:
  /// whether *our own* Firestore listener is currently erroring
  /// ([_streamStatus]), and whether the *opponent's* last presence
  /// heartbeat (see [MultiplayerRepository.sendHeartbeat]) is stale —
  /// either can indicate a dropped connection, from either side.
  ConnectionStatus get connectionStatus {
    if (_streamStatus == ConnectionStatus.reconnecting) return _streamStatus;

    final OnlineGame? game = _onlineGame;
    if (game == null || game.status != OnlineGameStatus.active) {
      return ConnectionStatus.connected;
    }

    final int? opponentLastSeen =
        myColor == PieceColor.white ? game.blackLastSeenEpochMs : game.whiteLastSeenEpochMs;
    if (opponentLastSeen == null) return ConnectionStatus.connected; // no data yet

    final int staleMs = DateTime.now().millisecondsSinceEpoch - opponentLastSeen;
    return staleMs > _presenceStaleAfter.inMilliseconds
        ? ConnectionStatus.opponentDisconnected
        : ConnectionStatus.connected;
  }

  PieceColor? get myColor {
    final OnlineGame? g = _onlineGame;
    if (g == null) return null;
    if (g.whiteUid == _myUid) return PieceColor.white;
    if (g.blackUid == _myUid) return PieceColor.black;
    return null;
  }

  bool get isMyTurn => myColor != null && myColor == sideToMove && !isGameOver;

  int get whiteDisplayMs => _whiteDisplayMs;
  int get blackDisplayMs => _blackDisplayMs;

  bool get drawOfferedByOpponent =>
      _onlineGame?.drawOfferedByUid != null && _onlineGame?.drawOfferedByUid != _myUid;

  bool get drawOfferedByMe => _onlineGame?.drawOfferedByUid == _myUid;

  String get opponentName {
    final OnlineGame? g = _onlineGame;
    if (g == null) return 'Opponent';
    return myColor == PieceColor.white ? g.blackName : g.whiteName;
  }

  void _onRemoteUpdate(OnlineGame game) {
    final OnlineGame? previous = _onlineGame;
    _onlineGame = game;
    _streamStatus = ConnectionStatus.connected;

    _whiteDisplayMs = game.whiteTimeRemainingMs;
    _blackDisplayMs = game.blackTimeRemainingMs;

    // Apply any moves we don't have yet — see class doc for why this is
    // incremental rather than a `loadFen`.
    if (game.uciMoveHistory.length > moveHistory.length) {
      for (int i = moveHistory.length; i < game.uciMoveHistory.length; i++) {
        final Move? move = MoveResolver.fromUci(engine.state, game.uciMoveHistory[i]);
        if (move == null) break; // Defensive: shouldn't happen with a valid server history.
        super.makeMove(move);
      }
    } else if (game.uciMoveHistory.length < moveHistory.length) {
      // Should never happen (server history only grows), but recovering
      // by hard-resetting to the server's FEN is safer than silently
      // diverging from it.
      loadFen(game.fen);
    }

    if (previous == null || previous.status != game.status) {
      // A fresh terminal status (opponent resigned, we were timed out
      // by them, etc.) — nothing further to sync, just repaint for the
      // game-over banner.
    }

    notifyListeners();
  }

  void _tickClocks() {
    final OnlineGame? game = _onlineGame;
    if (game == null || game.status != OnlineGameStatus.active) return;

    final int elapsed = DateTime.now().millisecondsSinceEpoch - game.lastMoveAtEpochMs;
    if (sideToMove == PieceColor.white) {
      _whiteDisplayMs = (game.whiteTimeRemainingMs - elapsed).clamp(0, 1 << 31);
    } else {
      _blackDisplayMs = (game.blackTimeRemainingMs - elapsed).clamp(0, 1 << 31);
    }
    notifyListeners();

    final bool iRanOut =
        (myColor == PieceColor.white && _whiteDisplayMs <= 0) ||
        (myColor == PieceColor.black && _blackDisplayMs <= 0);
    if (iRanOut && !_timeoutClaimed) {
      _timeoutClaimed = true;
      final OnlineGameStatus winner =
          myColor == PieceColor.white ? OnlineGameStatus.blackWon : OnlineGameStatus.whiteWon;
      _repository.claimTimeout(gameId: _gameId, winner: winner);
    }
  }

  @override
  bool moveSelectedTo(int targetSquare, {PieceType promotion = PieceType.queen}) {
    if (!isMyTurn) return false;

    final int before = moveHistory.length;
    final bool applied = super.moveSelectedTo(targetSquare, promotion: promotion);
    if (applied && moveHistory.length != before) {
      _pushLastMoveToServer();
    }
    return applied;
  }

  void _pushLastMoveToServer() {
    final Move? move = lastMove;
    if (move == null) return;

    final int myRemainingMs = myColor == PieceColor.white ? _whiteDisplayMs : _blackDisplayMs;

    _repository.submitMove(
      gameId: _gameId,
      uciMove: move.uci,
      sanMove: sanHistory.last,
      resultingFen: fen,
      remainingMs: myRemainingMs,
    );

    if (status.isGameOver) {
      final OnlineGameStatus resultStatus = switch (status) {
        GameStatus.checkmate =>
          sideToMove == PieceColor.white ? OnlineGameStatus.blackWon : OnlineGameStatus.whiteWon,
        _ => OnlineGameStatus.draw,
      };
      final GameEndReason reason = switch (status) {
        GameStatus.checkmate => GameEndReason.checkmate,
        GameStatus.stalemate => GameEndReason.stalemate,
        GameStatus.drawFiftyMoveRule => GameEndReason.fiftyMoveRule,
        GameStatus.drawInsufficientMaterial => GameEndReason.insufficientMaterial,
        GameStatus.drawThreefoldRepetition => GameEndReason.threefoldRepetition,
        _ => GameEndReason.drawAgreement,
      };
      _repository.reportGameOver(gameId: _gameId, status: resultStatus, reason: reason);
    }
  }

  Future<void> resign() => _repository.resign(gameId: _gameId);

  Future<void> offerDraw() => _repository.offerDraw(gameId: _gameId);

  Future<void> respondToDrawOffer(bool accept) =>
      _repository.respondToDrawOffer(gameId: _gameId, accept: accept);

  @override
  void dispose() {
    _subscription.cancel();
    _heartbeatTimer.cancel();
    _clockTicker.cancel();
    _repository.leaveGame(gameId: _gameId);
    super.dispose();
  }
}
