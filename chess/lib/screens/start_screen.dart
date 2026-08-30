import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../core/constant/app_colors.dart';
import '../core/constant/app_constants.dart';
import '../features/advanced/domain/puzzle_bank.dart';
import '../features/advanced/presentation/analysis_board_screen.dart';
import '../features/advanced/presentation/puzzle_screen.dart';
import '../features/ai/presentation/new_game_dialog.dart';
import '../features/multiplayer/presentation/matchmaking_screen.dart';
import '../providers/game_provider.dart';
import 'game_screen.dart';

/// The app's landing screen.
///
/// This replaces Phase 1's placeholder, whose only job was proving
/// `GameProvider` + the engine worked end-to-end through `Consumer`
/// before any board UI existed. Now that Phase 5 has a real board, this
/// screen's job is picking how to start a game and handing off to
/// [GameScreen].
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  Future<void> _startLocalGame(BuildContext context) async {
    context.read<GameProvider>().startGameVsAi(aiPlaysAs: null);
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  Future<void> _startAiGame(BuildContext context) async {
    final NewGameSelection? selection = await showNewGameDialog(context);
    if (selection == null || !context.mounted) return;
    context.read<GameProvider>().startGameVsAi(
          aiPlaysAs: selection.aiPlaysAs,
          difficulty: selection.difficulty,
        );
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppConstants.appName)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_4x4_rounded, size: 72.w, color: AppColors.seed),
              SizedBox(height: 16.h),
              Text(
                AppConstants.appName,
                style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              Text(
                'Play a friend on this device, or challenge the AI.',
                style: TextStyle(fontSize: 13.sp, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 36.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: Text('Play vs AI', style: TextStyle(fontSize: 15.sp)),
                  onPressed: () => _startAiGame(context),
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.people_outline),
                  label: Text('Local 2-player', style: TextStyle(fontSize: 15.sp)),
                  onPressed: () => _startLocalGame(context),
                ),
              ),
              SizedBox(height: 24.h),
              const Divider(),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.public),
                  label: Text('Play online', style: TextStyle(fontSize: 15.sp)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MatchmakingScreen()),
                    );
                  },
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.query_stats),
                  label: Text('Analysis board', style: TextStyle(fontSize: 15.sp)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AnalysisBoardScreen()),
                    );
                  },
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.extension_outlined),
                  label: Text('Daily puzzle', style: TextStyle(fontSize: 15.sp)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PuzzleScreen(puzzle: PuzzleBank.daily()),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
