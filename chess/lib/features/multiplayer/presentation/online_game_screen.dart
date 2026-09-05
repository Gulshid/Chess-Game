import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../account/data/firestore_saved_games_repository.dart';
import '../../account/data/hive_cached_saved_games_repository.dart';
import '../../account/data/saved_games_repository.dart';
import '../../account/domain/rating.dart';
import '../../account/domain/saved_game.dart';
import '../../account/presentation/auth_provider.dart';
import '../../advanced/domain/pgn.dart';
import '../../board_ui/domain/board_theme.dart';
import '../../board_ui/presentation/widgets/captured_pieces_tray.dart';
import '../../board_ui/presentation/widgets/chess_board.dart';
import '../../board_ui/presentation/widgets/move_history_panel.dart';
import '../../chess_engine/domain/models/piece.dart';
import '../../../providers/game_provider.dart';
import '../data/multiplayer_repository.dart';
import '../domain/online_game_status.dart';
import 'online_game_provider.dart';
import 'widgets/chess_clock.dart';
import 'widgets/opponent_bar.dart';
import 'widgets/reconnect_banner.dart';

/// The live online game screen — Phase 7's counterpart to [GameScreen]
/// (Phase 5/6). Reuses every board_ui widget from those phases
/// unmodified by registering [OnlineGameProvider] under the `GameProvider`
/// type, exactly like [AnalysisBoardScreen] (Phase 8) and [PuzzleScreen]
/// (Phase 8) do — see `OnlineGameProvider`'s class doc for why that
/// works.
class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({super.key, required this.repository, required this.gameId});

  final MultiplayerRepository repository;
  final String gameId;

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  late final OnlineGameProvider _provider = OnlineGameProvider(
    repository: widget.repository,
    gameId: widget.gameId,
    myUid: widget.repository.currentUid,
  );

  // Phase 9: cloud save + rating update for this device/account — see
  // `SavedGamesScreen`'s `_LazySavedGamesRepository` for why this is
  // constructed the same lazy way rather than injected, and
  // `_recordResultOnce`'s doc for why it's a plain field guarded by a
  // flag rather than something `OnlineGameProvider` itself calls.
  final SavedGamesRepository _savedGamesRepository =
      HiveCachedSavedGamesRepository(cloud: FirestoreSavedGamesRepository());
  bool _resultRecorded = false;

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  /// Applies this game's result to the signed-in player's rating
  /// ([AuthProvider.recordGameResult]) and saves it to their game
  /// history ([SavedGamesRepository.saveGame]) — exactly once per game,
  /// guarded by [_resultRecorded] since [_showGameOverDialogIfNeeded]
  /// (and therefore this) runs on every rebuild while the game stays
  /// over, not just the first frame that detects it.
  ///
  /// Deliberately done here in the screen rather than inside
  /// [OnlineGameProvider] itself: the provider's job (per its own class
  /// doc) is mirroring Firestore into local `ChessEngine`/UI state, the
  /// same responsibility `GameProvider` has for local/AI games. Account
  /// side-effects are a different concern that both `GameScreen` (for
  /// local/AI games) and this screen (for online games) apply the same
  /// way: react to a terminal [OnlineGameStatus] once, from the screen
  /// that already has both the game and an [AuthProvider] in scope.
  void _recordResultOnce() {
    if (_resultRecorded) return;
    final game = _provider.onlineGame;
    final PieceColor? myColor = _provider.myColor;
    if (game == null || myColor == null || !game.status.isOver) return;
    _resultRecorded = true;

    final MatchResult? result = switch (game.status) {
      OnlineGameStatus.whiteWon =>
        myColor == PieceColor.white ? MatchResult.win : MatchResult.loss,
      OnlineGameStatus.blackWon =>
        myColor == PieceColor.black ? MatchResult.win : MatchResult.loss,
      OnlineGameStatus.draw => MatchResult.draw,
      _ => null, // Aborted (e.g. opponent left pre-game) — no rating impact.
    };

    final AuthProvider auth = context.read<AuthProvider>();
    final int opponentRating = myColor == PieceColor.white ? game.blackRating : game.whiteRating;
    final String opponentName = myColor == PieceColor.white ? game.blackName : game.whiteName;

    if (result != null) {
      auth.recordGameResult(result: result, opponentRating: opponentRating);
    }

    final String? uid = auth.user?.uid;
    if (uid == null) return;

    final String pgnResult = switch (game.status) {
      OnlineGameStatus.whiteWon => '1-0',
      OnlineGameStatus.blackWon => '0-1',
      OnlineGameStatus.draw => '1/2-1/2',
      _ => '*',
    };
    final String pgn = Pgn.generate(
      sanMoves: game.sanMoveHistory,
      event: 'Online · ${game.timeControl.label}',
      white: game.whiteName,
      black: game.blackName,
      result: pgnResult,
    );
    final SavedGameOutcome outcome = switch (result) {
      MatchResult.win => SavedGameOutcome.win,
      MatchResult.loss => SavedGameOutcome.loss,
      MatchResult.draw => SavedGameOutcome.draw,
      null => SavedGameOutcome.unknown,
    };
    _savedGamesRepository.saveGame(
      uid,
      SavedGame(
        id: game.id,
        pgn: pgn,
        source: SavedGameSource.online,
        outcome: outcome,
        opponentLabel: 'vs. $opponentName',
        playerColorWasWhite: myColor == PieceColor.white,
        moveCount: game.sanMoveHistory.length,
        playedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _showGameOverDialogIfNeeded() {
    final status = _provider.onlineGame?.status;
    if (status == null || !status.isOver) return;
    _recordResultOnce();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(_resultText()),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Back to menu'),
            ),
          ],
        ),
      );
    });
  }

  String _resultText() {
    final game = _provider.onlineGame!;
    final myColor = _provider.myColor;
    final String outcome = switch (game.status) {
      OnlineGameStatus.whiteWon => myColor == PieceColor.white ? 'You won!' : 'You lost',
      OnlineGameStatus.blackWon => myColor == PieceColor.black ? 'You won!' : 'You lost',
      OnlineGameStatus.draw => 'Draw',
      OnlineGameStatus.aborted => 'Game aborted',
      _ => 'Game over',
    };
    final String reason = switch (game.endReason) {
      GameEndReason.checkmate => 'by checkmate',
      GameEndReason.resignation => 'by resignation',
      GameEndReason.timeout => 'on time',
      GameEndReason.drawAgreement => 'by agreement',
      GameEndReason.stalemate => '— stalemate',
      GameEndReason.insufficientMaterial => '— insufficient material',
      GameEndReason.threefoldRepetition => '— threefold repetition',
      GameEndReason.fiftyMoveRule => '— fifty-move rule',
      GameEndReason.abandonment => '— opponent left',
      null => '',
    };
    return '$outcome $reason'.trim();
  }

  Future<void> _confirmResign() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign?'),
        content: const Text('This counts as a loss.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Resign')),
        ],
      ),
    );
    if (confirmed == true) _provider.resign();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GameProvider>.value(value: _provider),
      ],
      child: AnimatedBuilder(
        animation: _provider,
        builder: (context, _) {
          _showGameOverDialogIfNeeded();

          final game = _provider.onlineGame;
          if (game == null) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final PieceColor? myColor = _provider.myColor;
          final bool flipped = myColor == PieceColor.black;
          final bool wide = MediaQuery.of(context).size.width > 720;

          final Widget board = Padding(
            padding: EdgeInsets.all(12.w),
            child: ChessBoard(
              game: _provider,
              theme: BoardTheme.classicGreen,
              flipped: flipped,
              interactive: _provider.isMyTurn,
            ),
          );

          return Scaffold(
            appBar: AppBar(
              title: Text(_provider.isMyTurn ? 'Your move' : "Opponent's move"),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  ReconnectBanner(provider: _provider),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    child: OpponentBar(provider: _provider),
                  ),
                  if (_provider.drawOfferedByOpponent)
                    _DrawOfferBanner(provider: _provider),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ChessClock(
                          label: myColor == PieceColor.white ? 'You' : 'Opponent',
                          remainingMs: _provider.whiteDisplayMs,
                          isActive: _provider.sideToMove == PieceColor.white,
                        ),
                        ChessClock(
                          label: myColor == PieceColor.black ? 'You' : 'Opponent',
                          remainingMs: _provider.blackDisplayMs,
                          isActive: _provider.sideToMove == PieceColor.black,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              Expanded(flex: 3, child: Center(child: board)),
                              SizedBox(
                                width: 320.w,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: MoveHistoryPanel(),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Center(child: board),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                                  child: const MoveHistoryPanel(),
                                ),
                              ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: CapturedPiecesTray(color: PieceColor.white),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 12.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Resign'),
                      onPressed: game.status == OnlineGameStatus.active ? _confirmResign : null,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.handshake_outlined),
                      label: Text(_provider.drawOfferedByMe ? 'Draw offered' : 'Offer draw'),
                      onPressed: game.status == OnlineGameStatus.active && !_provider.drawOfferedByMe
                          ? _provider.offerDraw
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DrawOfferBanner extends StatelessWidget {
  const _DrawOfferBanner({required this.provider});

  final OnlineGameProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
      child: Row(
        children: [
          Expanded(child: Text('${provider.opponentName} offered a draw')),
          TextButton(
            onPressed: () => provider.respondToDrawOffer(false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => provider.respondToDrawOffer(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}
