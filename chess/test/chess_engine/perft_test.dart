// Perft ("performance test", despite the name it's really a correctness
// test) counts the total number of legal move sequences from a position to
// a fixed depth. These counts are well-known and published for standard
// test positions, so a mismatch pinpoints a move-generation bug precisely:
//
// - Wrong count at depth 1 -> basic move generation bug for some piece type.
// - Correct at depth 1-2 but wrong deeper -> usually castling rights,
//   en passant, or pin/check-detection bugs that only surface once
//   captures/checks start interacting.
//
// Reference: https://www.chessprogramming.org/Perft_Results
import 'package:chess/features/chess_engine/domain/fen.dart';
import 'package:chess/features/chess_engine/domain/models/board_state.dart';
import 'package:chess/features/chess_engine/domain/move_generator.dart';
import 'package:test/test.dart';

/// Counts leaf nodes at [depth] from [state]. Operates directly on
/// [BoardState] (not [ChessEngine]) since perft is a raw tree search with
/// no need for move history or repetition tracking.
int perft(BoardState state, int depth) {
  if (depth == 0) return 1;

  final moves = MoveGenerator.legalMoves(state);
  if (depth == 1) return moves.length;

  int nodes = 0;
  for (final move in moves) {
    nodes += perft(state.applyMove(move), depth - 1);
  }
  return nodes;
}

void main() {
  group('Perft — starting position', () {
    final BoardState start = BoardState.initial();

    test('depth 1 = 20', () {
      expect(perft(start, 1), 20);
    });

    test('depth 2 = 400', () {
      expect(perft(start, 2), 400);
    });

    test('depth 3 = 8902', () {
      expect(perft(start, 3), 8902);
    });

    test('depth 4 = 197281', () {
      expect(perft(start, 4), 197281);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Perft — Kiwipete position (castling, promotion, tactics)', () {
    // Standard "Kiwipete" test position — deliberately dense with castling
    // rights on both sides, pending captures, and pawns near promotion.
    final BoardState kiwipete = Fen.parse(
      'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
    );

    test('depth 1 = 48', () {
      expect(perft(kiwipete, 1), 48);
    });

    test('depth 2 = 2039', () {
      expect(perft(kiwipete, 2), 2039);
    });

    test('depth 3 = 97862', () {
      expect(perft(kiwipete, 3), 97862);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Perft — Position 3 (en passant / rook endgame edge cases)', () {
    final BoardState position3 = Fen.parse(
      '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1',
    );

    test('depth 1 = 14', () {
      expect(perft(position3, 1), 14);
    });

    test('depth 2 = 191', () {
      expect(perft(position3, 2), 191);
    });

    test('depth 3 = 2812', () {
      expect(perft(position3, 3), 2812);
    });
  });

  group('Perft — Position 4 (promotions, castling, and checks together)', () {
    // Added in Phase 3 specifically because it stresses promotion,
    // castling, and check/pin interactions all in one position — exactly
    // the combination Phase 3's edge-case hardening targets.
    final BoardState position4 = Fen.parse(
      'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1',
    );

    test('depth 1 = 6', () {
      expect(perft(position4, 1), 6);
    });

    test('depth 2 = 264', () {
      expect(perft(position4, 2), 264);
    });

    test('depth 3 = 9467', () {
      expect(perft(position4, 3), 9467);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
