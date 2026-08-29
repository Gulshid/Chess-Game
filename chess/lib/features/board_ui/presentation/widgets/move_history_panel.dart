import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../providers/game_provider.dart';

/// Scrollable move-list panel showing SAN notation, paired into rows of
/// (move number, White's move, Black's move) the way score sheets and
/// every serious chess UI display it.
///
/// Jumping to an arbitrary earlier position (rather than just stepping
/// one move at a time) needs random-access history navigation the engine
/// doesn't expose yet — [GameProvider] only offers linear [undo]/[redo].
/// That's flagged as an Phase 8 "analysis board" feature in the roadmap,
/// so this panel is read-only display for now rather than tappable.
class MoveHistoryPanel extends StatelessWidget {
  const MoveHistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        final List<String> sans = game.sanHistory;
        final int rowCount = (sans.length + 1) ~/ 2;

        if (sans.isEmpty) {
          return Center(
            child: Text(
              'No moves yet',
              style: TextStyle(fontSize: 12.sp, color: Colors.white54),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          itemCount: rowCount,
          itemBuilder: (context, rowIndex) {
            final int whiteIdx = rowIndex * 2;
            final int blackIdx = whiteIdx + 1;
            final bool isLastRow = rowIndex == rowCount - 1;
            final bool highlightWhite =
                isLastRow && blackIdx >= sans.length && game.lastMove != null;
            final bool highlightBlack =
                blackIdx == sans.length - 1 && game.lastMove != null;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              child: Row(
                children: [
                  SizedBox(
                    width: 26.w,
                    child: Text(
                      '${rowIndex + 1}.',
                      style: TextStyle(fontSize: 12.sp, color: Colors.white54),
                    ),
                  ),
                  Expanded(
                    child: _SanCell(
                      text: sans[whiteIdx],
                      highlighted: highlightWhite,
                    ),
                  ),
                  Expanded(
                    child: blackIdx < sans.length
                        ? _SanCell(text: sans[blackIdx], highlighted: highlightBlack)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SanCell extends StatelessWidget {
  const _SanCell({required this.text, required this.highlighted});

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: highlighted
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
