import 'package:flutter/foundation.dart';

import '../features/chess_engine/domain/chess_engine.dart';
import '../features/chess_engine/domain/game_status.dart';
import '../features/chess_engine/domain/models/move.dart';
import '../features/chess_engine/domain/models/piece.dart';

/// The single source of truth for "what is the current game" from the
/// UI's point of view. Every screen that needs to read or mutate the
/// position goes through this provider rather than touching [ChessEngine]
/// directly.
///
/// This is a deliberately minimal slice of what full Phase 4 will cover
/// (move-history navigation, per-square selection state for the board
/// widget, etc.) — just enough to wire up `main.dart` and prove the
/// engine works end-to-end through Provider. It gets extended, not
/// replaced, when Phase 4/5 build the real board UI.
class GameProvider extends ChangeNotifier {
  GameProvider() : _engine = ChessEngine.initial();

  ChessEngine _engine;

  ChessEngine get engine => _engine;

  String get fen => _engine.fen;

  PieceColor get sideToMove => _engine.sideToMove;

  GameStatus get status => _engine.status;

  bool get isInCheck => _engine.isInCheck;

  List<Move> get legalMoves => _engine.allLegalMoves;

  List<Move> legalMovesFrom(int square) => _engine.legalMovesFrom(square);

  /// Attempts [move]. Returns true if it was legal and applied.
  bool makeMove(Move move) {
    final bool applied = _engine.makeMove(move);
    if (applied) notifyListeners();
    return applied;
  }

  bool undo() {
    final bool undone = _engine.undoMove();
    if (undone) notifyListeners();
    return undone;
  }

  /// Starts a brand new game from the standard starting position.
  void reset() {
    _engine = ChessEngine.initial();
    notifyListeners();
  }

  /// Loads an arbitrary position — used by the future analysis board
  /// (Phase 8) and puzzle mode, wired up early since it's a one-liner.
  void loadFen(String fen) {
    _engine = ChessEngine.fromFen(fen);
    notifyListeners();
  }
}
