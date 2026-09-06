import 'package:chess/features/ai/domain/ai_difficulty.dart';
import 'package:chess/features/chess_engine/domain/board_utils.dart';
import 'package:chess/features/chess_engine/domain/chess_engine.dart';
import 'package:chess/features/chess_engine/domain/game_status.dart';
import 'package:chess/features/chess_engine/domain/models/piece.dart';
import 'package:chess/providers/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  group('initial state', () {
    test('starts at the standard position with white to move', () {
      final provider = GameProvider();
      expect(provider.sideToMove, PieceColor.white);
      expect(provider.legalMoves, hasLength(20));
      expect(provider.isGameOver, isFalse);
      expect(provider.selectedSquare, isNull);
    });
  });

  group('selection and moving', () {
    test('selecting your own piece populates movesFromSelected', () {
      final provider = GameProvider();
      provider.selectSquare(algebraicToSquare('e2'));
      expect(provider.selectedSquare, algebraicToSquare('e2'));
      expect(provider.movesFromSelected.map((m) => squareToAlgebraic(m.to)),
          containsAll(<String>['e3', 'e4']));
    });

    test('selecting an empty square or the opponent\'s piece is a no-op', () {
      final provider = GameProvider();
      provider.selectSquare(algebraicToSquare('e4')); // empty
      expect(provider.selectedSquare, isNull);

      provider.selectSquare(algebraicToSquare('e7')); // black pawn, white to move
      expect(provider.selectedSquare, isNull);
    });

    test('moveSelectedTo applies a legal move and flips the side to move', () {
      final provider = GameProvider();
      provider.selectSquare(algebraicToSquare('e2'));
      final bool applied = provider.moveSelectedTo(algebraicToSquare('e4'));

      expect(applied, isTrue);
      expect(provider.sideToMove, PieceColor.black);
      expect(provider.sanHistory, <String>['e4']);
      expect(provider.selectedSquare, isNull, reason: 'selection clears after a move attempt');
    });

    test('moveSelectedTo to a non-legal destination fails and clears the selection', () {
      final provider = GameProvider();
      provider.selectSquare(algebraicToSquare('e2'));
      final bool applied = provider.moveSelectedTo(algebraicToSquare('e5')); // too far

      expect(applied, isFalse);
      expect(provider.sideToMove, PieceColor.white, reason: 'nothing should have moved');
      expect(provider.selectedSquare, isNull);
    });

    test('moveSelectedTo with nothing selected returns false', () {
      final provider = GameProvider();
      expect(provider.moveSelectedTo(algebraicToSquare('e4')), isFalse);
    });

    test('a promotion move defaults to queen when unspecified', () {
      final provider = GameProvider(engine: _engineAt('7k/P7/8/8/8/8/8/7K w - - 0 1'));
      provider.selectSquare(algebraicToSquare('a7'));
      final bool applied = provider.moveSelectedTo(algebraicToSquare('a8'));

      expect(applied, isTrue);
      expect(provider.engine.state.pieceAt(algebraicToSquare('a8')),
          const Piece(PieceColor.white, PieceType.queen));
    });

    test('a promotion move honors an explicit non-queen choice', () {
      final provider = GameProvider(engine: _engineAt('7k/P7/8/8/8/8/8/7K w - - 0 1'));
      provider.selectSquare(algebraicToSquare('a7'));
      final bool applied =
          provider.moveSelectedTo(algebraicToSquare('a8'), promotion: PieceType.knight);

      expect(applied, isTrue);
      expect(provider.engine.state.pieceAt(algebraicToSquare('a8')),
          const Piece(PieceColor.white, PieceType.knight));
    });
  });

  group('undo/redo', () {
    test('undo reverts the last move and redo replays it', () {
      final provider = GameProvider();
      provider.selectSquare(algebraicToSquare('e2'));
      provider.moveSelectedTo(algebraicToSquare('e4'));
      expect(provider.canUndo, isTrue);
      expect(provider.canRedo, isFalse);

      provider.undo();
      expect(provider.sideToMove, PieceColor.white);
      expect(provider.sanHistory, isEmpty);
      expect(provider.canRedo, isTrue);

      provider.redo();
      expect(provider.sideToMove, PieceColor.black);
      expect(provider.sanHistory, <String>['e4']);
    });
  });

  group('resign and offer draw', () {
    test('resign ends the game in favor of the opponent', () {
      final provider = GameProvider();
      provider.resign(); // white to move resigns
      expect(provider.isGameOver, isTrue);
      expect(provider.gameOverOverrideMessage, contains('Black wins'));
    });

    test('offerDraw ends the game as a draw', () {
      final provider = GameProvider();
      provider.offerDraw();
      expect(provider.isGameOver, isTrue);
      expect(provider.gameOverOverrideMessage, 'Draw by agreement');
    });

    test('resigning an already-over game is a no-op', () {
      final provider = GameProvider();
      provider.resign();
      final String? firstMessage = provider.gameOverOverrideMessage;
      provider.offerDraw(); // should not overwrite the resignation
      expect(provider.gameOverOverrideMessage, firstMessage);
    });

    test('status-driven game overs (checkmate) do not need an override message', () {
      // Fool's mate position, one move from mate — Qh4#.
      final provider = GameProvider(
        engine: _engineAt('rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3'),
      );
      expect(provider.isGameOver, isTrue);
      expect(provider.status, GameStatus.checkmate);
      expect(provider.gameOverOverrideMessage, isNull);
    });
  });

  group('AI opponent integration', () {
    test('the AI moves automatically when it plays the side to move', () async {
      final provider = GameProvider();
      provider.startGameVsAi(aiPlaysAs: PieceColor.white, difficulty: AiDifficulty.beginner);

      expect(provider.aiColor, PieceColor.white);
      await _waitUntil(() => provider.moveHistory.length == 1);

      expect(provider.isAiThinking, isFalse);
      expect(provider.sideToMove, PieceColor.black, reason: 'the AI (white) should have moved once');
    });

    test('the AI does not move on the human\'s turn', () async {
      final provider = GameProvider();
      provider.startGameVsAi(aiPlaysAs: PieceColor.black, difficulty: AiDifficulty.beginner);

      // Give any (incorrect) background search a moment to fire if it
      // were going to.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(provider.moveHistory, isEmpty);
      expect(provider.isHumanTurnInAiGame, isTrue);
    });

    test('a human move triggers a single AI reply', () async {
      final provider = GameProvider();
      provider.startGameVsAi(aiPlaysAs: PieceColor.black, difficulty: AiDifficulty.beginner);

      provider.selectSquare(algebraicToSquare('e2'));
      provider.moveSelectedTo(algebraicToSquare('e4'));

      await _waitUntil(() => provider.moveHistory.length == 2);
      expect(provider.sideToMove, PieceColor.white);
    });

    test('startGameVsAi(aiPlaysAs: null) returns to a local two-player game', () {
      final provider = GameProvider();
      provider.startGameVsAi(aiPlaysAs: PieceColor.white, difficulty: AiDifficulty.beginner);
      provider.startGameVsAi(aiPlaysAs: null);
      expect(provider.aiColor, isNull);
    });
  });

  group('loadFen', () {
    test('loads an arbitrary position and turns off the AI', () {
      final provider = GameProvider();
      provider.startGameVsAi(aiPlaysAs: PieceColor.black, difficulty: AiDifficulty.beginner);

      provider.loadFen('7k/8/8/8/8/8/8/K6R w - - 0 1');
      expect(provider.aiColor, isNull);
      expect(provider.fen, '7k/8/8/8/8/8/8/K6R w - - 0 1');
    });
  });
}

ChessEngine _engineAt(String fen) => ChessEngine.fromFen(fen);
