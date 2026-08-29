import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  return showDialog<PieceType>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: Text('Promote pawn to', style: TextStyle(fontSize: 16.sp)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final PieceType type in choices)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12.r),
                  onTap: () => Navigator.of(context).pop(type),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: ChessPieceWidget(
                      piece: Piece(color, type),
                      size: 40.w,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
