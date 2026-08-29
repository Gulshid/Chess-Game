import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../core/constant/app_colors.dart';
import '../core/constant/app_constants.dart';
import '../providers/game_provider.dart';

/// Temporary landing screen — replaced by the real board UI in Phase 5.
///
/// Right now its only job is to (a) prove `GameProvider` + the engine work
/// end-to-end through `Consumer`, and (b) demonstrate the ScreenUtil unit
/// conventions (`.sp` for text, `.w`/`.h` for spacing/sizing, `.r` for
/// radii) so the pattern is already established before the board widget
/// tree gets built on top of it.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppConstants.appName)),
      body: Center(
        child: Consumer<GameProvider>(
          builder: (context, game, _) {
            return Container(
              padding: EdgeInsets.all(20.w),
              margin: EdgeInsets.symmetric(horizontal: 24.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.seed.withValues(alpha: 0.4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Engine loaded via GameProvider',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Legal moves for White at start: ${game.legalMoves.length}\n'
                    '(expected: 20)',
                    style: TextStyle(fontSize: 13.sp),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'FEN: ${game.fen}',
                    style: TextStyle(fontSize: 11.sp, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20.h),
                  ElevatedButton(
                    onPressed: game.reset,
                    child: Text('Reset game', style: TextStyle(fontSize: 14.sp)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
