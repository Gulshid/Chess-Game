import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A single player's clock readout — "chess clocks (blitz, rapid,
/// classical time controls) with increment support" (Phase 7).
///
/// Turns red under 10 seconds, the conventional low-time warning every
/// clock UI (physical or digital) uses.
class ChessClock extends StatelessWidget {
  const ChessClock({
    super.key,
    required this.remainingMs,
    required this.isActive,
    required this.label,
  });

  final int remainingMs;
  final bool isActive;
  final String label;

  @override
  Widget build(BuildContext context) {
    final int totalSeconds = (remainingMs / 1000).ceil().clamp(0, 999999);
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final bool isLow = totalSeconds <= 10;

    final String text = '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isActive ? Colors.white10 : Colors.transparent,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: isActive ? Colors.white38 : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10.sp, color: Colors.white54)),
          Text(
            text,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isLow ? const Color(0xFFE53935) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
