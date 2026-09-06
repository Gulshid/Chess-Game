import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../core/constant/app_colors.dart';

import '../core/services/game_feedback_service.dart';
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
import '../features/board_ui/presentation/widgets/game_over_dialog.dart';
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
  //
  // Lazily constructed rather than a plain field initializer: building
  // `FirestoreSavedGamesRepository()` touches `FirebaseFirestore.instance`
  // immediately, which throws if Firebase hasn't finished initializing
  // yet (or isn't configured at all, e.g. in a widget test that pumps
  // this screen without a real Firebase app). Deferring construction to
  // first actual use — i.e. the moment a game genuinely finishes — means
  // a game that never reaches game-over never touches Firebase at all.
  SavedGamesRepository? _savedGamesRepositoryInstance;
  SavedGamesRepository get _savedGamesRepository => _savedGamesRepositoryInstance ??=
      HiveCachedSavedGamesRepository(cloud: FirestoreSavedGamesRepository());
  bool _gameSaved = false;

  /// Phase 11: guards the game-end sound/haptic hit the same way
  /// [_gameSaved] guards the save-to-history call — without it, every
  /// rebuild while the game-over dialog is up (e.g. from an unrelated
  /// `SettingsProvider` change) would re-fire the feedback.
  bool _gameOverFeedbackPlayed = false;

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
    _gameOverFeedbackPlayed = false;
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

  /// The dialog/feedback-relevant outcome of the just-finished game, from
  /// the perspective of whoever is looking at this screen. Mirrors
  /// [_saveFinishedGameOnce]'s "local 2-player has no single 'me'"
  /// reasoning — kept as a separate helper (rather than reusing
  /// [SavedGameOutcome] directly) because it also needs to cover
  /// resignation/draw-by-agreement, which [SavedGameOutcome] doesn't:
  /// those are [GameProvider]-level UI overrides, not one of
  /// [GameStatus]'s five game-over states.
  GameOverOutcome _outcomeForDisplay(GameProvider game) {
    final bool vsAi = game.aiColor != null;
    if (!vsAi) return GameOverOutcome.neutral;

    final PieceColor perspective =
        game.aiColor == PieceColor.white ? PieceColor.black : PieceColor.white;

    final String? override = game.gameOverOverrideMessage;
    if (override != null) {
      if (override.startsWith('Draw')) return GameOverOutcome.draw;
      final bool whiteWon = override.startsWith('White');
      final bool perspectiveIsWhite = perspective == PieceColor.white;
      return whiteWon == perspectiveIsWhite ? GameOverOutcome.win : GameOverOutcome.loss;
    }

    return switch (game.status) {
      GameStatus.checkmate =>
        game.sideToMove == perspective ? GameOverOutcome.loss : GameOverOutcome.win,
      GameStatus.stalemate ||
      GameStatus.drawFiftyMoveRule ||
      GameStatus.drawInsufficientMaterial ||
      GameStatus.drawThreefoldRepetition =>
        GameOverOutcome.draw,
      _ => GameOverOutcome.neutral,
    };
  }

  /// Phase 11: "Sound design pass … game-start/end sounds" and haptic
  /// feedback on the result, gated by the player's actual settings (not
  /// the [ChessBoard]-level per-move feedback, which only covers moves
  /// while the game is still ongoing).
  void _playGameEndFeedbackOnce(GameProvider game) {
    if (_gameOverFeedbackPlayed) return;
    _gameOverFeedbackPlayed = true;
    final settings = context.read<SettingsProvider>().settings;
    final GameOverOutcome outcome = _outcomeForDisplay(game);
    GameFeedbackService.playGameEnd(
      soundEnabled: settings.soundEnabled,
      hapticsEnabled: settings.hapticsEnabled,
      won: outcome == GameOverOutcome.win,
      drawn: outcome == GameOverOutcome.draw,
    );
  }

  void _showGameOverDialogIfNeeded(GameProvider game) {
    if (!game.isGameOver) return;
    _saveFinishedGameOnce(game);
    _playGameEndFeedbackOnce(game);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => GameOverDialog(
          headline: game.gameOverOverrideMessage ?? _statusHeadline(game.status, game.sideToMove),
          outcome: _outcomeForDisplay(game),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.query_stats),
              label: const Text('Review'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AnalysisBoardScreen(initialMoves: game.moveHistory),
                  ),
                );
              },
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startNewGame();
              },
              child: const Text('New game'),
            ),
          ],
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
        // Phase 11: the player's actual sound/haptics preference,
        // wired through to the board that fires the feedback per move.
        final settings = context.watch<SettingsProvider>().settings;

        final Widget board = Padding(
          padding: EdgeInsets.all(12.w),
          // A soft "floating card" frame around the board — rounded
          // corners + shadow — instead of the board sitting flush
          // against the scaffold background, so it reads as the
          // centerpiece of the screen rather than a flat grid.
          child: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ChessBoard(
                game: game,
                theme: _theme,
                flipped: _flipped,
                interactive: !game.isAiThinking && !game.isGameOver,
                soundEnabled: settings.soundEnabled,
                hapticsEnabled: settings.hapticsEnabled,
              ),
            ),
          ),
        );

        final Widget sidePanel = _SidePanel(game: game);

        return Scaffold(
          appBar: AppBar(
            title: game.isAiThinking ? const _ThinkingTitle() : Text(_appBarTitle(game)),
            actions: [
              HintButton(game: game),
              IconButton(
                icon: const Icon(Icons.palette_outlined),
                tooltip: 'Board theme',
                onPressed: () => _pickTheme(context),
              ),
            ],
          ),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.heroGradient,
              ),
            ),
            child: SafeArea(
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

/// Replaces the plain "AI is thinking…" text in the app bar with an
/// animated three-dot indicator next to the label — a small but
/// noticeable cue that something is actively happening rather than the
/// title just being a static string.
class _ThinkingTitle extends StatefulWidget {
  const _ThinkingTitle();

  @override
  State<_ThinkingTitle> createState() => _ThinkingTitleState();
}

class _ThinkingTitleState extends State<_ThinkingTitle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('AI is thinking'),
        SizedBox(width: 4.w),
        SizedBox(
          width: 20,
          height: 14,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (i) {
                  final double phase = (_controller.value - i * 0.2) % 1.0;
                  final double bounce = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
                  return Transform.translate(
                    offset: Offset(0, -bounce * 4),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
