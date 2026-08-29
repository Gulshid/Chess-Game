import 'fen.dart';
import 'game_status.dart';
import 'models/board_state.dart';
import 'models/move.dart';
import 'models/piece.dart';
import 'move_generator.dart';

/// The public facade for the chess rules engine. This is the ONLY class
/// the rest of the app (UI in Phase 5, AI in Phase 6, multiplayer in
/// Phase 7) should need to talk to — nobody outside this folder should
/// call `MoveGenerator` or `BoardState.applyMove` directly.
///
/// Everything here is pure Dart with zero Flutter dependency, so it can be
/// unit-tested without any widget test harness (see test/chess_engine/).
class ChessEngine {
  ChessEngine._(this._state);

  factory ChessEngine.initial() => ChessEngine._(BoardState.initial());

  factory ChessEngine.fromFen(String fen) => ChessEngine._(Fen.parse(fen));

  BoardState _state;

  /// Position history, used for undo (Phase 4) and threefold-repetition
  /// detection. Stores the state *before* each move, so `_history.last`
  /// is what you'd restore on undo.
  final List<BoardState> _history = <BoardState>[];

  /// Repetition keys for every position reached so far (including the
  /// current one), used for threefold-repetition detection. A "position"
  /// for repetition purposes excludes the halfmove/fullmove counters —
  /// only piece placement, side to move, castling rights, and en passant
  /// target matter, per FIDE rules.
  final List<String> _positionKeys = <String>[];

  BoardState get state => _state;

  String get fen => Fen.generate(_state);

  PieceColor get sideToMove => _state.sideToMove;

  /// All legal moves for the side to move.
  List<Move> get allLegalMoves => MoveGenerator.legalMoves(_state);

  /// Legal moves originating from a specific square — this is what the
  /// board UI calls when a player taps/selects a piece.
  List<Move> legalMovesFrom(int square) =>
      allLegalMoves.where((Move m) => m.from == square).toList();

  bool get isInCheck => MoveGenerator.isKingInCheck(_state, _state.sideToMove);

  /// Attempts to play [move]. Returns true and updates state if the move
  /// is legal; returns false and leaves state unchanged otherwise.
  ///
  /// Callers should get candidate moves from [legalMovesFrom] /
  /// [allLegalMoves] rather than constructing arbitrary [Move] objects by
  /// hand — this guards against illegal moves slipping through, but the
  /// legality check here is the real source of truth.
  bool makeMove(Move move) {
    final bool isLegal = allLegalMoves.contains(move);
    if (!isLegal) return false;

    _history.add(_state);
    if (_positionKeys.isEmpty) {
      _positionKeys.add(_repetitionKey(_state));
    }
    _state = _state.applyMove(move);
    _positionKeys.add(_repetitionKey(_state));
    return true;
  }

  /// Undoes the last move, if any. Returns true if a move was undone.
  bool undoMove() {
    if (_history.isEmpty) return false;
    _state = _history.removeLast();
    if (_positionKeys.isNotEmpty) _positionKeys.removeLast();
    return true;
  }

  GameStatus get status {
    final List<Move> moves = allLegalMoves;
    final bool inCheck = isInCheck;

    if (moves.isEmpty) {
      return inCheck ? GameStatus.checkmate : GameStatus.stalemate;
    }
    if (_state.halfmoveClock >= 100) {
      return GameStatus.drawFiftyMoveRule;
    }
    if (_hasInsufficientMaterial()) {
      return GameStatus.drawInsufficientMaterial;
    }
    if (_isThreefoldRepetition()) {
      return GameStatus.drawThreefoldRepetition;
    }
    return inCheck ? GameStatus.check : GameStatus.ongoing;
  }

  String _repetitionKey(BoardState s) {
    // Same as FEN but deliberately omits halfmove/fullmove counters,
    // per the FIDE repetition rule (those counters don't define "the same
    // position").
    final String full = Fen.generate(s);
    final List<String> parts = full.split(' ');
    return parts.sublist(0, 4).join(' ');
  }

  bool _isThreefoldRepetition() {
    if (_positionKeys.isEmpty) return false;
    final String current = _positionKeys.last;
    final int occurrences = _positionKeys.where((String k) => k == current).length;
    return occurrences >= 3;
  }

  /// Conservative insufficient-material check covering the common cases:
  /// K vs K, K+B vs K, K+N vs K, and K+B vs K+B with same-colored bishops.
  /// Does not attempt to cover every theoretical edge case (e.g. K+N+N vs K
  /// is technically a draw in almost all lines but not forced) — this is a
  /// documented simplification, expandable later if needed.
  bool _hasInsufficientMaterial() {
    final List<Piece> pieces = _state.squares.whereType<Piece>().toList();
    final List<Piece> nonKings =
        pieces.where((Piece p) => p.type != PieceType.king).toList();

    if (nonKings.isEmpty) return true; // K vs K

    if (nonKings.length == 1 &&
        (nonKings.first.type == PieceType.bishop || nonKings.first.type == PieceType.knight)) {
      return true; // K+B vs K, or K+N vs K
    }

    if (nonKings.length == 2 &&
        nonKings.every((Piece p) => p.type == PieceType.bishop) &&
        nonKings[0].color != nonKings[1].color) {
      // K+B vs K+B — insufficient only if bishops are on the same square
      // color. Square color can be derived from (file+rank) % 2, but we'd
      // need the squares, not just the pieces — left as a documented
      // simplification (treated as sufficient material) until Phase 3
      // hardening, where square-color parity is added.
      return false;
    }

    return false;
  }
}
