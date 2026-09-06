import 'package:chess/core/constant/app_constants.dart';
import 'package:chess/features/chess_engine/domain/board_utils.dart';
import 'package:chess/features/chess_engine/domain/chess_engine.dart';
import 'package:chess/features/chess_engine/domain/fen.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Validate FEN parsing/generation round-trips correctly for arbitrary
/// positions" — Phase 3.
void main() {
  const List<String> positions = <String>[
    // Standard starting position.
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    // After 1. e4 c5 2. Nf3 — mixed castling rights, no en passant.
    'rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
    // An en passant target present.
    'rnbqkbnr/pp2pppp/8/2ppP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3',
    // No castling rights at all for either side.
    '4k3/8/8/8/8/8/8/4K2R w - - 12 30',
    // The "Kiwipete" perft test position — deliberately dense with
    // special-move potential (castling both sides, an en passant
    // target, promotions available).
    'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
  ];

  for (final String fen in positions) {
    test('round-trips: $fen', () {
      final state = Fen.parse(fen);
      expect(Fen.generate(state), fen);
    });
  }

  test('ChessEngine.fen matches the FEN it was constructed from', () {
    for (final String fen in positions) {
      expect(ChessEngine.fromFen(fen).fen, fen);
    }
  });

  test('the starting position FEN matches the app-wide constant', () {
    expect(ChessEngine.initial().fen, AppConstants.startingFen);
  });

  test('FEN round-trips correctly after a game is played out', () {
    final engine = ChessEngine.initial();
    // Play a short, ordinary opening sequence.
    for (final List<String> ply in <List<String>>[
      <String>['e2', 'e4'],
      <String>['e7', 'e5'],
      <String>['g1', 'f3'],
      <String>['b8', 'c6'],
    ]) {
      final move = engine
          .legalMovesFrom(algebraicToSquare(ply[0]))
          .firstWhere((m) => squareToAlgebraic(m.to) == ply[1]);
      engine.makeMove(move);
    }
    final String fen = engine.fen;
    expect(Fen.generate(Fen.parse(fen)), fen);
  });

  test('throws FormatException on structurally invalid FEN', () {
    expect(() => Fen.parse('not a fen'), throwsFormatException);
    expect(() => Fen.parse('8/8/8/8/8/8/8 w - - 0 1'), throwsFormatException); // only 7 ranks
  });
}
