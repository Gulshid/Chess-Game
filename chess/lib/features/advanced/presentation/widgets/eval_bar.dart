import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A vertical White/Black fill bar plus a numeric readout, the standard
/// way analysis tools show "who's better and by how much" at a glance.
///
/// [centipawns] is White-relative (positive = White better), matching
/// `EvalService`'s convention. A very large magnitude (>= 900000, see
/// `EvalService._mateScore`) is displayed as a forced-mate count instead
/// of a raw score, since "+998234 centipawns" means nothing to a player
/// but "M4" does.
class EvalBar extends StatelessWidget {
  const EvalBar({
    super.key,
    required this.centipawns,
    required this.isLoading,
    this.height = 260,
  });

  final int? centipawns;
  final bool isLoading;
  final double height;

  static const int _mateThreshold = 900000;

  @override
  Widget build(BuildContext context) {
    final int cp = centipawns ?? 0;
    final bool isMate = cp.abs() >= _mateThreshold;

    // Clamp to a +-8 pawn visual range so the bar stays readable; beyond
    // that (or on a forced mate) it simply pins to full.
    final double clamped = (cp / 800).clamp(-1.0, 1.0);
    final double whiteFraction = (clamped + 1) / 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28.w,
          height: height.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.r),
            color: Colors.black87,
            border: Border.all(color: Colors.white24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                flex: (((1 - whiteFraction) * 1000).round()).clamp(1, 999),
                child: Container(color: Colors.black87),
              ),
              Expanded(
                flex: ((whiteFraction * 1000).round()).clamp(1, 999),
                child: Container(color: Colors.white),
              ),
            ],
          ),
        ),
        SizedBox(height: 6.h),
        if (isLoading)
          SizedBox(
            width: 12.w,
            height: 12.w,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Text(
            isMate
                ? (cp > 0 ? 'M' : '-M')
                : '${cp > 0 ? '+' : ''}${(cp / 100).toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
      ],
    );
  }
}
