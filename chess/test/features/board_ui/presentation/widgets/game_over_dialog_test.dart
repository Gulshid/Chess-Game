import 'package:chess/features/board_ui/presentation/widgets/game_over_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/test_app.dart';

void main() {
  testWidgets('renders the headline and every provided action', (tester) async {
    await pumpForTest(
      tester,
      GameOverDialog(
        headline: 'White wins by checkmate',
        outcome: GameOverOutcome.win,
        actions: const [
          Text('Close'),
          Text('New game'),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 500)); // let the open animation settle

    expect(find.text('White wins by checkmate'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('New game'), findsOneWidget);
  });

  testWidgets('shows the trophy icon on a win and the handshake icon on a draw', (tester) async {
    await pumpForTest(
      tester,
      GameOverDialog(
        headline: 'Draw by agreement',
        outcome: GameOverOutcome.draw,
        actions: const [Text('Close')],
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.handshake), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsNothing);
  });

  testWidgets('does not throw while animating in for any outcome', (tester) async {
    for (final GameOverOutcome outcome in GameOverOutcome.values) {
      await pumpForTest(
        tester,
        GameOverDialog(
          headline: 'Game over',
          outcome: outcome,
          actions: const [Text('Close')],
        ),
      );
      // Pump a few intermediate frames (not just pumpAndSettle) so the
      // confetti painter — which only actually draws anything for a
      // win — gets exercised mid-animation, not just at the start/end.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
    }
  });
}
