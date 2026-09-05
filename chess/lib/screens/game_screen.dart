import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../features/account/data/firestore_saved_games_repository.dart';
import '../features/account/data/hive_cached_saved_games_repository.dart';
import '../features/account/data/saved_games_repository.dart';
import '../features/account/domain/saved_game.dart';
import '../features/account/presentation/auth_provider.dart';
import '../features/account/presentation/settings_provider.dart';
import '../features/advanced/domain/pgn.dart';
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
  late BoardTheme _theme;

  // Phase 9: local/AI games are saved to history the same way online
  // games are (see `OnlineGameScreen._savedGamesRepository`'s doc for
  // why this is a plain field rather than something `GameProvider`
  // itself does) — `_gameSaved` guards against saving the same finished
  // game twice across rebuilds, mirroring `OnlineGameScreen`'s
  // `_resultRecorded`. Local/AI games don't touch [AuthProvider]'s
  // rating — see [ProfileRepository.recordGameResult]'s doc for why
  // that's ranked-online-only.
  final SavedGamesRepository _savedGamesRepository =
      HiveCachedSavedGamesRepository(cloud: FirestoreSavedGamesRepository());
  bool _gameSaved = false;

  @override
  void initState() {
    super.initState();
    // Phase 9: start from the player's saved default board theme
    // instead of always `BoardTheme.classicGreen` — still changeable
    // per-game via [_pickTheme], which now also persists the choice.
    _theme = context.read<SettingsProvider>().settings.boardTheme;
  }

  Future<void> _startNewGame() async {
    final game = context.read<GameProvider>();
    _gameSaved = false;
    final NewGameSelection? selection = await showNewGameDialog(context);
    if (selection == null) return;
    game.startGameVsAi(aiPlaysAs: selection.aiPlaysAs, difficulty: selection.difficulty);
    setState(() => _flipped = selection.aiPlaysAs == PieceColor.white);
  }

  /// Saves the just-finished game to history — see the `_gameSaved`
  /// field doc above for why this is guarded and scoped to local/AI
  /// games only.
  void _saveFinishedGameOnce(GameProvider game) {
    if (_gameSaved || !game.isGameOver || game.sanHistory.isEmpty) return;
    _gameSaved = true;

    final String? uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    final bool vsAi = game.aiColor != null;
    // Local 2-player has no single "me" to score a win/loss against —
    // White's perspective is just the display convention for that case;
    // for a vs-AI game, "me" is unambiguous (whichever color the AI
    // isn't playing).
    final PieceColor perspective =
        vsAi ? (game.aiColor == PieceColor.white ? PieceColor.black : PieceColor.white) : PieceColor.white;

    final SavedGameOutcome outcome = switch (game.status) {
      GameStatus.checkmate =>
        game.sideToMove == perspective ? SavedGameOutcome.loss : SavedGameOutcome.win,
      GameStatus.stalemate ||
      GameStatus.drawFiftyMoveRule ||
      GameStatus.drawInsufficientMaterial ||
      GameStatus.drawThreefoldRepetition =>
        SavedGameOutcome.draw,
      _ => SavedGameOutcome.unknown,
    };
    final String pgnResult = switch (game.status) {
      GameStatus.checkmate => game.sideToMove == PieceColor.white ? '0-1' : '1-0',
      GameStatus.stalemate ||
      GameStatus.drawFiftyMoveRule ||
      GameStatus.drawInsufficientMaterial ||
      GameStatus.drawThreefoldRepetition =>
        '1/2-1/2',
      _ => '*',
    };

    final String pgn = Pgn.generate(
      sanMoves: game.sanHistory,
      event: vsAi ? 'vs. AI (${game.aiDifficulty.label})' : 'Local 2-player',
      white: vsAi ? (game.aiColor == PieceColor.white ? 'AI' : 'Player') : 'White',
      black: vsAi ? (game.aiColor == PieceColor.black ? 'AI' : 'Player') : 'Black',
      result: pgnResult,
    );

    _savedGamesRepository.saveGame(
      uid,
      SavedGame(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        pgn: pgn,
        source: vsAi ? SavedGameSource.ai : SavedGameSource.local,
        outcome: outcome,
        opponentLabel: vsAi ? 'vs. AI · ${game.aiDifficulty.label}' : 'Local 2-player',
        playerColorWasWhite: perspective == PieceColor.white,
        moveCount: game.sanHistory.length,
        playedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _showGameOverDialogIfNeeded(GameProvider game) {
    if (!game.isGameOver) return;
    _saveFinishedGameOnce(game);
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
                    context.read<SettingsProvider>().setBoardTheme(t.name);
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
