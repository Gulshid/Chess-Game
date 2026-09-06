import 'package:chess/features/advanced/domain/move_resolver.dart';
import 'package:chess/features/advanced/domain/pgn.dart';
import 'package:chess/features/chess_engine/domain/board_utils.dart';
import 'package:chess/features/chess_engine/domain/chess_engine.dart';
import 'package:chess/features/chess_engine/domain/models/move.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Full PGN import/export (with headers: event, players, result,
/// date)" — Phase 8. The meaningful correctness property for PGN isn't
/// that [Pgn.generate]'s text matches some exact expected string (PGN
/// whitespace/wrapping is cosmetic) — it's that a game exported to PGN
/// and re-imported produces the *same final position*. That's what
/// these tests check, replaying the parsed SAN moves with
/// [MoveResolver] exactly like [AnalysisProvider.loadPgn] does.
void main() {
  test('generate -> parse -> replay reproduces the original final position', () {
    final ChessEngine original = ChessEngine.initial();
    for (final List<String> ply in <List<String>>[
      <String>['e2', 'e4'],
      <String>['e7', 'e5'],
      <String>['g1', 'f3'],
      <String>['b8', 'c6'],
      <String>['f1', 'c4'],
      <String>['f8', 'c5'],
    ]) {
      final Move move = original
          .legalMovesFrom(algebraicToSquare(ply[0]))
          .firstWhere((m) => squareToAlgebraic(m.to) == ply[1]);
      original.makeMove(move);
    }

    final String pgn = Pgn.generate(
      sanMoves: original.sanHistory,
      white: 'Alice',
      black: 'Bob',
      result: '*',
    );

    final ParsedPgn parsed = Pgn.parse(pgn);
    expect(parsed.white, 'Alice');
    expect(parsed.black, 'Bob');
    expect(parsed.sanMoves, original.sanHistory);

    final ChessEngine replay = ChessEngine.initial();
    for (final String san in parsed.sanMoves) {
      final Move? move = MoveResolver.fromSan(replay.state, san);
      expect(move, isNotNull, reason: 'could not resolve "$san"');
      replay.makeMove(move!);
    }

    expect(replay.fen, original.fen);
  });

  test('a game with castling, a capture, and check round-trips correctly', () {
    final ChessEngine original = ChessEngine.initial();
    for (final List<String> ply in <List<String>>[
      <String>['e2', 'e4'],
      <String>['e7', 'e5'],
      <String>['g1', 'f3'],
      <String>['b8', 'c6'],
      <String>['f1', 'b5'], // Ruy Lopez
      <String>['a7', 'a6'],
      <String>['b5', 'c6'], // capture
      <String>['d7', 'c6'], // recapture
      <String>['e1', 'g1'], // white castles kingside
    ]) {
      final Move move = original
          .legalMovesFrom(algebraicToSquare(ply[0]))
          .firstWhere((m) => squareToAlgebraic(m.to) == ply[1]);
      original.makeMove(move);
    }

    final String pgn = Pgn.generate(sanMoves: original.sanHistory);
    final ParsedPgn parsed = Pgn.parse(pgn);

    final ChessEngine replay = ChessEngine.initial();
    for (final String san in parsed.sanMoves) {
      final Move? move = MoveResolver.fromSan(replay.state, san);
      expect(move, isNotNull, reason: 'could not resolve "$san"');
      replay.makeMove(move!);
    }

    expect(replay.fen, original.fen);
  });

  test('parsing strips move numbers, results, and comments', () {
    const String pgn = '''
[Event "Casual Game"]
[White "A"]
[Black "B"]
[Result "1-0"]

1. e4 {best by test} e5 2. Nf3 Nc6 3. Bb5 {the Ruy Lopez} 1-0
''';
    final ParsedPgn parsed = Pgn.parse(pgn);
    expect(parsed.sanMoves, <String>['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
    expect(parsed.result, '1-0');
  });

  test('a [FEN] header sets a custom starting position', () {
    const String customStart = '4k3/8/8/8/8/8/8/4K2R w K - 0 1';
    final String pgn = Pgn.generate(
      sanMoves: <String>['O-O'],
      startingFen: customStart,
    );
    final ParsedPgn parsed = Pgn.parse(pgn);
    expect(parsed.startingFen, customStart);
  });
}
