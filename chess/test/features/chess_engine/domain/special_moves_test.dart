import 'package:chess/features/chess_engine/domain/board_utils.dart';
import 'package:chess/features/chess_engine/domain/chess_engine.dart';
import 'package:chess/features/chess_engine/domain/models/move.dart';
import 'package:chess/features/chess_engine/domain/models/piece.dart';
import 'package:flutter_test/flutter_test.dart';

Move _findMove(List<Move> moves, String toSquare, {MoveFlag? flag, PieceType? promotionType}) {
  return moves.firstWhere(
    (m) =>
        squareToAlgebraic(m.to) == toSquare &&
        (flag == null || m.flag == flag) &&
        (promotionType == null || m.promotionType == promotionType),
  );
}

void main() {
  group('castling', () {
    test('kingside castling is legal when path is clear and safe', () {
      final engine = ChessEngine.fromFen('4k3/8/8/8/8/8/8/4K2R w K - 0 1');
      final List<Move> kingMoves = engine.legalMovesFrom(algebraicToSquare('e1'));
      final Move castle = _findMove(kingMoves, 'g1', flag: MoveFlag.castleKingSide);

      final applied = engine.makeMove(castle);
      expect(applied, isTrue);
      expect(engine.state.pieceAt(algebraicToSquare('g1')), const Piece(PieceColor.white, PieceType.king));
      expect(engine.state.pieceAt(algebraicToSquare('f1')), const Piece(PieceColor.white, PieceType.rook));
      expect(engine.state.pieceAt(algebraicToSquare('e1')), isNull);
      expect(engine.state.pieceAt(algebraicToSquare('h1')), isNull);
    });

    test('queenside castling is legal when path is clear and safe', () {
      final engine = ChessEngine.fromFen('4k3/8/8/8/8/8/8/R3K3 w Q - 0 1');
      final List<Move> kingMoves = engine.legalMovesFrom(algebraicToSquare('e1'));
      final Move castle = _findMove(kingMoves, 'c1', flag: MoveFlag.castleQueenSide);

      engine.makeMove(castle);
      expect(engine.state.pieceAt(algebraicToSquare('c1')), const Piece(PieceColor.white, PieceType.king));
      expect(engine.state.pieceAt(algebraicToSquare('d1')), const Piece(PieceColor.white, PieceType.rook));
    });

    test('castling is illegal if a square in the path is occupied', () {
      final engine = ChessEngine.fromFen('4k3/8/8/8/8/8/8/RN2K3 w Q - 0 1');
      final List<Move> kingMoves = engine.legalMovesFrom(algebraicToSquare('e1'));
      expect(kingMoves.any((m) => m.flag == MoveFlag.castleQueenSide), isFalse);
    });

    test('castling is illegal through an attacked square, even if the king itself is not in check', () {
      // Black rook on f8 attacks the f-file, including f1 — the square
      // the king must pass through to reach g1.
      final engine = ChessEngine.fromFen('5r2/8/8/8/8/8/8/4K2R w K - 0 1');
      final List<Move> kingMoves = engine.legalMovesFrom(algebraicToSquare('e1'));
      expect(kingMoves.any((m) => m.flag == MoveFlag.castleKingSide), isFalse);
    });

    test('castling is illegal while the king is in check', () {
      final engine = ChessEngine.fromFen('4r3/8/8/8/8/8/8/4K2R w K - 0 1');
      final List<Move> kingMoves = engine.legalMovesFrom(algebraicToSquare('e1'));
      expect(kingMoves.any((m) => m.flag == MoveFlag.castleKingSide), isFalse);
    });

    test('moving the king permanently revokes both castling rights, even after moving back', () {
      final engine = ChessEngine.fromFen('4k3/8/8/8/8/8/8/4K2R w K - 0 1');

      final Move kingStep = _findMove(engine.legalMovesFrom(algebraicToSquare('e1')), 'f1');
      engine.makeMove(kingStep);
      expect(engine.state.whiteCanCastleKingSide, isFalse);

      final Move blackWaits = _findMove(engine.legalMovesFrom(algebraicToSquare('e8')), 'd8');
      engine.makeMove(blackWaits);

      final Move kingBack = _findMove(engine.legalMovesFrom(algebraicToSquare('f1')), 'e1');
      engine.makeMove(kingBack);

      expect(engine.state.whiteCanCastleKingSide, isFalse,
          reason: 'castling rights, once lost, do not come back');
      expect(
        engine.legalMovesFrom(algebraicToSquare('e1')).any((m) => m.isCastle),
        isFalse,
      );
    });

    test('moving one rook only revokes that side\'s right', () {
      final engine = ChessEngine.fromFen('4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1');
      final Move rookMove = _findMove(engine.legalMovesFrom(algebraicToSquare('a1')), 'a2');
      engine.makeMove(rookMove);

      expect(engine.state.whiteCanCastleQueenSide, isFalse);
      expect(engine.state.whiteCanCastleKingSide, isTrue);
    });
  });

  group('en passant', () {
    // Position after 1. e4 c5 2. e5 d5 — white's e5 pawn can capture the
    // just-double-moved black d-pawn en passant, landing on d6.
    const String epFen =
        'rnbqkbnr/pp2pppp/8/2ppP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3';

    test('en passant capture is offered immediately after the double push', () {
      final engine = ChessEngine.fromFen(epFen);
      final List<Move> pawnMoves = engine.legalMovesFrom(algebraicToSquare('e5'));
      expect(pawnMoves.any((m) => m.flag == MoveFlag.enPassant && m.to == algebraicToSquare('d6')),
          isTrue);
    });

    test('capturing en passant removes the captured pawn, not just the destination square', () {
      final engine = ChessEngine.fromFen(epFen);
      final Move capture = _findMove(
        engine.legalMovesFrom(algebraicToSquare('e5')),
        'd6',
        flag: MoveFlag.enPassant,
      );
      engine.makeMove(capture);

      expect(engine.state.pieceAt(algebraicToSquare('d6')), const Piece(PieceColor.white, PieceType.pawn));
      expect(engine.state.pieceAt(algebraicToSquare('d5')), isNull,
          reason: 'the captured black pawn (not on the destination square) must be removed');
      expect(engine.state.pieceAt(algebraicToSquare('e5')), isNull);
    });

    test('the en passant right disappears the moment a different move is played', () {
      final engine = ChessEngine.fromFen(epFen);
      final Move developKnight =
          _findMove(engine.legalMovesFrom(algebraicToSquare('g1')), 'f3');
      engine.makeMove(developKnight);
      expect(engine.state.enPassantSquare, isNull);
    });
  });

  group('promotion', () {
    test('a pawn reaching the last rank offers all four promotion choices', () {
      final engine = ChessEngine.fromFen('7k/P7/8/8/8/8/7K/8 w - - 0 1');
      final List<Move> pawnMoves = engine.legalMovesFrom(algebraicToSquare('a7'));
      final promotions = pawnMoves.where((m) => m.to == algebraicToSquare('a8')).toList();

      expect(promotions, hasLength(4));
      expect(
        promotions.map((m) => m.promotionType).toSet(),
        <PieceType>{PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight},
      );
    });

    test('promoting replaces the pawn with the chosen piece type', () {
      final engine = ChessEngine.fromFen('7k/P7/8/8/8/8/7K/8 w - - 0 1');
      final Move promoteToQueen = _findMove(
        engine.legalMovesFrom(algebraicToSquare('a7')),
        'a8',
        promotionType: PieceType.queen,
      );
      engine.makeMove(promoteToQueen);
      expect(engine.state.pieceAt(algebraicToSquare('a8')), const Piece(PieceColor.white, PieceType.queen));
    });

    test('capturing on the last rank also offers all four promotion choices', () {
      final engine = ChessEngine.fromFen('kn6/P7/8/8/8/8/7K/8 w - - 0 1');
      final List<Move> pawnMoves = engine.legalMovesFrom(algebraicToSquare('a7'));
      final captures = pawnMoves.where((m) => m.to == algebraicToSquare('b8')).toList();

      expect(captures, hasLength(4));
      expect(captures.every((m) => m.flag == MoveFlag.promotionCapture), isTrue);
    });
  });
}
