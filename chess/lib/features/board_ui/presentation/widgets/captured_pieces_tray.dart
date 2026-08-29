import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../providers/game_provider.dart';
import '../../../chess_engine/domain/models/piece.dart';
import 'chess_piece_widget.dart';

/// Shows the pieces [color] has captured so far, plus a "+N" material
/// advantage badge when that side is ahead on material.
///
/// Captured pieces are derived from the live board rather than tracked
/// as a running event log: for each piece type, count how many of the
/// *opponent's* pieces of that type remain on the board, and subtract
/// from the starting count of 8 pawns / 2 knights / 2 bishops / 2 rooks /
/// 1 queen. That's simpler than threading a "capture event" through
/// [GameProvider] and can never drift out of sync with undo/redo/loadFen,
/// since it's recomputed from the current position every time.
class CapturedPiecesTray extends StatelessWidget {
  const CapturedPiecesTray({super.key, required this.color, this.pieceSize = 18});

  /// The side whose captures are shown (i.e. pieces of the *opposite*
  /// color that are missing from the board).
  final PieceColor color;
  final double pieceSize;

  static const Map<PieceType, int> _startingCounts = <PieceType, int>{
    PieceType.pawn: 8,
    PieceType.knight: 2,
    PieceType.bishop: 2,
    PieceType.rook: 2,
    PieceType.queen: 1,
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        final PieceColor opponent = color.opposite;
        final Map<PieceType, int> remaining = <PieceType, int>{
          for (final PieceType t in _startingCounts.keys) t: 0,
        };

        for (int s = 0; s < 64; s++) {
          final Piece? p = game.engine.state.pieceAt(s);
          if (p != null && p.color == opponent && _startingCounts.containsKey(p.type)) {
            remaining[p.type] = (remaining[p.type] ?? 0) + 1;
          }
        }

        int materialForSide(PieceColor side) {
          int total = 0;
          for (int s = 0; s < 64; s++) {
            final Piece? p = game.engine.state.pieceAt(s);
            if (p != null && p.color == side) total += p.type.value;
          }
          return total;
        }

        final int advantage = materialForSide(color) - materialForSide(opponent);

        final List<Widget> chips = <Widget>[];
        for (final PieceType type in const <PieceType>[
          PieceType.queen,
          PieceType.rook,
          PieceType.bishop,
          PieceType.knight,
          PieceType.pawn,
        ]) {
          final int captured = _startingCounts[type]! - (remaining[type] ?? 0);
          for (int i = 0; i < captured; i++) {
            chips.add(
              Padding(
                padding: EdgeInsets.only(right: 1.w),
                child: ChessPieceWidget(piece: Piece(opponent, type), size: pieceSize.w),
              ),
            );
          }
        }

        return Row(
          children: [
            Expanded(
              child: Wrap(children: chips),
            ),
            if (advantage > 0)
              Padding(
                padding: EdgeInsets.only(left: 4.w),
                child: Text(
                  '+$advantage',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
