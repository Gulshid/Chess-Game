import '../../../core/constant/app_constants.dart';
import '../../account/domain/rating.dart';
import 'online_game_status.dart';
import 'time_control.dart';

/// A snapshot of one online game, as stored in the `games/{gameId}`
/// Firestore document and streamed down to both players.
///
/// This is a *whole-document* sync model (every move rewrites the full
/// move list + resulting FEN) rather than an event-sourced one (a
/// separate `moves` sub-collection appended to). That trade-off is
/// deliberate for the scope here: whole-document sync is one read + one
/// listener per game, trivially gives every field "last write wins"
/// semantics, and needs no server-side aggregation step — see
/// `FirestoreMultiplayerRepository`'s class doc for the honest limits
/// that trade-off comes with.
class OnlineGame {
  const OnlineGame({
    required this.id,
    required this.whiteUid,
    required this.blackUid,
    this.whiteName = 'White',
    this.blackName = 'Black',
    this.whiteRating = Rating.startingRating,
    this.blackRating = Rating.startingRating,
    required this.fen,
    required this.uciMoveHistory,
    required this.sanMoveHistory,
    required this.status,
    this.endReason,
    required this.timeControl,
    required this.whiteTimeRemainingMs,
    required this.blackTimeRemainingMs,
    required this.lastMoveAtEpochMs,
    required this.createdAtEpochMs,
    this.drawOfferedByUid,
    this.rematchOfferedByUid,
    this.whiteLastSeenEpochMs,
    this.blackLastSeenEpochMs,
  });

  final String id;

  final String? whiteUid;
  final String? blackUid;
  final String whiteName;
  final String blackName;

  /// Elo-style rating snapshot for each player at the moment this game
  /// was created/joined (see `MultiplayerRepository.createPrivateGame`'s
  /// doc for why it's captured then rather than re-read at game-over) —
  /// used by `OnlineGameScreen._recordResultOnce` to update
  /// `AuthProvider.recordGameResult` without a second Firestore read.
  final int whiteRating;
  final int blackRating;

  final String fen;
  final List<String> uciMoveHistory;
  final List<String> sanMoveHistory;

  final OnlineGameStatus status;
  final GameEndReason? endReason;

  final TimeControl timeControl;
  final int whiteTimeRemainingMs;
  final int blackTimeRemainingMs;

  /// Server-recorded timestamp (epoch ms) of the last move — clocks are
  /// derived client-side from this plus [whiteTimeRemainingMs] /
  /// [blackTimeRemainingMs] rather than trusting a client-ticked local
  /// timer alone, so a player who reconnects sees an accurate remaining
  /// time immediately.
  final int lastMoveAtEpochMs;
  final int createdAtEpochMs;

  final String? drawOfferedByUid;
  final String? rematchOfferedByUid;

  /// Last presence heartbeat from each player — used to show "opponent
  /// disconnected" rather than silently waiting forever. See
  /// [FirestoreMultiplayerRepository]'s reconnection notes.
  final int? whiteLastSeenEpochMs;
  final int? blackLastSeenEpochMs;

  bool get isFull => whiteUid != null && blackUid != null;

  factory OnlineGame.fromMap(String id, Map<String, Object?> map) {
    final Map<String, Object?> tc = (map['timeControl'] as Map?)?.cast<String, Object?>() ??
        TimeControl.rapid10.toJson();
    return OnlineGame(
      id: id,
      whiteUid: map['whiteUid'] as String?,
      blackUid: map['blackUid'] as String?,
      whiteName: map['whiteName'] as String? ?? 'White',
      blackName: map['blackName'] as String? ?? 'Black',
      whiteRating: (map['whiteRating'] as num?)?.toInt() ?? Rating.startingRating,
      blackRating: (map['blackRating'] as num?)?.toInt() ?? Rating.startingRating,
      fen: map['fen'] as String? ?? AppConstants.startingFen,
      uciMoveHistory: (map['uciMoveHistory'] as List?)?.cast<String>() ?? const <String>[],
      sanMoveHistory: (map['sanMoveHistory'] as List?)?.cast<String>() ?? const <String>[],
      status: OnlineGameStatus.fromWire(map['status'] as String? ?? 'waitingForOpponent'),
      endReason: GameEndReason.fromWire(map['endReason'] as String?),
      timeControl: TimeControl.fromJson(tc),
      whiteTimeRemainingMs: (map['whiteTimeRemainingMs'] as num?)?.toInt() ?? 0,
      blackTimeRemainingMs: (map['blackTimeRemainingMs'] as num?)?.toInt() ?? 0,
      lastMoveAtEpochMs: (map['lastMoveAtEpochMs'] as num?)?.toInt() ?? 0,
      createdAtEpochMs: (map['createdAtEpochMs'] as num?)?.toInt() ?? 0,
      drawOfferedByUid: map['drawOfferedByUid'] as String?,
      rematchOfferedByUid: map['rematchOfferedByUid'] as String?,
      whiteLastSeenEpochMs: (map['whiteLastSeenEpochMs'] as num?)?.toInt(),
      blackLastSeenEpochMs: (map['blackLastSeenEpochMs'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'whiteUid': whiteUid,
        'blackUid': blackUid,
        'whiteName': whiteName,
        'blackName': blackName,
        'whiteRating': whiteRating,
        'blackRating': blackRating,
        'fen': fen,
        'uciMoveHistory': uciMoveHistory,
        'sanMoveHistory': sanMoveHistory,
        'status': status.name,
        'endReason': endReason?.name,
        'timeControl': timeControl.toJson(),
        'whiteTimeRemainingMs': whiteTimeRemainingMs,
        'blackTimeRemainingMs': blackTimeRemainingMs,
        'lastMoveAtEpochMs': lastMoveAtEpochMs,
        'createdAtEpochMs': createdAtEpochMs,
        'drawOfferedByUid': drawOfferedByUid,
        'rematchOfferedByUid': rematchOfferedByUid,
        'whiteLastSeenEpochMs': whiteLastSeenEpochMs,
        'blackLastSeenEpochMs': blackLastSeenEpochMs,
      };

  OnlineGame copyWith({
    String? whiteUid,
    String? blackUid,
    String? whiteName,
    String? blackName,
    int? whiteRating,
    int? blackRating,
    String? fen,
    List<String>? uciMoveHistory,
    List<String>? sanMoveHistory,
    OnlineGameStatus? status,
    GameEndReason? endReason,
    int? whiteTimeRemainingMs,
    int? blackTimeRemainingMs,
    int? lastMoveAtEpochMs,
    String? drawOfferedByUid,
    bool clearDrawOffer = false,
    String? rematchOfferedByUid,
    int? whiteLastSeenEpochMs,
    int? blackLastSeenEpochMs,
  }) {
    return OnlineGame(
      id: id,
      whiteUid: whiteUid ?? this.whiteUid,
      blackUid: blackUid ?? this.blackUid,
      whiteName: whiteName ?? this.whiteName,
      blackName: blackName ?? this.blackName,
      whiteRating: whiteRating ?? this.whiteRating,
      blackRating: blackRating ?? this.blackRating,
      fen: fen ?? this.fen,
      uciMoveHistory: uciMoveHistory ?? this.uciMoveHistory,
      sanMoveHistory: sanMoveHistory ?? this.sanMoveHistory,
      status: status ?? this.status,
      endReason: endReason ?? this.endReason,
      timeControl: timeControl,
      whiteTimeRemainingMs: whiteTimeRemainingMs ?? this.whiteTimeRemainingMs,
      blackTimeRemainingMs: blackTimeRemainingMs ?? this.blackTimeRemainingMs,
      lastMoveAtEpochMs: lastMoveAtEpochMs ?? this.lastMoveAtEpochMs,
      createdAtEpochMs: createdAtEpochMs,
      drawOfferedByUid: clearDrawOffer ? null : (drawOfferedByUid ?? this.drawOfferedByUid),
      rematchOfferedByUid: rematchOfferedByUid ?? this.rematchOfferedByUid,
      whiteLastSeenEpochMs: whiteLastSeenEpochMs ?? this.whiteLastSeenEpochMs,
      blackLastSeenEpochMs: blackLastSeenEpochMs ?? this.blackLastSeenEpochMs,
    );
  }
}