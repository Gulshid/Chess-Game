import 'package:chess/core/constant/app_constants.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/chess_engine/domain/chess_engine.dart';

/// Phase 1 entry point.
///
/// This does not render a chess board yet — that's Phase 5. Its only job
/// right now is to prove the project compiles and to sanity-check the
/// Phase 2 engine by printing the legal move count for the starting
/// position and the resulting FEN after one move.
void main() {
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _EngineSmokeTestScreen(),
    );
  }
}

/// Temporary Phase 1/2 screen. Replaced by the real board UI in Phase 5.
class _EngineSmokeTestScreen extends StatelessWidget {
  const _EngineSmokeTestScreen();

  @override
  Widget build(BuildContext context) {
    final engine = ChessEngine.initial();
    final legalMoveCount = engine.allLegalMoves.length;

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Engine loaded.\n'
              'Legal moves for White at start: $legalMoveCount\n'
              '(expected: 20)',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text('FEN: ${engine.fen}'),
          ],
        ),
      ),
    );
  }
}
