import 'package:chess/features/account/domain/rating.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('updateElo', () {
    test('a draw between equally-rated players leaves both ratings unchanged', () {
      final int newRating = Rating.updateElo(
        playerRating: 1200,
        opponentRating: 1200,
        result: MatchResult.draw,
      );
      expect(newRating, 1200);
    });

    test('beating an equally-rated opponent gains close to half the k-factor', () {
      final int newRating = Rating.updateElo(
        playerRating: 1200,
        opponentRating: 1200,
        result: MatchResult.win,
      );
      // Expected score is 0.5 against an equal opponent, so the gain is
      // k * (1 - 0.5) = 16 for the default k-factor of 32.
      expect(newRating, 1216);
    });

    test('losing to an equally-rated opponent loses the same amount', () {
      final int newRating = Rating.updateElo(
        playerRating: 1200,
        opponentRating: 1200,
        result: MatchResult.loss,
      );
      expect(newRating, 1184);
    });

    test('an upset (beating a much higher-rated opponent) gains close to the full k-factor', () {
      final int newRating = Rating.updateElo(
        playerRating: 1000,
        opponentRating: 1800,
        result: MatchResult.win,
      );
      // Expected score against a 800-point-higher opponent is tiny, so
      // the gain should be very close to the full k-factor of 32.
      expect(newRating - 1000, inInclusiveRange(30, 32));
    });

    test('beating a much lower-rated opponent gains almost nothing', () {
      final int newRating = Rating.updateElo(
        playerRating: 1800,
        opponentRating: 1000,
        result: MatchResult.win,
      );
      expect(newRating - 1800, inInclusiveRange(0, 2));
    });

    test('losing to a much lower-rated opponent loses close to the full k-factor', () {
      final int newRating = Rating.updateElo(
        playerRating: 1800,
        opponentRating: 1000,
        result: MatchResult.loss,
      );
      expect(1800 - newRating, inInclusiveRange(30, 32));
    });

    test('a higher k-factor produces a bigger swing for the same result', () {
      final int smallK = Rating.updateElo(
        playerRating: 1200,
        opponentRating: 1200,
        result: MatchResult.win,
        kFactor: 16,
      );
      final int bigK = Rating.updateElo(
        playerRating: 1200,
        opponentRating: 1200,
        result: MatchResult.win,
        kFactor: 64,
      );
      expect(bigK - 1200, greaterThan(smallK - 1200));
    });
  });

  group('updatePuzzleRating', () {
    test('solving a harder puzzle than your rating gains points', () {
      final int newRating = Rating.updatePuzzleRating(
        playerPuzzleRating: 1000,
        puzzleRating: 1400,
        solved: true,
      );
      expect(newRating, greaterThan(1000));
    });

    test('failing an easier puzzle than your rating loses points', () {
      final int newRating = Rating.updatePuzzleRating(
        playerPuzzleRating: 1400,
        puzzleRating: 1000,
        solved: false,
      );
      expect(newRating, lessThan(1400));
    });

    test('uses a smaller k-factor than ranked games, for a smaller swing', () {
      final int puzzleResult = Rating.updatePuzzleRating(
        playerPuzzleRating: 1200,
        puzzleRating: 1200,
        solved: true,
      );
      final int gameResult = Rating.updateElo(
        playerRating: 1200,
        opponentRating: 1200,
        result: MatchResult.win,
      );
      expect(puzzleResult - 1200, lessThan(gameResult - 1200));
    });
  });
}
