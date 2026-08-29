import 'package:flutter/foundation.dart';

import '../features/ai/data/ai_opponent.dart';
import '../features/ai/domain/ai_difficulty.dart';
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
  // AI opponent state (Phase 6). Null [_aiColor] means this is a local
  // pass-and-play game with no AI — [makeMove]/[moveSelectedTo] never
  // trigger a background search in that mode.
  // ---------------------------------------------------------------------

  PieceColor? _aiColor;
  AiDifficulty _aiDifficulty = AiDifficulty.medium;
  bool _isAiThinking = false;

  /// Which color the AI is playing, or null if there's no AI in this game.
  PieceColor? get aiColor => _aiColor;

  AiDifficulty get aiDifficulty => _aiDifficulty;

  /// True while a background search for the AI's move is in flight — the
  /// board widget uses this to disable input so the human can't move
  /// out of turn while the AI is "thinking".
  bool get isAiThinking => _isAiThinking;

  bool get isHumanTurnInAiGame => _aiColor == null || _aiColor != sideToMove;

  // ---------------------------------------------------------------------
  // Local resign / draw-by-agreement (Phase 5 controls, ahead of Phase 7
  // multiplayer where an opponent would actually need to be notified).
  // ---------------------------------------------------------------------

  /// Set by [resign] or [offerDraw]. [GameStatus] itself only knows about
  /// checkmate/stalemate/the three draw rules — it has no "resigned"
  /// state, and extending the engine's status enum for a UI-only concept
  /// would leak presentation concerns into `chess_engine/domain`. This
  /// stays provider-side instead; the UI checks it alongside
  /// [status.isGameOver].
  String? _gameOverOverrideMessage;

  String? get gameOverOverrideMessage => _gameOverOverrideMessage;

  bool get isGameOver => status.isGameOver || _gameOverOverrideMessage != null;

  /// The side to move resigns. There's no online opponent to notify yet
  /// (Phase 7), so this just ends the local game immediately.
  void resign() {
    if (isGameOver) return;
    final String winner = sideToMove == PieceColor.white ? 'Black' : 'White';
    _gameOverOverrideMessage = '$winner wins by resignation';
    notifyListeners();
  }

  /// Offers a draw. With no online opponent to decline it (Phase 7),
  /// this is accepted immediately — the same "nobody to say no" reason
  /// [GameControls]' doc explains for [resign].
  void offerDraw() {
    if (isGameOver) return;
    _gameOverOverrideMessage = 'Draw by agreement';
    notifyListeners();
  }

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
    if (applied) _maybeTriggerAiMove();
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
      _maybeTriggerAiMove();
    }
    return applied;
  }

  // ---------------------------------------------------------------------
  // AI opponent (Phase 6)
  // ---------------------------------------------------------------------

  /// Starts a fresh game with the AI playing [aiPlaysAs] at [difficulty].
  /// Pass `null` for [aiPlaysAs] to go back to a local two-player game.
  void startGameVsAi({
    required PieceColor? aiPlaysAs,
    AiDifficulty difficulty = AiDifficulty.medium,
  }) {
    _engine = ChessEngine.initial();
    _selectedSquare = null;
    _movesFromSelected = const <Move>[];
    _aiColor = aiPlaysAs;
    _aiDifficulty = difficulty;
    _isAiThinking = false;
    _gameOverOverrideMessage = null;
    notifyListeners();
    _maybeTriggerAiMove();
  }

  void setAiDifficulty(AiDifficulty difficulty) {
    _aiDifficulty = difficulty;
    notifyListeners();
  }

  /// Kicks off a background search if it's currently the AI's turn, the
  /// game isn't over, and a search isn't already running. Safe to call
  /// after every move — it's a no-op the rest of the time.
  void _maybeTriggerAiMove() {
    if (_aiColor == null) return;
    if (_isAiThinking) return;
    if (isGameOver) return;
    if (sideToMove != _aiColor) return;

    _isAiThinking = true;
    notifyListeners();

    final PieceColor requestedFor = _aiColor!;
    final String positionFen = fen;

    AiOpponent.findBestMove(fen: positionFen, difficulty: _aiDifficulty).then((Move? move) {
      _isAiThinking = false;

      // Guard against a stale result: if the user reset/loaded a new
      // position (or switched the AI off) while the search was running,
      // this response no longer applies to the current game.
      if (_aiColor != requestedFor || fen != positionFen) {
        notifyListeners();
        return;
      }

      if (move != null) {
        _engine.makeMove(move);
      }
      notifyListeners();
    }).catchError((Object error, StackTrace stackTrace) {
      // Defensive: a search failure shouldn't leave the board stuck with
      // "AI is thinking…" forever and no way to move.
      _isAiThinking = false;
      notifyListeners();
    });
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

  /// Starts a brand new game from the standard starting position,
  /// keeping whatever AI configuration (or lack of one) is already set —
  /// use [startGameVsAi] instead to also change who the AI plays as.
  void reset() {
    _engine = ChessEngine.initial();
    _selectedSquare = null;
    _movesFromSelected = const <Move>[];
    _isAiThinking = false;
    _gameOverOverrideMessage = null;
    notifyListeners();
    _maybeTriggerAiMove();
  }

  /// Loads an arbitrary position — used by the future analysis board
  /// (Phase 8) and puzzle mode. Turns off the AI opponent: an
  /// arbitrarily-loaded position is an analysis/setup action, not a
  /// move in an ongoing AI game.
  void loadFen(String fen) {
    _engine = ChessEngine.fromFen(fen);
    _selectedSquare = null;
    _movesFromSelected = const <Move>[];
    _aiColor = null;
    _isAiThinking = false;
    _gameOverOverrideMessage = null;
    notifyListeners();
  }
}
