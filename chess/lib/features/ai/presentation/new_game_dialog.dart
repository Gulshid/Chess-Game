import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constant/app_colors.dart';
import '../../board_ui/presentation/widgets/chess_piece_widget.dart';
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
///
/// Redesigned from the original `SegmentedButton`/`ChoiceChip` version:
/// the color choice now shows the actual king artwork instead of just a
/// text label, and difficulty is a horizontal "ladder" of five bars
/// (à la a signal-strength meter) so relative strength reads at a
/// glance instead of needing to compare five text chips.
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New game',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            SizedBox(height: 18.h),
            Row(
              children: [
                Expanded(
                  child: _ModeTile(
                    label: 'Vs AI',
                    icon: Icons.smart_toy_rounded,
                    selected: _vsAi,
                    onTap: () => setState(() => _vsAi = true),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _ModeTile(
                    label: '2 Players',
                    icon: Icons.people_alt_rounded,
                    selected: !_vsAi,
                    onTap: () => setState(() => _vsAi = false),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _vsAi
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.h),
                        Text('Play as',
                            style: TextStyle(fontSize: 13.sp, color: Colors.white60)),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            _ColorTile(
                              color: PieceColor.white,
                              selected: _humanColor == PieceColor.white,
                              onTap: () => setState(() => _humanColor = PieceColor.white),
                            ),
                            SizedBox(width: 12.w),
                            _ColorTile(
                              color: PieceColor.black,
                              selected: _humanColor == PieceColor.black,
                              onTap: () => setState(() => _humanColor = PieceColor.black),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                        Text('Difficulty',
                            style: TextStyle(fontSize: 13.sp, color: Colors.white60)),
                        SizedBox(height: 10.h),
                        _DifficultyLadder(
                          selected: _difficulty,
                          onChanged: (d) => setState(() => _difficulty = d),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: FilledButton(
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? AppColors.seed.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: selected ? AppColors.seed : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.seed : Colors.white60, size: 22),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  const _ColorTile({required this.color, required this.selected, required this.onTap});

  final PieceColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? AppColors.gold.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: selected ? AppColors.gold : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChessPieceWidget(piece: Piece(color, PieceType.king), size: 34.w),
            SizedBox(height: 2.h),
            Text(
              color == PieceColor.white ? 'White' : 'Black',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.gold : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Five-bar "signal strength" style difficulty picker — each bar taller
/// than the last, filled up to and including the selected level, so
/// "Hard" visibly reads as stronger than "Easy" without needing to read
/// every label to compare them.
class _DifficultyLadder extends StatelessWidget {
  const _DifficultyLadder({required this.selected, required this.onChanged});

  final AiDifficulty selected;
  final ValueChanged<AiDifficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<AiDifficulty> all = AiDifficulty.values;
    final int selectedIndex = all.indexOf(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < all.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(all[i]),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2.w),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 14.0 + i * 6.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i <= selectedIndex
                            ? AppColors.gold
                            : Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        Center(
          child: Text(
            selected.label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ),
      ],
    );
  }
}
