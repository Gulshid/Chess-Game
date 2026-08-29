import 'package:chess/features/chess_engine/domain/chess_engine.dart';
import 'package:chess/features/chess_engine/domain/game_status.dart';
import 'package:chess/features/chess_engine/domain/models/piece.dart';
import 'package:chess/providers/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameProvider — construction & DI', () {
    test('defaults to a fresh game when no engine is injected', () {
      final provider = GameProvider();
      expect(provider.legalMoves.length, 20);
      expect(provider.sideToMove, PieceColor.white);
    });

    test('accepts an injected engine (e.g. a resumed/loaded game)', () {
      final engine = ChessEngine.fromFen(
        'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1',
      );
      final provider = GameProvider(engine: engine);
      expect(provider.fen, engine.fen);
    });
  });

  group('GameProvider — selection', () {
    test('selecting own piece populates movesFromSelected and notifies', () {
      final provider = GameProvider();
      int notifications = 0;
      provider.addListener(() => notifications++);

      provider.selectSquare(12); // e2, white pawn
      expect(provider.selectedSquare, 12);
      expect(provider.movesFromSelected, isNotEmpty);
      expect(notifications, 1);
    });

    test('selecting an opponent piece is a no-op', () {
      final provider = GameProvider();
      provider.selectSquare(52); // e7, black pawn — not white's piece
      expect(provider.selectedSquare, isNull);
    });

    test('clearSelection resets selection state', () {
      final provider = GameProvider();
      provider.selectSquare(12);
      provider.clearSelection();
      expect(provider.selectedSquare, isNull);
      expect(provider.movesFromSelected, isEmpty);
    });
  });

  group('GameProvider — moveSelectedTo', () {
    test('applies a legal move and clears selection', () {
      final provider = GameProvider();
      provider.selectSquare(12); // e2

      final applied = provider.moveSelectedTo(28); // e4
      expect(applied, isTrue);
      expect(provider.selectedSquare, isNull);
      expect(provider.sanHistory, <String>['e4']);
    });

    test('tapping a non-legal destination fails and clears selection', () {
      final provider = GameProvider();
      provider.selectSquare(12); // e2

      final applied = provider.moveSelectedTo(4); // e1 — not a legal pawn move
      expect(applied, isFalse);
      expect(provider.selectedSquare, isNull);
    });

    test('defaults to queen promotion when the target is ambiguous', () {
      final provider = GameProvider(
        engine: ChessEngine.fromFen('8/P3k3/8/8/8/8/8/4K3 w - - 0 1'),
      );
      provider.selectSquare(48); // a7

      final applied = provider.moveSelectedTo(56); // a8
      expect(applied, isTrue);
      expect(provider.sanHistory.single, 'a8=Q');
    });

    test('honors an explicit non-queen promotion choice', () {
      final provider = GameProvider(
        engine: ChessEngine.fromFen('8/P3k3/8/8/8/8/8/4K3 w - - 0 1'),
      );
      provider.selectSquare(48); // a7

      final applied = provider.moveSelectedTo(56, promotion: PieceType.knight);
      expect(applied, isTrue);
      expect(provider.sanHistory.single, 'a8=N');
    });
  });

  group('GameProvider — undo/redo/reset/loadFen', () {
    test('undo and redo round-trip correctly and notify listeners', () {
      final provider = GameProvider();
      provider.selectSquare(12);
      provider.moveSelectedTo(28); // e4
      final fenAfterMove = provider.fen;

      provider.undo();
      expect(provider.canUndo, isFalse);
      expect(provider.canRedo, isTrue);

      provider.redo();
      expect(provider.fen, fenAfterMove);
      expect(provider.canRedo, isFalse);
    });

    test('reset restores the standard starting position', () {
      final provider = GameProvider();
      provider.selectSquare(12);
      provider.moveSelectedTo(28);

      provider.reset();
      expect(provider.legalMoves.length, 20);
      expect(provider.status, GameStatus.ongoing);
    });

    test('loadFen switches the underlying position', () {
      final provider = GameProvider();
      const fen = '4k3/8/8/8/8/8/8/4K3 w - - 0 1';
      provider.loadFen(fen);
      expect(provider.fen, fen);
      expect(provider.status, GameStatus.drawInsufficientMaterial);
    });
  });
}
