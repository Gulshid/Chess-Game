import 'package:chess/features/ai/domain/minimax_engine.dart';
import 'package:chess/features/chess_engine/domain/board_utils.dart';
import 'package:chess/features/chess_engine/domain/fen.dart';
import 'package:chess/features/chess_engine/domain/models/board_state.dart';
import 'package:chess/features/chess_engine/domain/models/move.dart';
import 'package:chess/features/chess_engine/domain/move_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Talks to [MinimaxEngine] directly rather than through [AiOpponent] —
/// [AiOpponent] only adds an [Isolate.run] boundary and UCI
/// string-marshalling around this same call (see its class doc), which
/// isn't worth re-testing here; `game_provider_test.dart` covers that
/// integration end-to-end instead.
void main() {
  test('always returns a legal move for a normal position', () {
    final BoardState start = BoardState.initial();
    final Move? move = MinimaxEngine.findBestMove(
      start,
      maxDepth: 2,
      deadline: DateTime.now().add(const Duration(seconds: 5)),
    );
    expect(move, isNotNull);
    expect(MoveGenerator.legalMoves(start), contains(move));
  });

  test('returns null when there are no legal moves (checkmate/stalemate)', () {
    // Back-rank checkmate position — side to move (black) has no moves.
    final BoardState mated = Fen.parse('R5k1/5ppp/8/8/8/8/8/6K1 b - - 0 1');
    expect(MoveGenerator.legalMoves(mated), isEmpty);
    final Move? move = MinimaxEngine.findBestMove(
      mated,
      maxDepth: 2,
      deadline: DateTime.now().add(const Duration(seconds: 1)),
    );
    expect(move, isNull);
  });

  test('finds the only legal move immediately without searching', () {
    // White king in check from the rook on a8 along the open a-file,
    // with a black pawn on c3 covering b2 — b1 is the only square that
    // both escapes the check and isn't otherwise attacked. A good check
    // that the "single legal move" fast path (see
    // `MinimaxEngine.findBestMove`'s early return) doesn't just return
    // an arbitrary/wrong move.
    final BoardState state = Fen.parse('r6k/8/8/8/8/2p5/8/K7 w - - 0 1');
    final List<Move> legal = MoveGenerator.legalMoves(state);
    expect(legal, hasLength(1));
    expect(legal.single.to, algebraicToSquare('b1'));

    final Move? move = MinimaxEngine.findBestMove(
      state,
      maxDepth: 3,
      deadline: DateTime.now().add(const Duration(seconds: 1)),
    );
    expect(move, legal.single);
  });

  test('finds a one-move checkmate when one is available', () {
    // White to move: Ra1-a8 is mate (see the same position in
    // game_status_test.dart's back-rank-mate test).
    final BoardState state = Fen.parse('6k1/5ppp/8/8/8/8/8/R6K w - - 0 1');
    final Move? move = MinimaxEngine.findBestMove(
      state,
      maxDepth: 3,
      deadline: DateTime.now().add(const Duration(seconds: 5)),
    );
    expect(move, isNotNull);
    expect(move!.to, algebraicToSquare('a8'));
  });
}
