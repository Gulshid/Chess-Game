import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../account/presentation/auth_provider.dart';
import '../../board_ui/domain/board_theme.dart';
import '../../board_ui/presentation/widgets/chess_board.dart';
import '../../chess_engine/domain/models/piece.dart';
import '../../../providers/game_provider.dart';
import '../domain/puzzle.dart';
import '../domain/puzzle_bank.dart';
import 'puzzle_provider.dart';

/// Puzzle-solving screen for a single [Puzzle] — used for both "puzzle
/// of the day" and browsing the practice set.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, required this.puzzle});

  final Puzzle puzzle;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  late PuzzleProvider _puzzleProvider = PuzzleProvider(widget.puzzle);

  // Phase 9: "Puzzle rating system (simplified Elo-style) to track
  // player improvement" (Phase 8) gets wired up to real persistence
  // here — `_attemptRecorded` guards recording the same solved/failed
  // outcome twice across rebuilds (mirroring `OnlineGameScreen`'s
  // `_resultRecorded`), and is reset whenever the puzzle itself resets
  // (retry or move to the next one) so a genuinely new attempt counts.
  bool _attemptRecorded = false;

  void _recordAttemptOnce(PuzzleStatus status) {
    if (_attemptRecorded || status == PuzzleStatus.inProgress) return;
    _attemptRecorded = true;
    context.read<AuthProvider>().recordPuzzleAttempt(
          solved: status == PuzzleStatus.solved,
          puzzleRating: _puzzleProvider.puzzle.rating,
        );
  }

  void _nextPuzzle() {
    final List<Puzzle> all = PuzzleBank.all;
    final int currentIndex = all.indexWhere((p) => p.id == _puzzleProvider.puzzle.id);
    final Puzzle next = all[(currentIndex + 1) % all.length];
    setState(() {
      _puzzleProvider.dispose();
      _puzzleProvider = PuzzleProvider(next);
      _attemptRecorded = false;
    });
  }

  @override
  void dispose() {
    _puzzleProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GameProvider>.value(value: _puzzleProvider),
      ],
      child: AnimatedBuilder(
        animation: _puzzleProvider,
        builder: (context, _) {
          final PuzzleStatus status = _puzzleProvider.puzzleStatus;
          final Puzzle puzzle = _puzzleProvider.puzzle;
          _recordAttemptOnce(status);

          return Scaffold(
            appBar: AppBar(
              title: Text('Puzzle · rating ${puzzle.rating}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.lightbulb_outline),
                  tooltip: 'Hint',
                  onPressed: _puzzleProvider.requestHint,
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 8.h),
                  _StatusBanner(status: status, playerColor: _puzzleProvider.playerColor),
                  SizedBox(height: 8.h),
                  Expanded(
                    child: Center(
                      child: ChessBoard(
                        game: _puzzleProvider,
                        theme: BoardTheme.classicGreen,
                        flipped: _puzzleProvider.playerColor == PieceColor.black,
                        interactive: status == PuzzleStatus.inProgress,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _puzzleProvider.resetPuzzle();
                              setState(() => _attemptRecorded = false);
                            },
                            child: const Text('Try again'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: FilledButton(
                            onPressed: _nextPuzzle,
                            child: const Text('Next puzzle'),
                          ),
                        ),
                      ],
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.playerColor});

  final PuzzleStatus status;
  final PieceColor playerColor;

  @override
  Widget build(BuildContext context) {
    final String sideLabel = playerColor == PieceColor.white ? 'White' : 'Black';
    final (String text, Color color) = switch (status) {
      PuzzleStatus.inProgress => ('$sideLabel to move — find the winning move', Colors.white70),
      PuzzleStatus.solved => ('Solved! 🎉', const Color(0xFF00C853)),
      PuzzleStatus.failed => ('Not quite — try again', const Color(0xFFE53935)),
    };
    return Text(text, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: color));
  }
}