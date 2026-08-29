import 'board_utils.dart';
import 'fen.dart';
import 'game_status.dart';
import 'models/board_state.dart';
import 'models/move.dart';
import 'models/piece.dart';
import 'move_generator.dart';
import 'san.dart';

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

  /// Board-state history, one entry per ply played, used for undo and for
  /// threefold-repetition detection. `_history.last` is what `undoMove`
  /// restores.
  final List<BoardState> _history = <BoardState>[];

  /// The moves played, parallel to `_history` (`_moveHistory[i]` is the
  /// move that turned `_history[i]` into the state that followed it).
  /// Exposed for UI move-list panels and for highlighting the last move.
  final List<Move> _moveHistory = <Move>[];

  /// SAN strings, parallel to `_moveHistory` — computed once, at the
  /// moment each move is played, since SAN needs the *pre-move* position
  /// for disambiguation.
  final List<String> _sanHistory = <String>[];

  /// Redo stacks — populated by `undoMove`, drained by `redoMove`, and
  /// cleared by `makeMove` (playing a genuinely new move after undoing
  /// invalidates whatever was undone, same as every standard chess UI).
  final List<BoardState> _redoStates = <BoardState>[];
  final List<Move> _redoMoves = <Move>[];
  final List<String> _redoSans = <String>[];

  /// Repetition keys for every position reached so far (including the
  /// current one), used for threefold-repetition detection. A "position"
  /// for repetition purposes excludes the halfmove/fullmove counters —
  /// only piece placement, side to move, castling rights, and en passant
  /// target matter, per FIDE rules. Kept in sync with undo/redo so
  /// repetition detection doesn't drift after browsing history.
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

  /// The moves played so far, in order. Unmodifiable — callers get a
  /// snapshot, not a handle into engine internals.
  List<Move> get moveHistory => List<Move>.unmodifiable(_moveHistory);

  /// SAN strings for the moves played so far, in order (e.g. `['e4',
  /// 'e5', 'Nf3', ...]`). Parallel to [moveHistory].
  List<String> get sanHistory => List<String>.unmodifiable(_sanHistory);

  Move? get lastMove => _moveHistory.isEmpty ? null : _moveHistory.last;

  bool get canUndo => _history.isNotEmpty;

  bool get canRedo => _redoStates.isNotEmpty;

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

    if (_positionKeys.isEmpty) {
      _positionKeys.add(_repetitionKey(_state));
    }

    final String san = San.forMove(_state, move);

    _history.add(_state);
    _moveHistory.add(move);
    _sanHistory.add(san);

    // A genuinely new move invalidates any previously-undone future.
    _redoStates.clear();
    _redoMoves.clear();
    _redoSans.clear();

    _state = _state.applyMove(move);
    _positionKeys.add(_repetitionKey(_state));
    return true;
  }

  /// Undoes the last move, if any. Returns true if a move was undone.
  bool undoMove() {
    if (_history.isEmpty) return false;

    _redoStates.add(_state);
    _redoMoves.add(_moveHistory.removeLast());
    _redoSans.add(_sanHistory.removeLast());

    _state = _history.removeLast();
    if (_positionKeys.isNotEmpty) _positionKeys.removeLast();
    return true;
  }

  /// Re-applies the most recently undone move, if any. Returns true if a
  /// move was redone.
  bool redoMove() {
    if (_redoStates.isEmpty) return false;

    _history.add(_state);
    _moveHistory.add(_redoMoves.removeLast());
    _sanHistory.add(_redoSans.removeLast());

    _state = _redoStates.removeLast();
    _positionKeys.add(_repetitionKey(_state));
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

  /// Insufficient-material check covering: K vs K; K+B vs K; K+N vs K; and
  /// K+B vs K+B where both bishops sit on same-colored squares.
  ///
  /// Phase 2 shipped a simplified version of this that treated any K+B vs
  /// K+B as *sufficient* material regardless of bishop square color —
  /// documented at the time as a known gap. Phase 3 closes it: square
  /// color is `(file + rank) % 2` (0 = dark, 1 = light in this indexing),
  /// which only requires the *squares* the bishops sit on, not just the
  /// piece list — hence iterating `_state.squares` by index here instead
  /// of the old `whereType<Piece>()` list.
  bool _hasInsufficientMaterial() {
    final List<int> nonKingSquares = <int>[];
    for (int square = 0; square < 64; square++) {
      final Piece? piece = _state.squares[square];
      if (piece != null && piece.type != PieceType.king) {
        nonKingSquares.add(square);
      }
    }

    if (nonKingSquares.isEmpty) return true; // K vs K

    if (nonKingSquares.length == 1) {
      final PieceType onlyType = _state.squares[nonKingSquares.single]!.type;
      return onlyType == PieceType.bishop || onlyType == PieceType.knight;
    }

    if (nonKingSquares.length == 2) {
      final Piece a = _state.squares[nonKingSquares[0]]!;
      final Piece b = _state.squares[nonKingSquares[1]]!;
      final bool bothBishops = a.type == PieceType.bishop && b.type == PieceType.bishop;
      final bool oppositeColors = a.color != b.color;
      if (bothBishops && oppositeColors) {
        final int squareColorA =
            (fileOf(nonKingSquares[0]) + rankOf(nonKingSquares[0])) % 2;
        final int squareColorB =
            (fileOf(nonKingSquares[1]) + rankOf(nonKingSquares[1])) % 2;
        return squareColorA == squareColorB;
      }
    }

    return false;
  }
}
