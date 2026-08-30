import '../../../core/constant/app_constants.dart';
import '../../../providers/game_provider.dart';
import '../../chess_engine/domain/chess_engine.dart';
import '../../chess_engine/domain/models/move.dart';
import '../../chess_engine/domain/models/piece.dart';
import '../domain/eval_service.dart';
import '../domain/move_resolver.dart';
import '../domain/pgn.dart';

/// Drives the Phase 8 analysis board: "step through any game, branch
/// into variations, run engine evaluation per move."
///
/// Subclasses [GameProvider] rather than duplicating it, for the same
/// reason `OnlineGameProvider` (Phase 7) does: [GameProvider] already
/// owns exactly the state a board needs (engine, selection, move
/// application) and — per its own class doc — was deliberately kept
/// swappable so new move sources could plug in "without any board-widget
/// code changing." That means [ChessBoard], [MoveHistoryPanel],
/// [CapturedPiecesTray], and [GameControls] all work against this
/// provider completely unmodified.
///
/// Variation handling: this implements *linear* browsing with the
/// ability to deviate (undo back into the game, then play a different
/// move, which discards the original continuation from that point) —
/// covers the common "what if I'd played X instead" case. A full
/// multi-branch variation *tree* (keeping the original continuation
/// alongside the new one, the way a PGN with `(...)` sidelines works) is
/// a natural next step but a materially bigger data-model change,
/// deliberately left out here rather than half-implemented.
class AnalysisProvider extends GameProvider {
  AnalysisProvider({String? startingFen})
      : _startingFen = startingFen,
        super(engine: startingFen == null ? null : ChessEngine.fromFen(startingFen)) {
    _recomputeEval();
  }

  String? _startingFen;

  int? _evalCentipawns;
  bool _evalLoading = false;
  int _evalRequestId = 0;
  bool _disposed = false;

  /// White-relative centipawn evaluation of the current position, or
  /// null while the first evaluation is still in flight.
  int? get evalCentipawns => _evalCentipawns;

  bool get isEvalLoading => _evalLoading;

  /// Loads a full game (e.g. from a parsed PGN or a just-finished match)
  /// and leaves the board at the final position — call [jumpToStart] to
  /// begin stepping through it from move 1.
  void loadGame(List<Move> moves, {String? startingFen}) {
    _startingFen = startingFen;
    // Uses the inherited (super) setters while replaying so only the
    // final position triggers an eval request — this may replay dozens
    // of moves in one call, and there is no reason to spawn an isolate
    // for every intermediate one the user will never actually see.
    super.loadFen(startingFen ?? _defaultStartingFen);
    for (final Move move in moves) {
      final bool applied = super.makeMove(move);
      if (!applied) break; // Defensive: stop rather than corrupt state.
    }
    _recomputeEval();
  }

  /// Parses [pgnText] and loads it as the active game.
  /// Throws [FormatException] if the PGN's move text doesn't resolve to
  /// legal moves from its (or the standard) starting position.
  void loadPgn(String pgnText) {
    final ParsedPgn parsed = Pgn.parse(pgnText);
    final String startFen = parsed.startingFen ?? _defaultStartingFen;

    ChessEngine replay = ChessEngine.fromFen(startFen);
    final List<Move> resolved = <Move>[];
    for (final String san in parsed.sanMoves) {
      final Move? move = MoveResolver.fromSan(replay.state, san);
      if (move == null) {
        throw FormatException('Could not resolve move "$san" against the position.');
      }
      replay.makeMove(move);
      resolved.add(move);
    }

    loadGame(resolved, startingFen: parsed.startingFen);
  }

  /// The current game as PGN text, using [white]/[black]/[event] header
  /// values supplied by the caller (the screen prompts for these, or
  /// falls back to generic placeholders).
  String exportPgn({String white = 'White', String black = 'Black', String event = 'Analysis'}) {
    return Pgn.generate(
      sanMoves: sanHistory,
      white: white,
      black: black,
      event: event,
      startingFen: _startingFen,
      result: '*',
    );
  }

  void jumpToStart() {
    while (canUndo) {
      undo();
    }
  }

  void jumpToEnd() {
    while (canRedo) {
      redo();
    }
  }

  /// Jumps directly to the position after ply [plyIndex] (0-based,
  /// matching [moveHistory]'s indexing) has been played, from wherever
  /// the browser currently sits — used by the move-list panel's
  /// tap-to-jump.
  void jumpToPly(int plyIndex) {
    // Walk back to the start of the *known* line first: undo/redo only
    // move within moves already recorded (main line + whatever's been
    // redone), which is exactly the range a tap target can reference.
    while (moveHistory.length - 1 > plyIndex && canUndo) {
      undo();
    }
    while (moveHistory.length - 1 < plyIndex && canRedo) {
      redo();
    }
  }

  static const String _defaultStartingFen = AppConstants.startingFen;

  @override
  bool makeMove(Move move) {
    final bool applied = super.makeMove(move);
    if (applied) _recomputeEval();
    return applied;
  }

  /// [GameProvider.moveSelectedTo] (tap/drag-to-move on the board)
  /// applies moves straight against the engine rather than routing
  /// through [makeMove], so it needs its own override here too — the
  /// eval bar should update for a board tap exactly the same way it
  /// does for a programmatically-applied move.
  @override
  bool moveSelectedTo(int targetSquare, {PieceType promotion = PieceType.queen}) {
    final int before = moveHistory.length;
    final bool applied = super.moveSelectedTo(targetSquare, promotion: promotion);
    if (moveHistory.length != before) _recomputeEval();
    return applied;
  }

  @override
  void undo() {
    final int before = moveHistory.length;
    super.undo();
    if (moveHistory.length != before) _recomputeEval();
  }

  @override
  void redo() {
    final int before = moveHistory.length;
    super.redo();
    if (moveHistory.length != before) _recomputeEval();
  }

  @override
  void loadFen(String fen) {
    super.loadFen(fen);
    _recomputeEval();
  }

  void _recomputeEval() {
    final int requestId = ++_evalRequestId;
    _evalLoading = true;
    notifyListeners();

    EvalService.evaluateFen(fen).then((int score) {
      // The isolate call can't be cancelled once started (see
      // `EvalService`) — if the screen was popped and this provider
      // disposed while it was in flight, its result must simply be
      // discarded rather than calling `notifyListeners` on a disposed
      // `ChangeNotifier`, which throws in debug builds.
      if (_disposed) return;
      if (requestId != _evalRequestId) return; // stale — position moved on
      _evalCentipawns = score;
      _evalLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
