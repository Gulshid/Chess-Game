import 'package:chess/features/board_ui/presentation/widgets/chess_piece_widget.dart';
import 'package:chess/features/board_ui/presentation/widgets/promotion_picker.dart';
import 'package:chess/features/chess_engine/domain/models/piece.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/test_app.dart';

Finder _pieceChoice(PieceType type) => find.byWidgetPredicate(
      (widget) => widget is ChessPieceWidget && widget.piece.type == type,
    );

void main() {
  testWidgets('offers all four promotion choices in the requested color', (tester) async {
    await pumpForTest(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showPromotionPicker(context, color: PieceColor.black),
          child: const Text('Promote'),
        ),
      ),
    );

    await tester.tap(find.text('Promote'));
    await tester.pumpAndSettle();

    expect(find.text('Promote pawn to'), findsOneWidget);
    for (final PieceType type in <PieceType>[
      PieceType.queen,
      PieceType.rook,
      PieceType.bishop,
      PieceType.knight,
    ]) {
      final ChessPieceWidget widget = tester.widget<ChessPieceWidget>(_pieceChoice(type));
      expect(widget.piece.color, PieceColor.black);
    }
  });

  testWidgets('tapping a choice resolves the picker with that PieceType', (tester) async {
    PieceType? result;
    await pumpForTest(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showPromotionPicker(context, color: PieceColor.white);
          },
          child: const Text('Promote'),
        ),
      ),
    );

    await tester.tap(find.text('Promote'));
    await tester.pumpAndSettle();

    await tester.tap(_pieceChoice(PieceType.rook));
    await tester.pumpAndSettle();

    expect(result, PieceType.rook);
    expect(find.text('Promote pawn to'), findsNothing, reason: 'the dialog should have closed');
  });

  testWidgets('the barrier cannot be tapped to dismiss without choosing', (tester) async {
    PieceType? result = PieceType.pawn; // sentinel: overwritten only if the future resolves
    bool resolved = false;

    await pumpForTest(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showPromotionPicker(context, color: PieceColor.white);
            resolved = true;
          },
          child: const Text('Promote'),
        ),
      ),
    );

    await tester.tap(find.text('Promote'));
    await tester.pumpAndSettle();

    // Tap far outside the dialog content, where the modal barrier is.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(resolved, isFalse,
        reason: 'promotion is a forced choice — showPromotionPicker is barrierDismissible: false');
    expect(find.text('Promote pawn to'), findsOneWidget);
    expect(result, PieceType.pawn);
  });
}
