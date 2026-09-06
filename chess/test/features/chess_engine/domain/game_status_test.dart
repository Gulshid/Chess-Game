import 'package:chess/features/chess_engine/domain/board_utils.dart';
import 'package:chess/features/chess_engine/domain/chess_engine.dart';
import 'package:chess/features/chess_engine/domain/game_status.dart';
import 'package:chess/features/chess_engine/domain/models/move.dart';
import 'package:chess/features/chess_engine/domain/models/piece.dart';
import 'package:flutter_test/flutter_test.dart';

Move _findMove(List<Move> moves, String toSquare) =>
    moves.firstWhere((m) => squareToAlgebraic(m.to) == toSquare);

void main() {
  group('checkmate', () {
    test('classic back-rank mate is detected', () {
      // Black king trapped on g8 by its own pawns; white rook delivers
      // mate along the 8th rank.
      final engine = ChessEngine.fromFen('6k1/5ppp/8/8/8/8/8/R6K w - - 0 1');
      final Move mate = _findMove(engine.legalMovesFrom(algebraicToSquare('a1')), 'a8');
      engine.makeMove(mate);

      expect(engine.status, GameStatus.checkmate);
      expect(engine.allLegalMoves, isEmpty);
      expect(engine.isInCheck, isTrue);
    });

    test("fool's mate (fastest possible checkmate) is detected", () {
      final engine = ChessEngine.initial();
      final List<List<String>> plies = <List<String>>[
        <String>['f2', 'f3'],
        <String>['e7', 'e5'],
        <String>['g2', 'g4'],
        <String>['d8', 'h4'],
      ];
      for (final List<String> ply in plies) {
        final Move move =
            _findMove(engine.legalMovesFrom(algebraicToSquare(ply[0])), ply[1]);
        final bool applied = engine.makeMove(move);
        expect(applied, isTrue, reason: '${ply[0]}${ply[1]} should be legal');
      }

      expect(engine.status, GameStatus.checkmate);
      expect(engine.sideToMove, PieceColor.white);
    });
  });

  group('stalemate', () {
    test('a king with no legal moves and not in check is stalemate, not checkmate', () {
      // Classic "how to blunder a win" stalemate trap: black king a8 is
      // not in check, but every one of its flight squares (a7, b7, b8)
      // is covered by the white queen/king, and it can't reach the
      // queen to capture it.
      final engine = ChessEngine.fromFen('k7/8/1QK5/8/8/8/8/8 b - - 0 1');
      expect(engine.isInCheck, isFalse);
      expect(engine.allLegalMoves, isEmpty);
      expect(engine.status, GameStatus.stalemate);
    });
  });

  group('draw rules', () {
    test('the fifty-move rule triggers at 100 halfmoves without a pawn move or capture', () {
      final engine = ChessEngine.fromFen('7k/8/8/8/8/8/8/K6R w - - 99 50');
      final Move quiet = _findMove(engine.legalMovesFrom(algebraicToSquare('h1')), 'h2');
      engine.makeMove(quiet);
      expect(engine.state.halfmoveClock, 100);
      expect(engine.status, GameStatus.drawFiftyMoveRule);
    });

    test('a pawn move resets the fifty-move counter', () {
      final engine = ChessEngine.fromFen('7k/8/8/8/8/8/P7/K6R w - - 99 50');
      final Move pawnPush = _findMove(engine.legalMovesFrom(algebraicToSquare('a2')), 'a3');
      engine.makeMove(pawnPush);
      expect(engine.state.halfmoveClock, 0);
      expect(engine.status, isNot(GameStatus.drawFiftyMoveRule));
    });

    test('threefold repetition is detected when the same position recurs three times', () {
      // Rook shuffles e1<->e2, king shuffles h8<->g8 — deliberately not
      // sharing a file/rank with the rook's resting squares (an earlier
      // version of this test used h1/h8, which share the h-file: once
      // the rook came home to h1 it attacked h8 along that file, making
      // the king's own "return home" move illegal and the test's move
      // list empty instead of testing repetition at all).
      final engine = ChessEngine.fromFen('7k/8/8/8/8/8/8/K3R3 w - - 0 1');
      // Two laps (8 plies) of shuffling back and forth already gets the
      // starting position back onto the board for the 3rd time
      // (occurrences at ply 0, 4, and 8) — a 3rd lap would try to make
      // more moves on a game the engine already considers over, which
      // correctly returns no legal moves and would make `_findMove`
      // throw.
      for (int lap = 0; lap < 2; lap++) {
        engine.makeMove(_findMove(engine.legalMovesFrom(algebraicToSquare('e1')), 'e2'));
        engine.makeMove(_findMove(engine.legalMovesFrom(algebraicToSquare('h8')), 'g8'));
        engine.makeMove(_findMove(engine.legalMovesFrom(algebraicToSquare('e2')), 'e1'));
        engine.makeMove(_findMove(engine.legalMovesFrom(algebraicToSquare('g8')), 'h8'));
      }
      expect(engine.status, GameStatus.drawThreefoldRepetition);
    });

    group('insufficient material', () {
      test('king vs king is a draw', () {
        final engine = ChessEngine.fromFen('7k/8/8/8/8/8/8/7K w - - 0 1');
        expect(engine.status, GameStatus.drawInsufficientMaterial);
      });

      test('king + bishop vs king is a draw', () {
        final engine = ChessEngine.fromFen('7k/8/8/8/8/8/8/B6K w - - 0 1');
        expect(engine.status, GameStatus.drawInsufficientMaterial);
      });

      test('king + knight vs king is a draw', () {
        final engine = ChessEngine.fromFen('7k/8/8/8/8/8/8/N6K w - - 0 1');
        expect(engine.status, GameStatus.drawInsufficientMaterial);
      });

      test('king + rook vs king is NOT a draw (sufficient material)', () {
        final engine = ChessEngine.fromFen('7k/8/8/8/8/8/8/R6K w - - 0 1');
        expect(engine.status, isNot(GameStatus.drawInsufficientMaterial));
      });

      test('bishops on the same-colored squares (one each side) is a draw', () {
        // White bishop on c1, black bishop on f8 — both dark squares
        // ((file+rank) is even for both) — same-colored-square bishops
        // of opposite sides can never checkmate, so this is a draw.
        final engine = ChessEngine.fromFen('5b1k/8/8/8/8/8/8/2B4K w - - 0 1');
        expect(engine.status, GameStatus.drawInsufficientMaterial);
      });

      test('bishops on different-colored squares (one each side) is NOT a draw', () {
        // White bishop on d1 (light square), black bishop on f8 (dark
        // square) — different-colored-square bishops are not flagged
        // as an automatic dead draw by this simplified check (see
        // `ChessEngine._hasInsufficientMaterial`'s class doc).
        final engine = ChessEngine.fromFen('5b1k/8/8/8/8/8/8/3B3K w - - 0 1');
        expect(engine.status, isNot(GameStatus.drawInsufficientMaterial));
      });
    });
  });
}
