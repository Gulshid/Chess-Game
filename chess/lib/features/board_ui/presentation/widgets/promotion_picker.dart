import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constant/app_colors.dart';
import '../../../chess_engine/domain/models/piece.dart';
import 'chess_piece_widget.dart';

/// Modal shown when a pawn reaches the last rank and more than one
/// promotion move lands on the same target square (queen/rook/bishop/
/// knight). Returns the chosen [PieceType], or null if dismissed
/// (dismissal is treated as "cancel the move" by the caller).
Future<PieceType?> showPromotionPicker(
  BuildContext context, {
  required PieceColor color,
}) {
  const List<PieceType> choices = <PieceType>[
    PieceType.queen,
    PieceType.rook,
    PieceType.bishop,
    PieceType.knight,
  ];

  return showGeneralDialog<PieceType>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Promote pawn',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final CurvedAnimation curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.85 + 0.15 * curved.value,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Promote pawn to',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final PieceType type in choices)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: _PromotionChoice(color: color, type: type),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PromotionChoice extends StatefulWidget {
  const _PromotionChoice({required this.color, required this.type});

  final PieceColor color;
  final PieceType type;

  @override
  State<_PromotionChoice> createState() => _PromotionChoiceState();
}

class _PromotionChoiceState extends State<_PromotionChoice> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(widget.type),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _hovered
                ? AppColors.gold.withOpacity(0.16)
                : Colors.white.withOpacity(0.05),
            border: Border.all(
              color: _hovered ? AppColors.gold : Colors.white.withOpacity(0.08),
              width: _hovered ? 2 : 1,
            ),
          ),
          child: ChessPieceWidget(piece: Piece(widget.color, widget.type), size: 42.w),
        ),
      ),
    );
  }
}
