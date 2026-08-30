import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

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

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _showGameOverDialogIfNeeded() {
    final status = _provider.onlineGame?.status;
    if (status == null || !status.isOver) return;
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
