import 'package:flutter/foundation.dart';

import '../features/chess_engine/domain/chess_engine.dart';
import '../features/chess_engine/domain/game_status.dart';
import '../features/chess_engine/domain/models/move.dart';
import '../features/chess_engine/domain/models/piece.dart';

/// The single source of truth for "what is the current game" from the
/// UI's point of view. Every screen goes through this provider rather
/// than touching [ChessEngine] directly — that boundary is what lets
/// Phase 6 (AI) and Phase 7 (multiplayer) plug in new move sources later
/// without any board-widget code changing.
///
/// Dependency injection note: the roadmap's Phase 4 calls for a DI
/// solution (get_it or Riverpod providers) so the engine is swappable and
/// testable. Since this project uses `provider` rather than Riverpod, that
/// need is met more simply: [ChessEngine] is injected through the
/// constructor (defaulting to a fresh game), so widget tests — or a
/// future "resume this server game" flow in Phase 7 — can hand in a
/// pre-built engine instance instead of adding a separate DI package.
class GameProvider extends ChangeNotifier {
  GameProvider({ChessEngine? engine}) : _engine = engine ?? ChessEngine.initial();

  ChessEngine _engine;

  /// The square currently selected as a move's origin, or null if nothing
  /// is selected. UI-only state — the engine itself has no concept of
  /// "selection", only positions and moves.
  int? _selectedSquare;
  List<Move> _movesFromSelected = const <Move>[];

  // ---------------------------------------------------------------------
  // Read-only game state (delegates straight to the engine)
  // ---------------------------------------------------------------------

  ChessEngine get engine => _engine;

  String get fen => _engine.fen;

  PieceColor get sideToMove => _engine.sideToMove;

  GameStatus get status => _engine.status;

  bool get isInCheck => _engine.isInCheck;

  List<Move> get legalMoves => _engine.allLegalMoves;

  List<Move> get moveHistory => _engine.moveHistory;

  List<String> get sanHistory => _engine.sanHistory;

  Move? get lastMove => _engine.lastMove;

  bool get canUndo => _engine.canUndo;

  bool get canRedo => _engine.canRedo;

  // ---------------------------------------------------------------------
  // Selection state (what Phase 5's board widget will drive)
  // ---------------------------------------------------------------------

  int? get selectedSquare => _selectedSquare;

  /// Legal destination squares for the currently-selected piece — the
  /// board widget uses this to draw move-dot highlights.
  List<Move> get movesFromSelected => _movesFromSelected;

  /// Selects [square] as a move's origin, if a piece belonging to the
  /// side to move is there. Selecting an empty square or an opponent's
  /// piece is a no-op (it does not clear an existing selection) — the UI
  /// is expected to call [clearSelection] explicitly, or call
  /// [moveSelectedTo] which clears it as a side effect either way.
  void selectSquare(int square) {
    final Piece? piece = _engine.state.pieceAt(square);
    if (piece == null || piece.color != _engine.sideToMove) return;

    _selectedSquare = square;
    _movesFromSelected = _engine.legalMovesFrom(square);
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedSquare == null) return;
    _selectedSquare = null;
    _movesFromSelected = const <Move>[];
    notifyListeners();
  }

  /// Attempts to move the currently-selected piece to [targetSquare].
  /// Returns true if a legal move was found and applied.
  ///
  /// [promotion] disambiguates which piece to promote to when more than
  /// one promotion option lands on the same [targetSquare] (queen,
  /// rook, bishop, knight all share a destination square). Defaults to
  /// queen — auto-queen is what nearly every chess UI does unless the
  /// player is explicitly offered a promotion picker (Phase 5).
  ///
  /// Clears the selection whether or not the move succeeds, since a tap
  /// on a square that isn't a legal destination should deselect, not
  /// leave a stale selection highlighted.
  bool moveSelectedTo(int targetSquare, {PieceType promotion = PieceType.queen}) {
    final int? origin = _selectedSquare;
    if (origin == null) return false;

    final List<Move> candidates =
        _movesFromSelected.where((Move m) => m.to == targetSquare).toList();

    _selectedSquare = null;
    _movesFromSelected = const <Move>[];

    if (candidates.isEmpty) {
      notifyListeners();
      return false;
    }

    final Move move = candidates.length == 1
        ? candidates.first
        : candidates.firstWhere(
            (Move m) => m.promotionType == promotion,
            orElse: () => candidates.first,
          );

    final bool applied = _engine.makeMove(move);
    notifyListeners();
    return applied;
  }

  // ---------------------------------------------------------------------
  // Direct move application / history navigation
  // ---------------------------------------------------------------------

  /// Applies [move] directly — used by the AI (Phase 6) and multiplayer
  /// (Phase 7) layers, which already have a concrete [Move] rather than
  /// a tapped square.
  bool makeMove(Move move) {
    final bool applied = _engine.makeMove(move);
    if (applied) {
      _selectedSquare = null;
      _movesFromSelected = const <Move>[];
      notifyListeners();
    }
    return applied;
  }

  void undo() {
    if (_engine.undoMove()) {
      _selectedSquare = null;
      _movesFromSelected = const <Move>[];
      notifyListeners();
    }
  }

  void redo() {
    if (_engine.redoMove()) {
      _selectedSquare = null;
      _movesFromSelected = const <Move>[];
      notifyListeners();
    }
  }

  /// Starts a brand new game from the standard starting position.
  void reset() {
    _engine = ChessEngine.initial();
    _selectedSquare = null;
    _movesFromSelected = const <Move>[];
    notifyListeners();
  }

  /// Loads an arbitrary position — used by the future analysis board
  /// (Phase 8) and puzzle mode.
  void loadFen(String fen) {
    _engine = ChessEngine.fromFen(fen);
    _selectedSquare = null;
    _movesFromSelected = const <Move>[];
    notifyListeners();
  }
}
