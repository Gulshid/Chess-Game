import 'package:chess/features/chess_engine/domain/fen.dart';
import 'package:chess/features/chess_engine/domain/models/board_state.dart';
import 'package:chess/features/chess_engine/domain/models/move.dart';
import 'package:chess/features/chess_engine/domain/move_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Write unit tests against known perft (performance test) positions to
/// verify move-generation correctness — this is the industry-standard
/// way to validate a chess engine." — Phase 2. Extended in Phase 3
/// ("Run the engine against public perft test suites ... to confirm
/// 100% correctness") with the Kiwipete position specifically, since it
/// is *the* standard reference position for exercising castling, en
/// passant, promotion, and check evasion all at once — a bug in any of
/// those shows up as a wrong node count here, before Phase 10 QA and
/// not after.
///
/// Deliberately works directly against [MoveGenerator]/[BoardState]
/// rather than [ChessEngine] — perft is pure move-generation counting
/// with no need for [ChessEngine]'s move-history/SAN/repetition
/// bookkeeping, which would only slow this down across the tens of
/// thousands of positions higher perft depths visit.
int _perft(BoardState state, int depth) {
  if (depth == 0) return 1;
  final List<Move> moves = MoveGenerator.legalMoves(state);
  if (depth == 1) return moves.length;
  int nodes = 0;
  for (final Move move in moves) {
    nodes += _perft(state.applyMove(move), depth - 1);
  }
  return nodes;
}

void main() {
  group('perft from the starting position', () {
    // Reference values: https://www.chessprogramming.org/Perft_Results
    final BoardState start = BoardState.initial();
    const Map<int, int> expected = <int, int>{
      1: 20,
      2: 400,
      3: 8902,
    };

    expected.forEach((depth, nodes) {
      test('depth $depth = $nodes nodes', () {
        expect(_perft(start, depth), nodes);
      });
    });
  });

  group('perft from the "Kiwipete" position', () {
    // The standard second reference position from the chessprogramming
    // wiki's perft results page — deliberately dense with castling
    // rights (both sides, both directions), an en passant target, and
    // near-term promotion/capture tactics, so a single wrong node count
    // here can point at several different rule categories at once.
    final BoardState kiwipete = Fen.parse(
      'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
    );
    const Map<int, int> expected = <int, int>{
      1: 48,
      2: 2039,
      3: 97862,
    };

    expected.forEach((depth, nodes) {
      test('depth $depth = $nodes nodes', () {
        expect(_perft(kiwipete, depth), nodes);
      }, timeout: const Timeout(Duration(minutes: 2)));
    });
  });
}
