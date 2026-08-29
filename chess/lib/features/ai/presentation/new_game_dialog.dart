import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../chess_engine/domain/models/piece.dart';
import '../domain/ai_difficulty.dart';

/// Result of the "new game" dialog: either local pass-and-play
/// ([aiPlaysAs] null) or a game against the AI as the given color and
/// difficulty.
class NewGameSelection {
  const NewGameSelection({this.aiPlaysAs, this.difficulty = AiDifficulty.medium});
  final PieceColor? aiPlaysAs;
  final AiDifficulty difficulty;
}

/// Lets the player choose local two-player, or an AI opponent (which
/// side it plays, and how strong) before starting a new game.
Future<NewGameSelection?> showNewGameDialog(BuildContext context) {
  return showDialog<NewGameSelection>(
    context: context,
    builder: (context) => const _NewGameDialog(),
  );
}

class _NewGameDialog extends StatefulWidget {
  const _NewGameDialog();

  @override
  State<_NewGameDialog> createState() => _NewGameDialogState();
}

class _NewGameDialogState extends State<_NewGameDialog> {
  bool _vsAi = true;
  PieceColor _humanColor = PieceColor.white;
  AiDifficulty _difficulty = AiDifficulty.medium;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('New game', style: TextStyle(fontSize: 18.sp)),
      content: SizedBox(
        width: 300.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Vs AI')),
                ButtonSegment(value: false, label: Text('2 Players')),
              ],
              selected: {_vsAi},
              onSelectionChanged: (s) => setState(() => _vsAi = s.first),
            ),
            if (_vsAi) ...[
              SizedBox(height: 16.h),
              Text('Play as', style: TextStyle(fontSize: 13.sp, color: Colors.white70)),
              SizedBox(height: 6.h),
              SegmentedButton<PieceColor>(
                segments: const [
                  ButtonSegment(value: PieceColor.white, label: Text('White')),
                  ButtonSegment(value: PieceColor.black, label: Text('Black')),
                ],
                selected: {_humanColor},
                onSelectionChanged: (s) => setState(() => _humanColor = s.first),
              ),
              SizedBox(height: 16.h),
              Text('Difficulty', style: TextStyle(fontSize: 13.sp, color: Colors.white70)),
              SizedBox(height: 6.h),
              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: [
                  for (final AiDifficulty d in AiDifficulty.values)
                    ChoiceChip(
                      label: Text(d.label),
                      selected: _difficulty == d,
                      onSelected: (_) => setState(() => _difficulty = d),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              NewGameSelection(
                aiPlaysAs: _vsAi ? _humanColor.opposite : null,
                difficulty: _difficulty,
              ),
            );
          },
          child: const Text('Start'),
        ),
      ],
    );
  }
}
