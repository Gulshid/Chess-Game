import 'package:chess/core/services/game_feedback_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// [GameFeedbackService] only calls into [SystemSound]/[HapticFeedback]
/// platform channels — it has no observable return value to assert on
/// directly, and those channel calls return a `Future<void>` that
/// resolves asynchronously. Every case below therefore runs inside
/// `testWidgets`, so the test binding's platform-channel mocks are
/// already wired up and any pending channel future gets a chance to
/// settle (and fail the test loudly) before the test ends — a bare
/// `test()` block would risk an unhandled-future error surfacing on a
/// later, unrelated test instead of this one.
void main() {
  testWidgets('every combination of sound/haptics runs cleanly for a quiet move', (tester) async {
    for (final bool sound in <bool>[true, false]) {
      for (final bool haptics in <bool>[true, false]) {
        GameFeedbackService.playMove(soundEnabled: sound, hapticsEnabled: haptics);
      }
    }
    await tester.pump();
  });

  testWidgets('capture, castle, and check events all run cleanly', (tester) async {
    GameFeedbackService.playCapture(soundEnabled: true, hapticsEnabled: true);
    GameFeedbackService.playCastle(soundEnabled: true, hapticsEnabled: true);
    GameFeedbackService.playCheck(soundEnabled: true, hapticsEnabled: true);
    await tester.pump();
  });

  testWidgets('game-end feedback runs cleanly for a win, a loss, and a draw', (tester) async {
    GameFeedbackService.playGameEnd(
      soundEnabled: true,
      hapticsEnabled: true,
      won: true,
      drawn: false,
    );
    GameFeedbackService.playGameEnd(
      soundEnabled: true,
      hapticsEnabled: true,
      won: false,
      drawn: false,
    );
    GameFeedbackService.playGameEnd(
      soundEnabled: true,
      hapticsEnabled: true,
      won: false,
      drawn: true,
    );
    await tester.pump();
  });

  testWidgets('fully disabled preferences run cleanly with no feedback fired', (tester) async {
    GameFeedbackService.playMove(soundEnabled: false, hapticsEnabled: false);
    GameFeedbackService.playCapture(soundEnabled: false, hapticsEnabled: false);
    GameFeedbackService.playCheck(soundEnabled: false, hapticsEnabled: false);
    GameFeedbackService.playGameEnd(
      soundEnabled: false,
      hapticsEnabled: false,
      won: true,
      drawn: false,
    );
    await tester.pump();
  });
}
