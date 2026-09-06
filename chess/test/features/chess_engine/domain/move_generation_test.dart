import 'package:chess/features/chess_engine/domain/board_utils.dart';
import 'package:chess/features/chess_engine/domain/chess_engine.dart';
import 'package:chess/features/chess_engine/domain/models/move.dart';
import 'package:chess/features/chess_engine/domain/models/piece.dart';
import 'package:chess/features/chess_engine/domain/move_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 10 / Phase 2: "Exhaustive tests on the chess engine: move
/// generation, perft validation, check/checkmate/stalemate detection,
/// FEN/PGN round-trips." This file covers plain move generation for
/// each piece type; see `perft_test.dart`, `special_moves_test.dart`,
/// and `game_status_test.dart` for the rest.
void main() {
  group('starting position', () {
    test('white has exactly 20 legal moves', () {
      final engine = ChessEngine.initial();
      expect(engine.allLegalMoves.length, 20);
    });

    test('every pawn has a single- and double-push move available', () {
      final engine = ChessEngine.initial();
      for (int file = 0; file < 8; file++) {
        final int from = squareAt(file, 1); // rank 2
        final List<Move> moves = engine.legalMovesFrom(from);
        expect(moves.map((m) => m.to), containsAll(<int>[
          squareAt(file, 2),
          squareAt(file, 3),
        ]));
      }
    });

    test('knights can only hop over the pawn wall to two squares each', () {
      final engine = ChessEngine.initial();
      final List<Move> b1Knight = engine.legalMovesFrom(algebraicToSquare('b1'));
      expect(
        b1Knight.map((m) => squareToAlgebraic(m.to)).toSet(),
        <String>{'a3', 'c3'},
      );
    });

    test('bishops, rooks, and the queen have no legal moves (blocked by pawns)', () {
      final engine = ChessEngine.initial();
      for (final String square in <String>['c1', 'f1', 'a1', 'h1', 'd1']) {
        expect(engine.legalMovesFrom(algebraicToSquare(square)), isEmpty,
            reason: '$square should be blocked at the start');
      }
    });

    test('the king has no legal moves at the start', () {
      final engine = ChessEngine.initial();
      expect(engine.legalMovesFrom(algebraicToSquare('e1')), isEmpty);
    });
  });

  group('captures', () {
    test('a pawn can capture diagonally but not push through a blocker', () {
      // 1. e4 d5 — white pawn on e4 can capture on d5.
      final engine = ChessEngine.fromFen(
        'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2',
      );
      final List<Move> fromE4 = engine.legalMovesFrom(algebraicToSquare('e4'));
      expect(fromE4.map((m) => squareToAlgebraic(m.to)), contains('d5'));
    });

    test('a rook slides until it hits the first piece, capturing an enemy', () {
      final engine = ChessEngine.fromFen('4k3/8/8/8/r7/8/8/R3K3 w Q - 0 1');
      final List<Move> rookMoves = engine.legalMovesFrom(algebraicToSquare('a1'));
      final Set<String> destinations = rookMoves.map((m) => squareToAlgebraic(m.to)).toSet();
      // Slides up the a-file and captures the black rook on a4 (stopping
      // there), and along rank 1 up to (but not onto) its own king on e1.
      expect(destinations, <String>{'a2', 'a3', 'a4', 'b1', 'c1', 'd1'});
    });

    test('a bishop cannot capture its own color', () {
      final engine = ChessEngine.initial();
      // c1 bishop is blocked by its own pawn on d2/b2 at the start.
      expect(engine.legalMovesFrom(algebraicToSquare('c1')), isEmpty);
    });
  });

  group('pins and check evasion', () {
    test('a pinned piece cannot move if doing so exposes the king', () {
      // White king e1, white bishop e2 pinned by black rook on e8.
      final engine = ChessEngine.fromFen('4r3/8/8/8/8/8/4B3/4K3 w - - 0 1');
      final List<Move> bishopMoves = engine.legalMovesFrom(algebraicToSquare('e2'));
      expect(bishopMoves, isEmpty, reason: 'bishop is pinned along the e-file');
    });

    test('in check, only moves that resolve the check are legal', () {
      // Black rook checks white king along the e-file; only the king
      // stepping off the file, or blocking with a piece on e-file, works.
      final engine = ChessEngine.fromFen('4r3/8/8/8/8/8/8/4K3 w - - 0 1');
      final List<Move> allMoves = engine.allLegalMoves;
      for (final Move m in allMoves) {
        final after = engine.state.applyMove(m);
        expect(
          MoveGenerator.isKingInCheck(after, PieceColor.white),
          isFalse,
          reason: '${m.uci} should resolve check',
        );
      }
      expect(allMoves, isNotEmpty);
    });
  });
}
