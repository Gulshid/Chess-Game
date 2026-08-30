import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../board_ui/domain/board_theme.dart';
import '../../board_ui/presentation/widgets/captured_pieces_tray.dart';
import '../../board_ui/presentation/widgets/chess_board.dart';
import '../../chess_engine/domain/models/move.dart';
import '../../chess_engine/domain/models/piece.dart';
import '../../../providers/game_provider.dart';
import 'analysis_provider.dart';
import 'fen_setup_dialog.dart';
import 'game_review_screen.dart';
import 'pgn_dialog.dart';
import 'widgets/analysis_move_list.dart';
import 'widgets/eval_bar.dart';

/// The Phase 8 analysis board: step through any game (loaded from a
/// finished match or an imported PGN), branch into a different move,
/// see the live evaluation, and open a full game review.
///
/// Provides its own [AnalysisProvider] as `GameProvider` (not a
/// duplicate registration alongside the app's live-game one) so this
/// screen is fully independent of whatever game is (or isn't) in
/// progress on [GameScreen] — pushing this screen never disturbs a
/// game the player is mid-way through elsewhere.
class AnalysisBoardScreen extends StatefulWidget {
  const AnalysisBoardScreen({super.key, this.initialMoves, this.startingFen});

  /// Optionally seed the board with an existing game (e.g. "review this
  /// match" from [GameScreen]'s game-over dialog) rather than starting
  /// from the standard position.
  final List<Move>? initialMoves;
  final String? startingFen;

  @override
  State<AnalysisBoardScreen> createState() => _AnalysisBoardScreenState();
}

class _AnalysisBoardScreenState extends State<AnalysisBoardScreen> {
  late final AnalysisProvider _analysis = AnalysisProvider(startingFen: widget.startingFen);
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMoves != null && widget.initialMoves!.isNotEmpty) {
      _analysis.loadGame(widget.initialMoves!, startingFen: widget.startingFen);
    }
  }

  @override
  void dispose() {
    _analysis.dispose();
    super.dispose();
  }

  Future<void> _openPgnDialog() async {
    final String? imported = await showPgnDialog(context, exportText: _analysis.exportPgn());
    if (imported == null) return;
    try {
      _analysis.loadPgn(imported);
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not read that PGN: ${e.message}')));
    }
  }

  Future<void> _openFenDialog() async {
    final String? fen = await showFenSetupDialog(context, initialFen: _analysis.fen);
    if (fen != null) _analysis.loadFen(fen);
  }

  void _openReview() {
    if (_analysis.moveHistory.isEmpty && !_analysis.canRedo) return;
    // Review the *whole* game regardless of where the browser currently
    // sits: walk to the end first so `moveHistory` is the full line.
    _analysis.jumpToEnd();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameReviewScreen(
          moves: _analysis.moveHistory,
          startingFen: widget.startingFen,
          onOpenInAnalysis: (plyIndex) {
            Navigator.of(context).pop();
            _analysis.jumpToPly(plyIndex);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GameProvider>.value(value: _analysis),
      ],
      child: AnimatedBuilder(
        animation: _analysis,
        builder: (context, _) {
          final bool wide = MediaQuery.of(context).size.width > 720;

          final Widget board = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EvalBar(
                centipawns: _analysis.evalCentipawns,
                isLoading: _analysis.isEvalLoading,
              ),
              SizedBox(width: 8.w),
              Padding(
                padding: EdgeInsets.all(8.w),
                child: ChessBoard(
                  game: _analysis,
                  theme: BoardTheme.classicGreen,
                  flipped: _flipped,
                  interactive: true,
                ),
              ),
            ],
          );

          final Widget sidePanel = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CapturedPiecesTray(color: PieceColor.white),
              SizedBox(height: 4.h),
              CapturedPiecesTray(color: PieceColor.black),
              SizedBox(height: 8.h),
              const Divider(height: 1),
              Expanded(child: AnalysisMoveList(analysis: _analysis)),
              const Divider(height: 1),
              _NavRow(analysis: _analysis),
            ],
          );

          return Scaffold(
            appBar: AppBar(
              title: const Text('Analysis board'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.file_open_outlined),
                  tooltip: 'Set up position (FEN)',
                  onPressed: _openFenDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.description_outlined),
                  tooltip: 'Import / export PGN',
                  onPressed: _openPgnDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.swap_vert),
                  tooltip: 'Flip board',
                  onPressed: () => setState(() => _flipped = !_flipped),
                ),
                IconButton(
                  icon: const Icon(Icons.summarize_outlined),
                  tooltip: 'Game review',
                  onPressed: _openReview,
                ),
              ],
            ),
            body: SafeArea(
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: 3, child: Center(child: board)),
                        SizedBox(width: 320.w, child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: sidePanel,
                        )),
                      ],
                    )
                  : Column(
                      children: [
                        Center(child: board),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            child: sidePanel,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.analysis});

  final AnalysisProvider analysis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            tooltip: 'Start',
            onPressed: analysis.canUndo ? analysis.jumpToStart : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous',
            onPressed: analysis.canUndo ? analysis.undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next',
            onPressed: analysis.canRedo ? analysis.redo : null,
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            tooltip: 'End',
            onPressed: analysis.canRedo ? analysis.jumpToEnd : null,
          ),
        ],
      ),
    );
  }
}
