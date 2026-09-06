import 'package:chess/features/advanced/domain/puzzle.dart';
import 'package:chess/features/advanced/domain/puzzle_bank.dart';
import 'package:chess/features/advanced/presentation/puzzle_provider.dart';
import 'package:chess/features/chess_engine/domain/board_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a single-move (mate-in-1) puzzle', () {
    // starter-001: '6k1/5ppp/8/8/8/8/8/R6K w - - 0 1', solution ['a1a8'].
    final Puzzle puzzle = PuzzleBank.byId('starter-001');

    test('starts inProgress at the puzzle position', () {
      final provider = PuzzleProvider(puzzle);
      addTearDown(provider.dispose);

      expect(provider.puzzleStatus, PuzzleStatus.inProgress);
      expect(provider.fen, puzzle.fen);
    });

    test('playing the solution move marks the puzzle solved', () {
      final provider = PuzzleProvider(puzzle);
      addTearDown(provider.dispose);

      provider.selectSquare(algebraicToSquare('a1'));
      final bool applied = provider.moveSelectedTo(algebraicToSquare('a8'));

      expect(applied, isTrue);
      expect(provider.puzzleStatus, PuzzleStatus.solved);
      expect(provider.solvedPlyCount, 1);
    });

    test('playing a wrong (but legal) move marks the puzzle failed and leaves the board unmoved', () {
      final provider = PuzzleProvider(puzzle);
      addTearDown(provider.dispose);

      // a1-a7 is a legal rook move, but not the puzzle's solution.
      provider.selectSquare(algebraicToSquare('a1'));
      final bool applied = provider.moveSelectedTo(algebraicToSquare('a7'));

      expect(applied, isFalse);
      expect(provider.puzzleStatus, PuzzleStatus.failed);
      expect(provider.fen, puzzle.fen, reason: 'the wrong move must not be applied to the board');
    });

    test('resetPuzzle returns to inProgress at the original position', () {
      final provider = PuzzleProvider(puzzle);
      addTearDown(provider.dispose);

      provider.selectSquare(algebraicToSquare('a1'));
      provider.moveSelectedTo(algebraicToSquare('a7')); // fail it first
      expect(provider.puzzleStatus, PuzzleStatus.failed);

      provider.resetPuzzle();

      expect(provider.puzzleStatus, PuzzleStatus.inProgress);
      expect(provider.fen, puzzle.fen);
      expect(provider.solvedPlyCount, 0);
    });

    test('requestHint selects the origin square of the correct move', () {
      final provider = PuzzleProvider(puzzle);
      addTearDown(provider.dispose);

      provider.requestHint();
      expect(provider.selectedSquare, algebraicToSquare('a1'));
    });
  });

  group('a puzzle with a forced opponent reply', () {
    // Player plays a1-a8+ (check, not mate — the king has e7/f7 to run
    // to); the puzzle's solution scripts the king retreating to e7 as
    // the automatic "opponent reply", after which the puzzle is solved.
    // Constructed for this test specifically since none of the starter
    // puzzles in `PuzzleBank` have a two-ply solution.
    final Puzzle puzzle = const Puzzle(
      id: 'test-two-ply',
      fen: '5k2/6pp/8/8/8/8/8/R6K w - - 0 1',
      solutionUci: <String>['a1a8', 'f8e7'],
      rating: 900,
      themes: <String>['check'],
    );

    test('stays inProgress after the correct first move, until the auto-reply lands', () async {
      final provider = PuzzleProvider(puzzle);
      addTearDown(provider.dispose);

      provider.selectSquare(algebraicToSquare('a1'));
      final bool applied = provider.moveSelectedTo(algebraicToSquare('a8'));
      expect(applied, isTrue);
      expect(provider.solvedPlyCount, 1);

      // The reply is scheduled on a short timer (see
      // `PuzzleProvider._maybePlayForcedReplyOrFinish`) rather than
      // applied synchronously, so status is still inProgress right
      // after the player's move...
      expect(provider.puzzleStatus, PuzzleStatus.inProgress);

      // ...and becomes solved once the timer fires.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(provider.puzzleStatus, PuzzleStatus.solved);
      expect(provider.solvedPlyCount, 2);
      expect(provider.engine.state.pieceAt(algebraicToSquare('e7')), isNotNull,
          reason: 'the scripted reply (Ke7) should have been played automatically');
    });
  });
}
