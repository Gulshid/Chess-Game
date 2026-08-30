import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../features/advanced/presentation/analysis_board_screen.dart';
import '../features/advanced/presentation/hint_button.dart';
import '../features/ai/presentation/new_game_dialog.dart';
import '../features/board_ui/domain/board_theme.dart';
import '../features/board_ui/presentation/widgets/captured_pieces_tray.dart';
import '../features/board_ui/presentation/widgets/chess_board.dart';
import '../features/board_ui/presentation/widgets/game_controls.dart';
import '../features/board_ui/presentation/widgets/move_history_panel.dart';
import '../features/chess_engine/domain/game_status.dart';
import '../features/chess_engine/domain/models/piece.dart';
import '../providers/game_provider.dart';

/// The primary screen once a game is underway: board + captured-piece
/// trays + move list + controls, laid out for a phone in portrait and
/// for a wider tablet/desktop viewport.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _flipped = false;
  BoardTheme _theme = BoardTheme.classicGreen;

  Future<void> _startNewGame() async {
    final game = context.read<GameProvider>();
    final NewGameSelection? selection = await showNewGameDialog(context);
    if (selection == null) return;
    game.startGameVsAi(aiPlaysAs: selection.aiPlaysAs, difficulty: selection.difficulty);
    setState(() => _flipped = selection.aiPlaysAs == PieceColor.white);
  }

  void _showGameOverDialogIfNeeded(GameProvider game) {
    if (!game.isGameOver) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            game.gameOverOverrideMessage ?? _statusHeadline(game.status, game.sideToMove),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startNewGame();
              },
              child: const Text('New game'),
            ),
          ],
          content: Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: SizedBox(
              width: double.minPositive,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.query_stats),
                label: const Text('Review this game'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AnalysisBoardScreen(initialMoves: game.moveHistory),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
  }

  String _statusHeadline(GameStatus status, PieceColor sideToMove) {
    return switch (status) {
      GameStatus.checkmate =>
        '${sideToMove == PieceColor.white ? 'Black' : 'White'} wins by checkmate',
      GameStatus.stalemate => 'Draw by stalemate',
      GameStatus.drawFiftyMoveRule => 'Draw — fifty-move rule',
      GameStatus.drawInsufficientMaterial => 'Draw — insufficient material',
      GameStatus.drawThreefoldRepetition => 'Draw — threefold repetition',
      _ => 'Game over',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        _showGameOverDialogIfNeeded(game);
        final bool wide = MediaQuery.of(context).size.width > 720;

        final Widget board = Padding(
          padding: EdgeInsets.all(12.w),
          child: ChessBoard(
            game: game,
            theme: _theme,
            flipped: _flipped,
            interactive: !game.isAiThinking && !game.isGameOver,
          ),
        );

        final Widget sidePanel = _SidePanel(game: game);

        return Scaffold(
          appBar: AppBar(
            title: Text(_appBarTitle(game)),
            actions: [
              HintButton(game: game),
              IconButton(
                icon: const Icon(Icons.palette_outlined),
                tooltip: 'Board theme',
                onPressed: () => _pickTheme(context),
              ),
            ],
          ),
          body: SafeArea(
            child: wide
                ? Row(
                    children: [
                      Expanded(flex: 3, child: Center(child: board)),
                      SizedBox(width: 320.w, child: sidePanel),
                    ],
                  )
                : Column(
                    children: [
                      Center(child: board),
                      Expanded(child: sidePanel),
                    ],
                  ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: GameControls(
                game: game,
                onFlipBoard: () => setState(() => _flipped = !_flipped),
                onNewGame: _startNewGame,
                onResign: game.resign,
                onOfferDraw: game.offerDraw,
              ),
            ),
          ),
        );
      },
    );
  }

  String _appBarTitle(GameProvider game) {
    if (game.isAiThinking) return 'AI is thinking…';
    if (game.status == GameStatus.check) {
      return '${game.sideToMove == PieceColor.white ? 'White' : 'Black'} is in check';
    }
    return game.sideToMove == PieceColor.white ? 'White to move' : 'Black to move';
  }

  void _pickTheme(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final BoardTheme t in BoardTheme.all)
                ListTile(
                  title: Text(t.name),
                  trailing: t == _theme ? const Icon(Icons.check) : null,
                  onTap: () {
                    setState(() => _theme = t);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.game});

  final GameProvider game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CapturedPiecesTray(color: PieceColor.white),
          SizedBox(height: 4.h),
          CapturedPiecesTray(color: PieceColor.black),
          SizedBox(height: 8.h),
          const Divider(height: 1),
          Expanded(child: MoveHistoryPanel()),
        ],
      ),
    );
  }
}
