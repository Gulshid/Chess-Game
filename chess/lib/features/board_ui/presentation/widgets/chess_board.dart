import 'package:flutter/material.dart';

import '../../../../core/services/game_feedback_service.dart';
import '../../../../providers/game_provider.dart';
import '../../../chess_engine/domain/board_utils.dart';
import '../../../chess_engine/domain/game_status.dart';
import '../../../chess_engine/domain/models/board_state.dart';
import '../../../chess_engine/domain/models/move.dart';
import '../../../chess_engine/domain/models/piece.dart';
import '../../domain/board_theme.dart';
import 'chess_piece_widget.dart';
import 'promotion_picker.dart';

/// The interactive 8x8 board: square rendering, coordinate labels,
/// legal-move / selection / last-move / check highlighting, tap-to-move,
/// drag-and-drop, and animated piece movement between squares.
///
/// Deliberately takes [game] as an explicit parameter rather than reading
/// `GameProvider` via `Consumer` internally, so this widget's animation
/// bookkeeping (see [_PieceTracker] below) can hook `GameProvider`'s
/// `ChangeNotifier` listener directly instead of relying on rebuild
/// timing — that's what makes the "slide from A to B" animation exact
/// rather than approximate.
class ChessBoard extends StatefulWidget {
  const ChessBoard({
    super.key,
    required this.game,
    this.theme = BoardTheme.classicGreen,
    this.flipped = false,
    this.interactive = true,
    this.showCoordinates = true,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  final GameProvider game;
  final BoardTheme theme;

  /// True to show the board from Black's side (Black's back rank at the
  /// bottom).
  final bool flipped;

  /// False while it isn't the human's turn to move (e.g. AI thinking, or
  /// spectating) — squares stop responding to taps/drags.
  final bool interactive;
  final bool showCoordinates;

  /// Phase 11: whether a move/capture/check should play a system sound
  /// or trigger haptic feedback, respectively. Both default to `true` so
  /// existing call sites (and widget tests) that don't pass these keep
  /// working unchanged; [GameScreen] wires these through to the
  /// player's actual `AppSettings.soundEnabled`/`hapticsEnabled`
  /// preference. See [GameFeedbackService] for why the board itself
  /// takes plain booleans rather than reading settings directly.
  final bool soundEnabled;
  final bool hapticsEnabled;

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> with SingleTickerProviderStateMixin {
  final _PieceTracker _tracker = _PieceTracker();

  /// Drives the check-highlight's pulse (see [_CheckPulseHighlight]).
  /// Repeats for the lifetime of the board rather than being started/
  /// stopped per check: while no square is in check, this widget simply
  /// isn't placed on the board at all, so a free-running controller
  /// costs nothing extra and is simpler than starting/stopping it in
  /// sync with game state.
  late final AnimationController _checkPulseController;

  /// Captured pieces mid fade-out-and-shrink, keyed by a fresh id per
  /// capture so two captures in quick succession (rare, but possible via
  /// fast undo/redo) each get their own timer rather than one clobbering
  /// the other. Purely decorative — [_PieceTracker] has already dropped
  /// these from the live board by the time they land here.
  final Map<int, _CaptureGhost> _captureGhosts = <int, _CaptureGhost>{};
  int _nextGhostId = 0;

  @override
  void initState() {
    super.initState();
    _tracker.resync(widget.game.engine.state);
    widget.game.addListener(_handleGameChanged);
    _checkPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      oldWidget.game.removeListener(_handleGameChanged);
      widget.game.addListener(_handleGameChanged);
      _tracker.resync(widget.game.engine.state);
    }
  }

  @override
  void dispose() {
    widget.game.removeListener(_handleGameChanged);
    _checkPulseController.dispose();
    super.dispose();
  }

  void _handleGameChanged() {
    final GameProvider game = widget.game;
    final int newCount = game.moveHistory.length;

    if (newCount == _tracker.lastAppliedMoveCount + 1 && game.lastMove != null) {
      final Move applied = game.lastMove!;
      if (applied.isCapture) {
        final int capturedSquare = applied.flag == MoveFlag.enPassant
            ? squareAt(fileOf(applied.to), rankOf(applied.from))
            : applied.to;
        final Piece? capturedPiece = _tracker.pieceAt(capturedSquare);
        if (capturedPiece != null) {
          _spawnCaptureGhost(capturedSquare, capturedPiece);
        }
      }
      _tracker.applyForward(applied, game.engine.state);
      _playFeedbackFor(applied, game.status);
    } else if (newCount != _tracker.lastAppliedMoveCount) {
      // Undo, redo-by-more-than-one, reset, or a freshly loaded FEN: not
      // worth reconstructing an animated path for, so snap to the new
      // position instead of animating.
      _tracker.resync(game.engine.state);
    } else {
      // Selection-only change (no new/removed move) — nothing to re-sync.
      return;
    }
    _tracker.lastAppliedMoveCount = newCount;
    setState(() {});
  }

  /// Phase 11 sound/haptics: fires the right [GameFeedbackService] event
  /// for whatever [move] just happened. Checkmate is deliberately
  /// excluded from the check-sound branch here — [GameScreen]'s
  /// game-over dialog fires a distinct, louder game-end cue for that
  /// case via [GameFeedbackService.playGameEnd], and playing both would
  /// double up on a single move.
  void _playFeedbackFor(Move move, GameStatus statusAfterMove) {
    if (statusAfterMove == GameStatus.check) {
      GameFeedbackService.playCheck(
        soundEnabled: widget.soundEnabled,
        hapticsEnabled: widget.hapticsEnabled,
      );
    } else if (move.isCapture) {
      GameFeedbackService.playCapture(
        soundEnabled: widget.soundEnabled,
        hapticsEnabled: widget.hapticsEnabled,
      );
    } else if (move.isCastle) {
      GameFeedbackService.playCastle(
        soundEnabled: widget.soundEnabled,
        hapticsEnabled: widget.hapticsEnabled,
      );
    } else if (statusAfterMove != GameStatus.checkmate) {
      GameFeedbackService.playMove(
        soundEnabled: widget.soundEnabled,
        hapticsEnabled: widget.hapticsEnabled,
      );
    }
  }

  /// Puts a fading, shrinking "ghost" of a just-captured piece on
  /// [square] for a quarter second — a small but noticeable cue that a
  /// piece was *taken* rather than just having vanished, on top of the
  /// existing capture sound/haptic from [_playFeedbackFor].
  void _spawnCaptureGhost(int square, Piece piece) {
    final int id = _nextGhostId++;
    _captureGhosts[id] = _CaptureGhost(square: square, piece: piece);
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _captureGhosts.remove(id));
    });
  }

  Offset _cellForSquare(int square) {
    final int file = fileOf(square);
    final int rank = rankOf(square);
    final double col = (widget.flipped ? 7 - file : file).toDouble();
    final double row = (widget.flipped ? rank : 7 - rank).toDouble();
    return Offset(col, row);
  }

  void _handleSquareTap(int square) {
    if (!widget.interactive) return;
    final GameProvider game = widget.game;

    final int? selected = game.selectedSquare;
    if (selected == null) {
      game.selectSquare(square);
      return;
    }

    if (selected == square) {
      game.clearSelection();
      return;
    }

    final List<Move> candidates =
        game.movesFromSelected.where((Move m) => m.to == square).toList();

    if (candidates.isEmpty) {
      // Not a legal destination for the current selection — either
      // switch selection to a different own piece, or deselect.
      game.clearSelection();
      game.selectSquare(square);
      return;
    }

    _commitMove(square, candidates);
  }

  Future<void> _commitMove(int targetSquare, List<Move> candidates) async {
    final GameProvider game = widget.game;

    if (candidates.length > 1) {
      // Ambiguous only happens for same-square promotion choices.
      final PieceColor mover = game.sideToMove;
      final PieceType? chosen = await showPromotionPicker(context, color: mover);
      if (!mounted) return;
      if (chosen == null) {
        game.clearSelection();
        return;
      }
      game.moveSelectedTo(targetSquare, promotion: chosen);
      return;
    }

    game.moveSelectedTo(targetSquare);
  }

  @override
  Widget build(BuildContext context) {
    final GameProvider game = widget.game;
    final BoardTheme theme = widget.theme;
    final bool inCheck = game.status == GameStatus.check ||
        game.status == GameStatus.checkmate;
    final int? checkSquare = inCheck ? _findKingSquare(game) : null;
    final Move? lastMove = game.lastMove;
    final Set<int> legalTargets =
        game.movesFromSelected.map((Move m) => m.to).toSet();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double side = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final double squareSize = side / 8;

        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            children: [
              // --- Square backgrounds + coordinates ---
              // Wrapped in its own RepaintBoundary (Phase 11 performance
              // pass: "Profile and optimize board repaint performance").
              // This layer only changes on theme/flip/coordinate-toggle,
              // never on a move, so isolating it means a piece sliding
              // across the board doesn't force the checkerboard + labels
              // to repaint every animation frame alongside it.
              RepaintBoundary(
                child: CustomPaint(
                  size: Size(side, side),
                  painter: _BoardPainter(
                    theme: theme,
                    flipped: widget.flipped,
                    showCoordinates: widget.showCoordinates,
                  ),
                ),
              ),

              // --- Highlights: last move, selection, check ---
              for (int square = 0; square < 64; square++)
                if (square == game.selectedSquare ||
                    square == lastMove?.from ||
                    square == lastMove?.to ||
                    square == checkSquare)
                  _positionedSquare(
                    square: square,
                    squareSize: squareSize,
                    child: IgnorePointer(
                      // The king-in-check square pulses (Phase 11: "check
                      // indication (pulsing red)") instead of sitting at a
                      // flat tint — see [_CheckPulseHighlight].
                      child: square == checkSquare
                          ? _CheckPulseHighlight(
                              animation: _checkPulseController,
                              color: theme.checkHighlight,
                            )
                          : Container(
                              color: square == game.selectedSquare
                                  ? theme.selectedHighlight
                                  : theme.lastMoveHighlight,
                            ),
                    ),
                  ),

              // --- Legal move indicators ---
              for (final int target in legalTargets)
                _positionedSquare(
                  square: target,
                  squareSize: squareSize,
                  child: IgnorePointer(
                    child: Center(
                      // Pops in with a slight overshoot rather than
                      // appearing instantly — this widget only exists
                      // for the lifetime of the current selection, so
                      // the animation naturally replays each time a
                      // piece is selected.
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutBack,
                        builder: (context, t, child) =>
                            Transform.scale(scale: t.clamp(0, 1.15), child: child),
                        child: Container(
                          width: game.engine.state.pieceAt(target) == null
                              ? squareSize * 0.3
                              : squareSize * 0.86,
                          height: game.engine.state.pieceAt(target) == null
                              ? squareSize * 0.3
                              : squareSize * 0.86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: game.engine.state.pieceAt(target) == null
                                ? theme.legalMoveDot
                                : Colors.transparent,
                            border: game.engine.state.pieceAt(target) == null
                                ? null
                                : Border.all(color: theme.legalMoveDot, width: 3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // --- Tap targets (one per square, invisible) ---
              for (int square = 0; square < 64; square++)
                _positionedSquare(
                  square: square,
                  squareSize: squareSize,
                  child: DragTarget<int>(
                    onWillAcceptWithDetails: (details) => widget.interactive,
                    onAcceptWithDetails: (details) {
                      final int from = details.data;
                      widget.game.selectSquare(from);
                      final List<Move> candidates = widget.game.movesFromSelected
                          .where((Move m) => m.to == square)
                          .toList();
                      if (candidates.isEmpty) {
                        widget.game.clearSelection();
                        return;
                      }
                      _commitMove(square, candidates);
                    },
                    builder: (context, candidateData, rejectedData) {
                      // Phase 11 accessibility pass: "screen-reader
                      // labels." Each square announces its coordinate and
                      // occupant (e.g. "e4, White pawn" / "e5, empty") so
                      // a screen-reader user can navigate the board and
                      // hear what they're about to select or capture —
                      // information sighted players get for free from
                      // the rendered piece glyphs and coordinate labels.
                      return Semantics(
                        label: _squareSemanticsLabel(
                          square,
                          game.engine.state.pieceAt(square),
                        ),
                        selected: square == game.selectedSquare,
                        button: widget.interactive,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _handleSquareTap(square),
                        ),
                      );
                    },
                  ),
                ),

              // --- Pieces (animated) ---
              for (final _TrackedPiece tp in _tracker.pieces)
                AnimatedPositioned(
                  key: ValueKey<int>(tp.id),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  left: _cellForSquare(tp.square).dx * squareSize,
                  top: _cellForSquare(tp.square).dy * squareSize,
                  width: squareSize,
                  height: squareSize,
                  // Isolates each piece's own paint from every other
                  // piece and from the highlight/background layers below
                  // it — part of the same Phase 11 repaint-boundary pass
                  // as the board background above. A capture or a single
                  // piece sliding no longer forces all 32 pieces to
                  // repaint on every frame of that one animation.
                  child: RepaintBoundary(
                    child: _DraggablePiece(
                      piece: tp.piece,
                      square: tp.square,
                      size: squareSize,
                      interactive: widget.interactive &&
                          tp.piece.color == game.sideToMove &&
                          !game.isGameOver,
                      onDragStarted: () => widget.game.selectSquare(tp.square),
                    ),
                  ),
                ),

              // --- Capture ghosts (fading, on top of everything) ---
              for (final MapEntry<int, _CaptureGhost> entry in _captureGhosts.entries)
                _positionedSquare(
                  square: entry.value.square,
                  squareSize: squareSize,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey<int>(entry.key),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                      builder: (context, t, child) => Opacity(
                        opacity: 1 - t,
                        child: Transform.scale(scale: 1 + 0.35 * t, child: child),
                      ),
                      child: ChessPieceWidget(piece: entry.value.piece, size: squareSize),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _positionedSquare({
    required int square,
    required double squareSize,
    required Widget child,
  }) {
    final Offset cell = _cellForSquare(square);
    return Positioned(
      left: cell.dx * squareSize,
      top: cell.dy * squareSize,
      width: squareSize,
      height: squareSize,
      child: child,
    );
  }

  int? _findKingSquare(GameProvider game) {
    final PieceColor mover = game.sideToMove;
    for (int s = 0; s < 64; s++) {
      final Piece? p = game.engine.state.pieceAt(s);
      if (p != null && p.color == mover && p.type == PieceType.king) return s;
    }
    return null;
  }

  /// Builds the screen-reader announcement for [square] — see the
  /// `Semantics` call site above for why this exists.
  String _squareSemanticsLabel(int square, Piece? occupant) {
    final String coordinate = squareToAlgebraic(square);
    if (occupant == null) return '$coordinate, empty';
    final String colorName = occupant.color == PieceColor.white ? 'White' : 'Black';
    final String typeName = switch (occupant.type) {
      PieceType.pawn => 'pawn',
      PieceType.knight => 'knight',
      PieceType.bishop => 'bishop',
      PieceType.rook => 'rook',
      PieceType.queen => 'queen',
      PieceType.king => 'king',
    };
    return '$coordinate, $colorName $typeName';
  }
}

/// A piece that can be dragged (source of a [Draggable]) while also
/// rendering normally when not being dragged.
class _DraggablePiece extends StatelessWidget {
  const _DraggablePiece({
    required this.piece,
    required this.square,
    required this.size,
    required this.interactive,
    required this.onDragStarted,
  });

  final Piece piece;
  final int square;
  final double size;
  final bool interactive;
  final VoidCallback onDragStarted;

  @override
  Widget build(BuildContext context) {
    final Widget visual = ChessPieceWidget(piece: piece, size: size);

    if (!interactive) return IgnorePointer(child: visual);

    return Draggable<int>(
      data: square,
      onDragStarted: onDragStarted,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: size * 1.15,
          height: size * 1.15,
          child: ChessPieceWidget(piece: piece, size: size * 1.15, elevated: true),
        ),
      ),
      childWhenDragging: const SizedBox.shrink(),
      child: visual,
    );
  }
}

/// The king-in-check square's highlight pulses rather than sitting at a
/// flat opacity — "check indication (pulsing red)" per the roadmap's
/// Phase 11 polish list, and one more cue (alongside the sound/haptic
/// hit from [GameFeedbackService.playCheck]) that doesn't rely on a
/// player being able to distinguish this red tint by color alone.
///
/// Built as an [AnimatedWidget] driven by [_ChessBoardState]'s own
/// repeating [AnimationController] rather than an implicit animation:
/// implicit animations (e.g. `TweenAnimationBuilder`) run once per value
/// change and don't loop on their own, and this needs to pulse for as
/// long as the check highlight is on screen.
class _CheckPulseHighlight extends AnimatedWidget {
  const _CheckPulseHighlight({required Animation<double> animation, required this.color})
      : super(listenable: animation);

  final Color color;

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55 + 0.45 * _animation.value,
      child: Container(color: color),
    );
  }
}

/// Paints the 8x8 checkerboard background and coordinate labels. Split
/// out as a [CustomPainter] (rather than 64 `Container` widgets) since
/// the squares themselves never need independent widget identity or
/// animation — only the highlight and piece layers above do.
class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.theme,
    required this.flipped,
    required this.showCoordinates,
  });

  final BoardTheme theme;
  final bool flipped;
  final bool showCoordinates;

  @override
  void paint(Canvas canvas, Size size) {
    final double squareSize = size.width / 8;
    final Paint light = Paint()..color = theme.lightSquare;
    final Paint dark = Paint()..color = theme.darkSquare;

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final bool isLight = (row + col) % 2 == 0;
        final Rect rect = Rect.fromLTWH(
          col * squareSize,
          row * squareSize,
          squareSize,
          squareSize,
        );
        canvas.drawRect(rect, isLight ? light : dark);
      }
    }

    if (!showCoordinates) return;

    for (int col = 0; col < 8; col++) {
      final int file = flipped ? 7 - col : col;
      final String label = String.fromCharCode('a'.codeUnitAt(0) + file);
      final bool onLight = (7 + col) % 2 == 0;
      _paintLabel(
        canvas,
        label,
        Offset(col * squareSize + squareSize * 0.05, size.height - squareSize * 0.26),
        onLight ? theme.darkSquare : theme.lightSquare,
        squareSize * 0.16,
      );
    }
    for (int row = 0; row < 8; row++) {
      final int rank = flipped ? row + 1 : 8 - row;
      final bool onLight = (row + 0) % 2 == 0;
      _paintLabel(
        canvas,
        '$rank',
        Offset(size.width - squareSize * 0.24, row * squareSize + squareSize * 0.04),
        onLight ? theme.darkSquare : theme.lightSquare,
        squareSize * 0.16,
      );
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset offset, Color color, double fontSize) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.flipped != flipped ||
      oldDelegate.showCoordinates != showCoordinates;
}

/// Assigns and maintains stable per-piece identity across moves so
/// [AnimatedPositioned] can interpolate a piece's position from its old
/// square to its new one, instead of the piece appearing to vanish from
/// one square and materialize on another.
///
/// [BoardState] itself is a plain array-of-squares snapshot with no
/// concept of piece identity (by design — see its class doc), so this
/// tracker reconstructs identity by mirroring the exact same
/// capture/en-passant/castling logic `BoardState.applyMove` uses,
/// applied to whichever piece was on `move.from`.
class _PieceTracker {
  final Map<int, _TrackedPiece> _byId = <int, _TrackedPiece>{};
  final Map<int, int> _squareToId = <int, int>{};
  int _nextId = 0;
  int lastAppliedMoveCount = 0;

  List<_TrackedPiece> get pieces => _byId.values.toList(growable: false);

  /// The piece currently tracked on [square], or null if empty — read
  /// *before* [applyForward] mutates the tracker, so callers can see
  /// what's about to be captured.
  Piece? pieceAt(int square) {
    final int? id = _squareToId[square];
    if (id == null) return null;
    return _byId[id]?.piece;
  }

  void resync(BoardState state) {
    _byId.clear();
    _squareToId.clear();
    for (int s = 0; s < 64; s++) {
      final Piece? p = state.pieceAt(s);
      if (p != null) {
        final int id = _nextId++;
        _byId[id] = _TrackedPiece(id, s, p);
        _squareToId[s] = id;
      }
    }
  }

  void _removeAt(int square) {
    final int? id = _squareToId.remove(square);
    if (id != null) _byId.remove(id);
  }

  void _relocate(int fromSquare, int toSquare, Piece newPiece) {
    final int? id = _squareToId.remove(fromSquare);
    if (id == null) return; // Defensive: tracker desynced, next resync fixes it.
    final _TrackedPiece tp = _byId[id]!;
    tp.square = toSquare;
    tp.piece = newPiece;
    _squareToId[toSquare] = id;
  }

  void applyForward(Move move, BoardState state) {
    // Ordinary capture / promotion-capture: whatever sat on `to` is gone.
    _removeAt(move.to);

    if (move.flag == MoveFlag.enPassant) {
      final int capturedPawnSquare = squareAt(fileOf(move.to), rankOf(move.from));
      _removeAt(capturedPawnSquare);
    }

    final Piece landed = state.pieceAt(move.to)!;
    _relocate(move.from, move.to, landed);

    if (move.flag == MoveFlag.castleKingSide || move.flag == MoveFlag.castleQueenSide) {
      final int rank = rankOf(move.from);
      final bool kingSide = move.flag == MoveFlag.castleKingSide;
      final int rookFrom = squareAt(kingSide ? 7 : 0, rank);
      final int rookTo = squareAt(kingSide ? 5 : 3, rank);
      final Piece rook = state.pieceAt(rookTo)!;
      _relocate(rookFrom, rookTo, rook);
    }
  }
}

class _TrackedPiece {
  _TrackedPiece(this.id, this.square, this.piece);
  final int id;
  int square;
  Piece piece;
}

/// A just-captured piece mid fade-out, rendered by [_ChessBoardState]
/// for a quarter second on top of the normal piece layer. See
/// [_ChessBoardState._spawnCaptureGhost].
class _CaptureGhost {
  const _CaptureGhost({required this.square, required this.piece});
  final int square;
  final Piece piece;
}
