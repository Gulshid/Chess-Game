// These positions specifically target the edge cases Phase 3 of the
// roadmap calls out: pins, double check, and en passant that would
// expose the king to check. As explained in the Phase 3 delivery notes,
// the engine's legality filter (simulate the move, then check whether the
// mover's own king is attacked on the *resulting* board) handles all of
// these correctly by construction — these tests exist to prove that,
// not to introduce new production logic for them.
import 'package:chess/features/chess_engine/domain/chess_engine.dart';
import 'package:chess/features/chess_engine/domain/game_status.dart';
import 'package:chess/features/chess_engine/domain/models/move.dart';
import 'package:test/test.dart';

void main() {
  group('Pins', () {
    test('a pinned rook can only move along the pin line', () {
      // White king e1, white rook e2, black rook e8 — the white rook is
      // pinned along the e-file and must not be able to step sideways.
      final engine = ChessEngine.fromFen('4r3/8/8/8/8/8/4R3/4K3 w - - 0 1');
      final rookMoves = engine.legalMovesFrom(12); // e2

      expect(rookMoves, isNotEmpty);
      for (final move in rookMoves) {
        expect(
          move.to % 8,
          12 % 8,
          reason: 'Pinned rook moved off the e-file to square ${move.to}',
        );
      }
    });
  });

  group('Double check', () {
    test('only king moves are legal when in double check', () {
      // Black king e8 is checked simultaneously by a white knight on d6
      // and a white rook on e1. A black knight on b7 *could* capture the
      // checking knight, but that still leaves the rook check unanswered,
      // so it must NOT appear among the legal moves — only king moves may.
      final engine = ChessEngine.fromFen('4k3/1n6/3N4/8/8/8/8/K3R3 b - - 0 1');

      expect(engine.isInCheck, isTrue);
      final moves = engine.allLegalMoves;
      expect(moves, isNotEmpty);

      const kingSquare = 60; // e8
      for (final move in moves) {
        expect(
          move.from,
          kingSquare,
          reason: 'Non-king move ${move.uci} was allowed while in double check',
        );
      }
      // Specifically confirm the "obvious" but illegal capture is excluded.
      expect(moves.any((m) => m.uci == 'b7d6'), isFalse);
    });
  });

  group('En passant discovered check', () {
    test('en passant capture is illegal if it exposes the king to check', () {
      // White king h5, white pawn e5, black pawn d5 (just double-pushed,
      // so en passant target is d6), black rook a5. Capturing en passant
      // (exd6) removes BOTH the e5 and d5 pawns from the 5th rank at
      // once, opening a clear line from the a5 rook straight to the h5
      // king — so the capture must be excluded from legal moves even
      // though the en passant target square is set.
      final engine = ChessEngine.fromFen('4k3/8/8/r2pP2K/8/8/8/8 w - d6 0 1');

      final pawnMoves = engine.legalMovesFrom(36); // e5
      expect(pawnMoves.any((m) => m.uci == 'e5d6'), isFalse);
    });

    test('the same en passant capture IS legal without the pinning rook', () {
      // Sanity check on the test position itself: remove the rook and
      // the identical en passant capture becomes legal, confirming the
      // previous test failed for the right reason (the rook), not a
      // FEN mistake.
      final engine = ChessEngine.fromFen('4k3/8/8/3pP2K/8/8/8/8 w - d6 0 1');
      final pawnMoves = engine.legalMovesFrom(36); // e5
      expect(pawnMoves.any((m) => m.uci == 'e5d6'), isTrue);
    });
  });

  group('Insufficient material (Phase 3 fix)', () {
    test('K vs K is a draw', () {
      final engine = ChessEngine.fromFen('4k3/8/8/8/8/8/8/4K3 w - - 0 1');
      expect(engine.status, GameStatus.drawInsufficientMaterial);
    });

    test('K+B vs K is a draw', () {
      final engine = ChessEngine.fromFen('4k3/8/8/8/8/8/8/3BK3 w - - 0 1');
      expect(engine.status, GameStatus.drawInsufficientMaterial);
    });

    test('K+B vs K+B on same-colored squares is a draw', () {
      // c1 is a dark square, f8 is a dark square — same color, drawn.
      final engine = ChessEngine.fromFen('5b1k/8/8/8/8/8/8/2B1K3 w - - 0 1');
      expect(engine.status, GameStatus.drawInsufficientMaterial);
    });

    test('K+B vs K+B on opposite-colored squares is NOT a draw', () {
      // c1 is a dark square, e8... use a genuinely opposite-colored
      // bishop: d1 is a light square, f8 is a dark square.
      final engine = ChessEngine.fromFen('5b1k/8/8/8/8/8/8/3BK3 w - - 0 1');
      expect(engine.status, isNot(GameStatus.drawInsufficientMaterial));
    });

    test('K+N+N vs K is NOT treated as insufficient (documented, conservative choice)', () {
      final engine = ChessEngine.fromFen('4k3/8/8/8/8/8/8/2N1KN2 w - - 0 1');
      expect(engine.status, isNot(GameStatus.drawInsufficientMaterial));
    });
  });

  group('Undo / redo', () {
    test('redo replays an undone move and restores SAN history', () {
      final engine = ChessEngine.initial();
      Move findByUci(String uci) => engine.allLegalMoves.firstWhere((m) => m.uci == uci);

      engine.makeMove(findByUci('e2e4'));
      final fenAfterE4 = engine.fen;
      engine.makeMove(findByUci('e7e5'));

      expect(engine.undoMove(), isTrue);
      expect(engine.fen, fenAfterE4);
      expect(engine.sanHistory, <String>['e4']);

      expect(engine.redoMove(), isTrue);
      expect(engine.sanHistory, <String>['e4', 'e5']);
      expect(engine.canRedo, isFalse);
    });

    test('making a new move after undo clears the redo stack', () {
      final engine = ChessEngine.initial();
      Move findByUci(String uci) => engine.allLegalMoves.firstWhere((m) => m.uci == uci);

      engine.makeMove(findByUci('e2e4'));
      engine.undoMove();
      engine.makeMove(findByUci('d2d4'));

      expect(engine.canRedo, isFalse);
      expect(engine.sanHistory, <String>['d4']);
    });

    test('undo keeps threefold-repetition tracking consistent', () {
      // Shuffle a knight out and back three times without ever undoing —
      // this SHOULD trigger threefold repetition (sanity baseline).
      final engine = ChessEngine.initial();
      Move findByUci(String uci) => engine.allLegalMoves.firstWhere((m) => m.uci == uci);

      for (int i = 0; i < 2; i++) {
        engine.makeMove(findByUci('g1f3'));
        engine.makeMove(findByUci('g8f6'));
        engine.makeMove(findByUci('f3g1'));
        engine.makeMove(findByUci('f6g8'));
      }
      expect(engine.status, GameStatus.drawThreefoldRepetition);

      // Now undo back to before the repetition was reached and confirm
      // the draw is no longer reported — proving _positionKeys shrank
      // along with the undo rather than staying stuck at the old count.
      engine.undoMove();
      engine.undoMove();
      expect(engine.status, isNot(GameStatus.drawThreefoldRepetition));
    });
  });
}
