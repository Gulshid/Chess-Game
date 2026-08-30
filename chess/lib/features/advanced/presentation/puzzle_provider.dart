import 'dart:async';

import '../../chess_engine/domain/chess_engine.dart';
import '../../chess_engine/domain/models/move.dart';
import '../../chess_engine/domain/models/piece.dart';
import '../../../providers/game_provider.dart';
import '../domain/move_resolver.dart';
import '../domain/puzzle.dart';

enum PuzzleStatus { inProgress, solved, failed }

/// Drives puzzle mode: "Daily puzzle mode using tactic positions" plus
/// "Puzzle rating system ... to track player improvement" (Phase 8).
///
/// Subclasses [GameProvider] for the same reason `AnalysisProvider`
/// (also Phase 8) and `OnlineGameProvider` (Phase 7) do — see either of
/// those class docs. Here specifically it means [ChessBoard] gets full
/// drag/tap-to-move interaction for free, with this class only needing
/// to *veto* the move if it doesn't match the puzzle's solution, rather
/// than reimplement move input.
class PuzzleProvider extends GameProvider {
  PuzzleProvider(this.puzzle) : super(engine: ChessEngine.fromFen(puzzle.fen));

  final Puzzle puzzle;

  int _solvedPlyCount = 0;
  PuzzleStatus _puzzleStatus = PuzzleStatus.inProgress;
  Timer? _autoReplyTimer;

  int get solvedPlyCount => _solvedPlyCount;

  /// Named `puzzleStatus` rather than `status` — [GameProvider] already
  /// declares a `status` getter returning `GameStatus` (checkmate/
  /// stalemate/etc. — chess_engine's status). Reusing that name here
  /// with a different return type (`PuzzleStatus`) would be an invalid
  /// override, since Dart requires an override's return type to be
  /// compatible with the member it overrides.
  PuzzleStatus get puzzleStatus => _puzzleStatus;

  /// The side the *player* is solving as — the side to move in the
  /// puzzle's starting FEN.
  late final PieceColor playerColor = engine.sideToMove;

  void resetPuzzle() {
    _autoReplyTimer?.cancel();
    loadFen(puzzle.fen);
    _solvedPlyCount = 0;
    _puzzleStatus = PuzzleStatus.inProgress;
    notifyListeners();
  }

  void requestHint() {
    // A puzzle hint just re-selects the correct origin square, the same
    // "let the existing legal-move dots do the pointing" approach
    // `HintButton` uses for live games — no bespoke arrow overlay needed.
    if (_puzzleStatus != PuzzleStatus.inProgress) return;
    final String? uci = puzzle.nextPlayerMove(_solvedPlyCount);
    if (uci == null) return;
    final Move? move = MoveResolver.fromUci(engine.state, uci);
    if (move != null) selectSquare(move.from);
  }

  @override
  bool moveSelectedTo(int targetSquare, {PieceType promotion = PieceType.queen}) {
    if (_puzzleStatus != PuzzleStatus.inProgress) return false;

    final List<Move> candidates =
        movesFromSelected.where((Move m) => m.to == targetSquare).toList();
    if (candidates.isEmpty) {
      // Not a legal destination at all — let the base class handle
      // clearing the selection, same as a normal misclick.
      return super.moveSelectedTo(targetSquare, promotion: promotion);
    }

    final Move attempted = candidates.length == 1
        ? candidates.first
        : candidates.firstWhere(
            (Move m) => m.promotionType == promotion,
            orElse: () => candidates.first,
          );

    final String? expectedUci = puzzle.nextPlayerMove(_solvedPlyCount);

    if (expectedUci == null || attempted.uci != expectedUci) {
      // Wrong move: don't apply it, don't touch the position, just clear
      // the selection and mark the attempt failed so the UI can show
      // "not quite" — [resetPuzzle] (a "try again" button) lets the
      // player retry from the same starting position.
      clearSelection();
      _puzzleStatus = PuzzleStatus.failed;
      notifyListeners();
      return false;
    }

    final bool applied = super.moveSelectedTo(targetSquare, promotion: promotion);
    if (!applied) return false; // Shouldn't happen — attempted was legal.

    _solvedPlyCount++;
    _maybePlayForcedReplyOrFinish();
    return true;
  }

  /// After a correct player move, if the puzzle's solution has a forced
  /// opponent reply next (an even-length solution — see [Puzzle]'s class
  /// doc), plays it automatically on a short delay so it reads as "the
  /// opponent responds", then checks whether the whole line is solved.
  void _maybePlayForcedReplyOrFinish() {
    final String? replyUci = puzzle.nextPlayerMove(_solvedPlyCount);
    if (replyUci == null) {
      _puzzleStatus = PuzzleStatus.solved;
      notifyListeners();
      return;
    }

    _autoReplyTimer?.cancel();
    _autoReplyTimer = Timer(const Duration(milliseconds: 400), () {
      final Move? reply = MoveResolver.fromUci(engine.state, replyUci);
      if (reply != null) {
        super.makeMove(reply);
        _solvedPlyCount++;
      }
      final bool done = puzzle.nextPlayerMove(_solvedPlyCount) == null;
      if (done) _puzzleStatus = PuzzleStatus.solved;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _autoReplyTimer?.cancel();
    super.dispose();
  }
}