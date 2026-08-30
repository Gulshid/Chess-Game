import '../domain/online_game.dart';
import '../domain/online_game_status.dart';
import '../domain/time_control.dart';

/// What the multiplayer presentation layer needs from a backend, kept as
/// an interface (rather than calling `FirestoreMultiplayerRepository`
/// directly everywhere) for two reasons the roadmap itself calls out:
///
/// 1. Phase 0's tech-stack shortlist treats the backend as a genuinely
///    open choice ("Firebase ... or a custom WebSocket server ...
///    recommended for a truly 'professional' real-time feel") — an
///    interface is what lets a `WebSocketMultiplayerRepository` be
///    written later and dropped in without touching
///    `OnlineGameProvider` or any screen.
/// 2. Phase 4's "Dependency Injection" principle ("engine, AI, and
///    networking layers are swappable and testable") applies just as
///    much to this networking layer as it did to the engine in Phase 4
///    — widget/provider tests can hand in a fake implementation instead
///    of hitting real Firestore.
abstract class MultiplayerRepository {
  /// The signed-in user's stable id (anonymous auth is enough for this
  /// app — see `FirestoreMultiplayerRepository`'s doc — but callers
  /// shouldn't need to know that).
  String get currentUid;

  /// Ensures the caller is authenticated (creating an anonymous session
  /// if needed) before any other call.
  Future<void> ensureSignedIn();

  /// Creates a private game other players join via [joinPrivateGame]'s
  /// [code]. Returns the created [OnlineGame] (status
  /// `waitingForOpponent`).
  Future<OnlineGame> createPrivateGame({
    required TimeControl timeControl,
    required String displayName,
  });

  /// Joins a private game by its short shareable code. Throws
  /// [GameNotFoundException] if the code doesn't resolve to a waiting
  /// game.
  Future<OnlineGame> joinPrivateGame({
    required String code,
    required String displayName,
  });

  /// Enters the quick-match queue for [timeControl] and completes once
  /// paired with an opponent (or throws if [cancelQuickMatch] is called
  /// first). See `FirestoreMultiplayerRepository`'s class doc for the
  /// documented limits of doing this without a matchmaking Cloud
  /// Function.
  Future<OnlineGame> findQuickMatch({
    required TimeControl timeControl,
    required String displayName,
  });

  Future<void> cancelQuickMatch();

  /// Looks up the shareable join code for a private game created via
  /// [createPrivateGame], if one exists.
  Future<String?> findCodeForGame(String gameId);

  /// Streams every update to [gameId] — the single source of truth
  /// `OnlineGameProvider` mirrors into a local [ChessEngine].
  Stream<OnlineGame> watchGame(String gameId);

  /// Submits [uciMove] as the next move in [gameId]. [remainingMs] is
  /// this player's own clock reading at the moment of the move (used to
  /// update the stored remaining time plus increment).
  Future<void> submitMove({
    required String gameId,
    required String uciMove,
    required String sanMove,
    required String resultingFen,
    required int remainingMs,
  });

  Future<void> resign({required String gameId});

  Future<void> offerDraw({required String gameId});

  Future<void> respondToDrawOffer({required String gameId, required bool accept});

  /// Called when either clock hits zero, client-side — see
  /// `FirestoreMultiplayerRepository`'s class doc for why this is
  /// client-reported rather than server-enforced in this project.
  Future<void> claimTimeout({required String gameId, required OnlineGameStatus winner});

  /// Records the terminal result once local engine state (checkmate/
  /// stalemate/draw) determines the game is over — see
  /// `FirestoreMultiplayerRepository.reportGameOver`'s doc for why this
  /// is a separate call from [submitMove].
  Future<void> reportGameOver({
    required String gameId,
    required OnlineGameStatus status,
    required GameEndReason reason,
  });

  /// Presence heartbeat — call periodically (e.g. every 15s) while a
  /// game screen is open so the opponent can distinguish "thinking" from
  /// "disconnected".
  Future<void> sendHeartbeat({required String gameId});

  Future<void> leaveGame({required String gameId});
}

class GameNotFoundException implements Exception {
  const GameNotFoundException(this.message);
  final String message;
  @override
  String toString() => message;
}
