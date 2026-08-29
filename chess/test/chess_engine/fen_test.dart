import 'package:chess/core/constant/app_constants.dart';
import 'package:chess/features/chess_engine/domain/chess_engine.dart';
import 'package:chess/features/chess_engine/domain/fen.dart';
import 'package:chess/features/chess_engine/domain/game_status.dart';
import 'package:chess/features/chess_engine/domain/models/board_state.dart';
import 'package:chess/features/chess_engine/domain/models/move.dart';
import 'package:test/test.dart';

void main() {
  group('FEN', () {
    test('starting position round-trips exactly', () {
      final BoardState state = BoardState.initial();
      expect(Fen.generate(state), AppConstants.startingFen);

      final BoardState reparsed = Fen.parse(AppConstants.startingFen);
      expect(Fen.generate(reparsed), AppConstants.startingFen);
    });

    test('arbitrary mid-game FEN round-trips', () {
      const String midGameFen =
          'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 2 2';
      final BoardState state = Fen.parse(midGameFen);
      expect(Fen.generate(state), midGameFen);
    });

    test('parses en passant target square correctly', () {
      const String fen = 'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3';
      final BoardState state = Fen.parse(fen);
      expect(state.enPassantSquare, isNotNull);
      expect(Fen.generate(state), fen);
    });
  });

  group('ChessEngine facade', () {
    test('starting position has exactly 20 legal moves for White', () {
      final ChessEngine engine = ChessEngine.initial();
      expect(engine.allLegalMoves.length, 20);
      expect(engine.status, GameStatus.ongoing);
    });

    test('makeMove rejects illegal moves and leaves state unchanged', () {
      final ChessEngine engine = ChessEngine.initial();
      final String fenBefore = engine.fen;

      // e2 to e5 in one move is not a legal opening move.
      const illegalMove = Move(from: 12, to: 36); // e2 -> e5, no flag set
      final bool applied = engine.makeMove(illegalMove);

      expect(applied, isFalse);
      expect(engine.fen, fenBefore);
    });

    test('undoMove restores the previous position', () {
      final ChessEngine engine = ChessEngine.initial();
      final String fenBefore = engine.fen;

      final Move e4 = engine.allLegalMoves.firstWhere((m) => m.uci == 'e2e4');
      expect(engine.makeMove(e4), isTrue);
      expect(engine.fen, isNot(fenBefore));

      expect(engine.undoMove(), isTrue);
      expect(engine.fen, fenBefore);
    });

    test("fool's mate reaches checkmate in 4 half-moves", () {
      final ChessEngine engine = ChessEngine.initial();

      Move findByUci(String uci) =>
          engine.allLegalMoves.firstWhere((m) => m.uci == uci);

      expect(engine.makeMove(findByUci('f2f3')), isTrue);
      expect(engine.makeMove(findByUci('e7e5')), isTrue);
      expect(engine.makeMove(findByUci('g2g4')), isTrue);
      expect(engine.makeMove(findByUci('d8h4')), isTrue);

      expect(engine.status, GameStatus.checkmate);
      expect(engine.allLegalMoves, isEmpty);
    });

    test('king cannot castle through check', () {
      // White king on e1, rook on h1, black rook on f8 controlling f1 —
      // king-side castling must be illegal because the king would pass
      // through an attacked square (f1).
      final ChessEngine engine =
          ChessEngine.fromFen('5r1k/8/8/8/8/8/8/4K2R w K - 0 1');

      final bool hasKingSideCastle =
          engine.allLegalMoves.any((m) => m.flag == MoveFlag.castleKingSide);

      expect(hasKingSideCastle, isFalse);
    });
  });
}
