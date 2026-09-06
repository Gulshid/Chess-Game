import 'package:chess/features/board_ui/presentation/widgets/chess_board.dart';
import 'package:chess/features/chess_engine/domain/board_utils.dart';
import 'package:chess/providers/game_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/test_app.dart';

/// Computes the on-screen center of [square] for a [ChessBoard] found at
/// [boardTopLeft] with the given [squareSize] — mirrors
/// `_ChessBoardState._cellForSquare`'s own col/row math exactly (see
/// that method's doc) so taps land on the right square regardless of
/// [flipped].
Offset _centerOfSquare(
  int square, {
  required Offset boardTopLeft,
  required double squareSize,
  bool flipped = false,
}) {
  final int file = fileOf(square);
  final int rank = rankOf(square);
  final double col = (flipped ? 7 - file : file).toDouble();
  final double row = (flipped ? rank : 7 - rank).toDouble();
  return boardTopLeft + Offset((col + 0.5) * squareSize, (row + 0.5) * squareSize);
}

void main() {
  testWidgets('renders all 32 starting pieces', (tester) async {
    final game = GameProvider();
    await pumpForTest(tester, SizedBox(width: 320, height: 320, child: ChessBoard(game: game)));

    // Each piece is rendered as its own AnimatedPositioned wrapping a
    // Unicode-glyph piece widget (see `chess_piece_widget.dart` — this
    // app has no piece image assets) — count those directly.
    expect(find.byType(ChessBoard), findsOneWidget);
    final int pieceCount =
        tester.widgetList<AnimatedPositioned>(find.byType(AnimatedPositioned)).length;
    expect(pieceCount, 32);
  });

  testWidgets('selecting a pawn highlights its legal destinations', (tester) async {
    final game = GameProvider();
    await pumpForTest(tester, SizedBox(width: 320, height: 320, child: ChessBoard(game: game)));

    expect(game.movesFromSelected, isEmpty);
    game.selectSquare(algebraicToSquare('e2'));
    await tester.pump();

    expect(game.selectedSquare, algebraicToSquare('e2'));
    expect(game.movesFromSelected, hasLength(2)); // e3 (push) and e4 (double push)
  });

  testWidgets('tapping a pawn then its destination plays the move', (tester) async {
    final game = GameProvider();
    await pumpForTest(tester, SizedBox(width: 320, height: 320, child: ChessBoard(game: game)));

    final Offset boardTopLeft = tester.getTopLeft(find.byType(ChessBoard));
    final Size boardSize = tester.getSize(find.byType(ChessBoard));
    final double squareSize = boardSize.width / 8;

    await tester.tapAt(_centerOfSquare(algebraicToSquare('e2'),
        boardTopLeft: boardTopLeft, squareSize: squareSize));
    await tester.pump();
    expect(game.selectedSquare, algebraicToSquare('e2'));

    await tester.tapAt(_centerOfSquare(algebraicToSquare('e4'),
        boardTopLeft: boardTopLeft, squareSize: squareSize));
    await tester.pump();

    expect(game.sanHistory, <String>['e4']);
    expect(game.selectedSquare, isNull);
  });

  testWidgets('tapping is ignored while interactive is false', (tester) async {
    final game = GameProvider();
    await pumpForTest(
      tester,
      SizedBox(width: 320, height: 320, child: ChessBoard(game: game, interactive: false)),
    );

    final Offset boardTopLeft = tester.getTopLeft(find.byType(ChessBoard));
    final Size boardSize = tester.getSize(find.byType(ChessBoard));
    final double squareSize = boardSize.width / 8;

    await tester.tapAt(_centerOfSquare(algebraicToSquare('e2'),
        boardTopLeft: boardTopLeft, squareSize: squareSize));
    await tester.pump();

    expect(game.selectedSquare, isNull,
        reason: 'a non-interactive board (e.g. while the AI is thinking) must not accept taps');
  });

  testWidgets('flipping the board mirrors tap coordinates correctly', (tester) async {
    final game = GameProvider();
    await pumpForTest(
      tester,
      SizedBox(width: 320, height: 320, child: ChessBoard(game: game, flipped: true)),
    );

    final Offset boardTopLeft = tester.getTopLeft(find.byType(ChessBoard));
    final Size boardSize = tester.getSize(find.byType(ChessBoard));
    final double squareSize = boardSize.width / 8;

    await tester.tapAt(_centerOfSquare(algebraicToSquare('e2'),
        boardTopLeft: boardTopLeft, squareSize: squareSize, flipped: true));
    await tester.pump();

    expect(game.selectedSquare, algebraicToSquare('e2'),
        reason: 'tapping the on-screen location of e2 on a flipped board must still select e2');
  });
}
