import 'package:chess/features/chess_engine/domain/chess_engine.dart';
import 'package:chess/features/chess_engine/domain/models/board_state.dart';
import 'package:chess/features/chess_engine/domain/models/move.dart';
import 'package:chess/features/chess_engine/domain/san.dart';
import 'package:test/test.dart';

void main() {
  group('San.forMove', () {
    test('simple pawn push has no piece letter', () {
      final engine = ChessEngine.initial();
      final move = engine.allLegalMoves.firstWhere((m) => m.uci == 'e2e4');
      expect(San.forMove(engine.state, move), 'e4');
    });

    test('pawn capture includes origin file and x', () {
      // 1. e4 d5 2. exd5 -- exd5 is a pawn capture.
      final engine = ChessEngine.initial();
      engine.makeMove(engine.allLegalMoves.firstWhere((m) => m.uci == 'e2e4'));
      engine.makeMove(engine.allLegalMoves.firstWhere((m) => m.uci == 'd7d5'));
      final move = engine.allLegalMoves.firstWhere((m) => m.uci == 'e4d5');
      expect(San.forMove(engine.state, move), 'exd5');
    });

    test('knight development move uses piece letter, no disambiguation needed', () {
      final engine = ChessEngine.initial();
      final move = engine.allLegalMoves.firstWhere((m) => m.uci == 'g1f3');
      expect(San.forMove(engine.state, move), 'Nf3');
    });

    test('disambiguates by file when two rooks can reach the same square', () {
      // Rooks on a4 and h4, both able to reach d4 along the open 4th rank.
      final engine = ChessEngine.fromFen('4k3/8/8/8/R6R/8/8/4K3 w - - 0 1');
      final move = engine.allLegalMoves.firstWhere((m) => m.uci == 'a4d4');
      expect(San.forMove(engine.state, move), 'Rad4');
    });

    test('disambiguates by rank when files match but ranks differ', () {
      // Rooks on a1 and a8 (white controls both somehow via promotion setup)
      // both able to reach a4 — needs rank disambiguation.
      final engine = ChessEngine.fromFen('R3k3/8/8/8/8/8/8/R3K3 w - - 0 1');
      final move = engine.allLegalMoves.firstWhere((m) => m.uci == 'a1a4');
      expect(San.forMove(engine.state, move), 'R1a4');
    });

    test('king-side castling is O-O', () {
      final engine = ChessEngine.fromFen('4k3/8/8/8/8/8/8/4K2R w K - 0 1');
      final move = engine.allLegalMoves.firstWhere((m) => m.uci == 'e1g1');
      expect(San.forMove(engine.state, move), 'O-O');
    });

    test('queen-side castling is O-O-O', () {
      final engine = ChessEngine.fromFen('4k3/8/8/8/8/8/8/R3K3 w Q - 0 1');
      final move = engine.allLegalMoves.firstWhere((m) => m.uci == 'e1c1');
      expect(San.forMove(engine.state, move), 'O-O-O');
    });

    test('promotion appends =Q', () {
      final engine = ChessEngine.fromFen('8/P3k3/8/8/8/8/8/4K3 w - - 0 1');
      final move = engine.allLegalMoves.firstWhere(
        (m) => m.uci == 'a7a8q',
      );
      expect(San.forMove(engine.state, move), 'a8=Q');
    });

    test('capturing promotion combines x and =Q and appends + when it checks', () {
      // White pawn b7 captures the a8 rook and promotes with check along
      // the 8th rank to the black king on e8.
      final engine = ChessEngine.fromFen('r3k3/1P6/8/8/8/8/8/7K w - - 0 1');
      final move = engine.allLegalMoves.firstWhere((m) => m.uci == 'b7a8q');
      expect(San.forMove(engine.state, move), 'bxa8=Q+');
    });

    test("fool's mate final move is annotated with #", () {
      final engine = ChessEngine.initial();
      Move findByUci(String uci) => engine.allLegalMoves.firstWhere((m) => m.uci == uci);

      engine.makeMove(findByUci('f2f3'));
      engine.makeMove(findByUci('e7e5'));
      engine.makeMove(findByUci('g2g4'));

      final BoardState beforeMate = engine.state;
      final Move mateMove = engine.allLegalMoves.firstWhere((m) => m.uci == 'd8h4');
      expect(San.forMove(beforeMate, mateMove), 'Qh4#');
    });
  });

  group('ChessEngine SAN history integration', () {
    test('sanHistory accumulates in order and matches moveHistory length', () {
      final engine = ChessEngine.initial();
      Move findByUci(String uci) => engine.allLegalMoves.firstWhere((m) => m.uci == uci);

      engine.makeMove(findByUci('e2e4'));
      engine.makeMove(findByUci('e7e5'));
      engine.makeMove(findByUci('g1f3'));

      expect(engine.sanHistory, <String>['e4', 'e5', 'Nf3']);
      expect(engine.moveHistory.length, 3);
      expect(engine.lastMove!.uci, 'g1f3');
    });
  });
}
