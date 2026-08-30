import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../analysis_provider.dart';

/// A tap-to-jump variant of `MoveHistoryPanel` (board_ui, Phase 5) —
/// that widget's own doc explicitly flags random-access jumping as "an
/// Phase 8 analysis board feature", so rather than bolt jump support
/// onto the live-game panel (and risk a mis-tap ending a real game), it
/// lives here as its own small widget scoped to [AnalysisProvider].
class AnalysisMoveList extends StatelessWidget {
  const AnalysisMoveList({super.key, required this.analysis});

  final AnalysisProvider analysis;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: analysis,
      builder: (context, _) {
        final List<String> sans = analysis.sanHistory;
        final int currentPly = sans.length - 1;

        if (sans.isEmpty) {
          return Center(
            child: Text('No moves yet', style: TextStyle(fontSize: 12.sp, color: Colors.white54)),
          );
        }

        final int rowCount = (sans.length + 1) ~/ 2;
        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          itemCount: rowCount,
          itemBuilder: (context, rowIndex) {
            final int whiteIdx = rowIndex * 2;
            final int blackIdx = whiteIdx + 1;
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
                    child: _MoveCell(
                      text: sans[whiteIdx],
                      highlighted: whiteIdx == currentPly,
                      onTap: () => analysis.jumpToPly(whiteIdx),
                    ),
                  ),
                  Expanded(
                    child: blackIdx < sans.length
                        ? _MoveCell(
                            text: sans[blackIdx],
                            highlighted: blackIdx == currentPly,
                            onTap: () => analysis.jumpToPly(blackIdx),
                          )
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

class _MoveCell extends StatelessWidget {
  const _MoveCell({required this.text, required this.highlighted, required this.onTap});

  final String text;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6.r),
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}
