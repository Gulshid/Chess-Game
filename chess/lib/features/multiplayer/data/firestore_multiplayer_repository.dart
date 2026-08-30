import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constant/app_constants.dart';
import '../domain/online_game.dart';
import '../domain/online_game_status.dart';
import '../domain/time_control.dart';
import 'multiplayer_repository.dart';

/// Firebase implementation of [MultiplayerRepository] — the roadmap's
/// Phase 7 "fastest to build, good for MVP and moderate scale" backend
/// choice, using Firestore for the game documents and matchmaking queue
/// and Firebase Auth (anonymous) for a stable per-device player id.
///
/// ### Honest limits of this implementation
///
/// The roadmap's own Phase 7 reliability checklist says: "Prevent
/// cheating basics: server-authoritative game state, move validation
/// server-side, not just client-side." This class is intentionally
/// client-only (no Cloud Functions) to keep the project's zero-backend-
/// infrastructure footprint from Phase 0 onward. Two consequences of
/// that trade-off, stated plainly rather than glossed over:
///
/// 1. **Move legality** is checked by whichever client submits the move
///    (`OnlineGameProvider` runs it through the same `ChessEngine`
///    Phase 2 built), not re-verified by a server. A modified client
///    could write an illegal move directly to Firestore. Closing this
///    gap for real means a Cloud Function (or security rules that run a
///    rules-side legality check) validating each `submitMove` write —
///    tracked as a follow-up, not done here.
/// 2. **Matchmaking pairing** (`findQuickMatch`) uses a Firestore
///    transaction where the *joining* client claims the oldest open
///    queue ticket, rather than a server assigning pairs. This works
///    correctly for the two-client race (Firestore transactions are
///    atomic) but has no server-side timeout/cleanup for abandoned
///    tickets — a scheduled Cloud Function sweeping stale tickets is the
///    production-grade version of this.
///
/// Both are flagged in the roadmap's own Phase 7 checklist as things a
/// "truly professional real-time feel" needs; this class gets the
/// client/data-model architecture fully in place so a Cloud Functions
/// layer can be added around it later without changing anything above
/// this file (`MultiplayerRepository`'s whole point, per its class doc).
class FirestoreMultiplayerRepository implements MultiplayerRepository {
  FirestoreMultiplayerRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, Object?>> get _games => _db.collection('games');
  CollectionReference<Map<String, Object?>> get _codes => _db.collection('game_codes');
  CollectionReference<Map<String, Object?>> get _queue => _db.collection('matchmaking_queue');

  String? _quickMatchTicketId;
  StreamSubscription<DocumentSnapshot<Map<String, Object?>>>? _quickMatchSub;

  @override
  String get currentUid => _auth.currentUser?.uid ?? '';

  @override
  Future<void> ensureSignedIn() async {
    if (_auth.currentUser != null) return;
    // Anonymous auth is enough here: there's no account system yet
    // (that's Phase 9's "User authentication ... via Firebase Auth"
    // with real sign-in providers) — this just needs a stable id per
    // device/session to tell the two players in a game apart.
    await _auth.signInAnonymously();
  }

  @override
  Future<OnlineGame> createPrivateGame({
    required TimeControl timeControl,
    required String displayName,
  }) async {
    await ensureSignedIn();
    final String uid = currentUid;
    final DocumentReference<Map<String, Object?>> gameRef = _games.doc();
    final int now = DateTime.now().millisecondsSinceEpoch;

    final OnlineGame game = OnlineGame(
      id: gameRef.id,
      whiteUid: uid,
      blackUid: null,
      whiteName: displayName,
      blackName: 'Waiting…',
      fen: AppConstants.startingFen,
      uciMoveHistory: const <String>[],
      sanMoveHistory: const <String>[],
      status: OnlineGameStatus.waitingForOpponent,
      timeControl: timeControl,
      whiteTimeRemainingMs: timeControl.initialSeconds * 1000,
      blackTimeRemainingMs: timeControl.initialSeconds * 1000,
      lastMoveAtEpochMs: now,
      createdAtEpochMs: now,
    );

    final String code = _generateCode();
    await gameRef.set(game.toMap());
    await _codes.doc(code).set(<String, Object?>{
      'gameId': gameRef.id,
      'createdAtEpochMs': now,
    });

    return game;
  }

  /// Exposes the code a just-created private game can be joined with —
  /// looked up separately from [createPrivateGame] so that method's
  /// return type stays a plain [OnlineGame] (the code is UI-facing
  /// metadata, not part of the game state itself).
  @override
  Future<String?> findCodeForGame(String gameId) async {
    final QuerySnapshot<Map<String, Object?>> matches =
        await _codes.where('gameId', isEqualTo: gameId).limit(1).get();
    if (matches.docs.isEmpty) return null;
    return matches.docs.first.id;
  }

  @override
  Future<OnlineGame> joinPrivateGame({
    required String code,
    required String displayName,
  }) async {
    await ensureSignedIn();
    final String uid = currentUid;
    final String normalizedCode = code.trim().toUpperCase();

    final DocumentSnapshot<Map<String, Object?>> codeDoc =
        await _codes.doc(normalizedCode).get();
    if (!codeDoc.exists) {
      throw const GameNotFoundException('No game found for that code.');
    }
    final String gameId = codeDoc.data()!['gameId'] as String;

    return _db.runTransaction<OnlineGame>((transaction) async {
      final DocumentReference<Map<String, Object?>> ref = _games.doc(gameId);
      final DocumentSnapshot<Map<String, Object?>> snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw const GameNotFoundException('That game no longer exists.');
      }
      OnlineGame game = OnlineGame.fromMap(snapshot.id, snapshot.data()!);
      if (game.status != OnlineGameStatus.waitingForOpponent) {
        throw const GameNotFoundException('That game has already started.');
      }
      if (game.whiteUid == uid) {
        // Creator re-opening their own invite link — just return it.
        return game;
      }

      final int now = DateTime.now().millisecondsSinceEpoch;
      game = game.copyWith(
        blackUid: uid,
        blackName: displayName,
        status: OnlineGameStatus.active,
        lastMoveAtEpochMs: now,
      );
      transaction.update(ref, <String, Object?>{
        'blackUid': uid,
        'blackName': displayName,
        'status': OnlineGameStatus.active.name,
        'lastMoveAtEpochMs': now,
      });
      return game;
    });
  }

  @override
  Future<OnlineGame> findQuickMatch({
    required TimeControl timeControl,
    required String displayName,
  }) async {
    await ensureSignedIn();
    final String uid = currentUid;

    // Step 1: try to claim an existing open ticket for this time
    // control (a transaction makes "claim" atomic — the two clients
    // racing to pick each other up can't both win).
    final QuerySnapshot<Map<String, Object?>> openTickets = await _queue
        .where('timeControlLabel', isEqualTo: timeControl.label)
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAtEpochMs')
        .limit(5)
        .get();

    for (final QueryDocumentSnapshot<Map<String, Object?>> ticketDoc in openTickets.docs) {
      if (ticketDoc.data()['uid'] == uid) continue; // don't match with yourself
      try {
        final String? gameId = await _db.runTransaction<String?>((transaction) async {
          final DocumentSnapshot<Map<String, Object?>> fresh =
              await transaction.get(ticketDoc.reference);
          if (!fresh.exists || fresh.data()!['status'] != 'waiting') return null;

          final String opponentUid = fresh.data()!['uid'] as String;
          final String opponentName = fresh.data()!['displayName'] as String? ?? 'Opponent';
          final int now = DateTime.now().millisecondsSinceEpoch;

          final DocumentReference<Map<String, Object?>> gameRef = _games.doc();
          final bool iAmWhite = Random().nextBool();

          final OnlineGame game = OnlineGame(
            id: gameRef.id,
            whiteUid: iAmWhite ? uid : opponentUid,
            blackUid: iAmWhite ? opponentUid : uid,
            whiteName: iAmWhite ? displayName : opponentName,
            blackName: iAmWhite ? opponentName : displayName,
            fen: AppConstants.startingFen,
            uciMoveHistory: const <String>[],
            sanMoveHistory: const <String>[],
            status: OnlineGameStatus.active,
            timeControl: timeControl,
            whiteTimeRemainingMs: timeControl.initialSeconds * 1000,
            blackTimeRemainingMs: timeControl.initialSeconds * 1000,
            lastMoveAtEpochMs: now,
            createdAtEpochMs: now,
          );

          transaction.set(gameRef, game.toMap());
          transaction.update(ticketDoc.reference, <String, Object?>{
            'status': 'matched',
            'gameId': gameRef.id,
          });
          return gameRef.id;
        });

        if (gameId != null) {
          final DocumentSnapshot<Map<String, Object?>> gameDoc = await _games.doc(gameId).get();
          return OnlineGame.fromMap(gameDoc.id, gameDoc.data()!);
        }
      } catch (_) {
        // Lost the race for this ticket (someone else claimed it, or it
        // was cancelled) — fall through and try the next candidate.
        continue;
      }
    }

    // Step 2: no open ticket to claim — post our own and wait for
    // someone else's `findQuickMatch` call to claim it, above.
    final int now = DateTime.now().millisecondsSinceEpoch;
    final DocumentReference<Map<String, Object?>> ticketRef = _queue.doc();
    _quickMatchTicketId = ticketRef.id;
    await ticketRef.set(<String, Object?>{
      'uid': uid,
      'displayName': displayName,
      'timeControlLabel': timeControl.label,
      'status': 'waiting',
      'createdAtEpochMs': now,
      'gameId': null,
    });

    final Completer<OnlineGame> completer = Completer<OnlineGame>();
    _quickMatchSub = ticketRef.snapshots().listen((snapshot) async {
      final Map<String, Object?>? data = snapshot.data();
      if (data == null) return;
      if (data['status'] == 'matched' && data['gameId'] != null && !completer.isCompleted) {
        final DocumentSnapshot<Map<String, Object?>> gameDoc =
            await _games.doc(data['gameId'] as String).get();
        if (gameDoc.exists) {
          completer.complete(OnlineGame.fromMap(gameDoc.id, gameDoc.data()!));
        }
      }
    });

    return completer.future.whenComplete(() {
      _quickMatchSub?.cancel();
      _quickMatchSub = null;
      _quickMatchTicketId = null;
    });
  }

  @override
  Future<void> cancelQuickMatch() async {
    await _quickMatchSub?.cancel();
    _quickMatchSub = null;
    final String? ticketId = _quickMatchTicketId;
    _quickMatchTicketId = null;
    if (ticketId != null) {
      await _queue.doc(ticketId).delete();
    }
  }

  @override
  Stream<OnlineGame> watchGame(String gameId) {
    return _games.doc(gameId).snapshots().where((s) => s.exists).map(
          (s) => OnlineGame.fromMap(s.id, s.data()!),
        );
  }

  @override
  Future<void> submitMove({
    required String gameId,
    required String uciMove,
    required String sanMove,
    required String resultingFen,
    required int remainingMs,
  }) async {
    final String uid = currentUid;
    final DocumentReference<Map<String, Object?>> ref = _games.doc(gameId);

    await _db.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, Object?>> snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final OnlineGame game = OnlineGame.fromMap(snapshot.id, snapshot.data()!);
      if (game.status.isOver) return;

      final bool isWhite = game.whiteUid == uid;
      final bool isBlacksTurn = game.uciMoveHistory.length.isOdd;
      final bool isMyTurn = isWhite ? !isBlacksTurn : isBlacksTurn;
      if (!isMyTurn) return; // Stale/duplicate submission — ignore.

      final int now = DateTime.now().millisecondsSinceEpoch;
      final int incrementMs = game.timeControl.incrementSeconds * 1000;
      final int updatedRemaining = remainingMs + incrementMs;

      transaction.update(ref, <String, Object?>{
        'fen': resultingFen,
        'uciMoveHistory': <String>[...game.uciMoveHistory, uciMove],
        'sanMoveHistory': <String>[...game.sanMoveHistory, sanMove],
        'lastMoveAtEpochMs': now,
        'drawOfferedByUid': null, // A move implicitly declines any open draw offer.
        if (isWhite) 'whiteTimeRemainingMs': updatedRemaining,
        if (!isWhite) 'blackTimeRemainingMs': updatedRemaining,
      });
    });
  }

  /// Call after a move is confirmed applied locally with the *resulting*
  /// [GameStatus] from `ChessEngine`, so the document's status reflects
  /// checkmate/stalemate/draw immediately rather than waiting on a
  /// second round-trip. Kept as a separate call (rather than folded into
  /// [submitMove]) so `OnlineGameProvider` — which already has the
  /// engine's verdict on hand right after applying the move — can pass
  /// it straight through instead of this class re-deriving game-over
  /// state from FEN alone.
  @override
  Future<void> reportGameOver({
    required String gameId,
    required OnlineGameStatus status,
    required GameEndReason reason,
  }) async {
    await _games.doc(gameId).update(<String, Object?>{
      'status': status.name,
      'endReason': reason.name,
    });
  }

  @override
  Future<void> resign({required String gameId}) async {
    final DocumentSnapshot<Map<String, Object?>> snapshot = await _games.doc(gameId).get();
    if (!snapshot.exists) return;
    final OnlineGame game = OnlineGame.fromMap(snapshot.id, snapshot.data()!);
    final bool iAmWhite = game.whiteUid == currentUid;
    await _games.doc(gameId).update(<String, Object?>{
      'status': (iAmWhite ? OnlineGameStatus.blackWon : OnlineGameStatus.whiteWon).name,
      'endReason': GameEndReason.resignation.name,
    });
  }

  @override
  Future<void> offerDraw({required String gameId}) async {
    await _games.doc(gameId).update(<String, Object?>{'drawOfferedByUid': currentUid});
  }

  @override
  Future<void> respondToDrawOffer({required String gameId, required bool accept}) async {
    if (accept) {
      await _games.doc(gameId).update(<String, Object?>{
        'status': OnlineGameStatus.draw.name,
        'endReason': GameEndReason.drawAgreement.name,
        'drawOfferedByUid': null,
      });
    } else {
      await _games.doc(gameId).update(<String, Object?>{'drawOfferedByUid': null});
    }
  }

  @override
  Future<void> claimTimeout({required String gameId, required OnlineGameStatus winner}) async {
    final DocumentReference<Map<String, Object?>> ref = _games.doc(gameId);
    await _db.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, Object?>> snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final OnlineGame game = OnlineGame.fromMap(snapshot.id, snapshot.data()!);
      if (game.status.isOver) return; // Already resolved — avoid a duplicate claim.
      transaction.update(ref, <String, Object?>{
        'status': winner.name,
        'endReason': GameEndReason.timeout.name,
      });
    });
  }

  @override
  Future<void> sendHeartbeat({required String gameId}) async {
    final DocumentSnapshot<Map<String, Object?>> snapshot = await _games.doc(gameId).get();
    if (!snapshot.exists) return;
    final OnlineGame game = OnlineGame.fromMap(snapshot.id, snapshot.data()!);
    final bool iAmWhite = game.whiteUid == currentUid;
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _games.doc(gameId).update(<String, Object?>{
      if (iAmWhite) 'whiteLastSeenEpochMs': now,
      if (!iAmWhite) 'blackLastSeenEpochMs': now,
    });
  }

  @override
  Future<void> leaveGame({required String gameId}) async {
    final DocumentSnapshot<Map<String, Object?>> snapshot = await _games.doc(gameId).get();
    if (!snapshot.exists) return;
    final OnlineGame game = OnlineGame.fromMap(snapshot.id, snapshot.data()!);
    if (game.status == OnlineGameStatus.waitingForOpponent) {
      // Nobody else has joined yet — safe to just delete the invite.
      await _games.doc(gameId).delete();
    }
    // If the game is active, leaving doesn't end it — `sendHeartbeat`
    // simply stops arriving, and the opponent's stale-presence check
    // (see `ReconnectBanner`) surfaces that as a disconnect. Ending an
    // active game outright on navigation-away would let a losing player
    // dodge a loss by just closing the app, which the roadmap's Phase 7
    // reliability checklist explicitly guards against ("abandonment/
    // timeout as a loss") — that's `claimTimeout`'s job instead.
  }

  String _generateCode() {
    const String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I
    final Random random = Random();
    return List<String>.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
