import 'package:flutter/material.dart';

import '../../../chess_engine/domain/models/piece.dart';

/// Renders a single chess piece.
///
/// The roadmap recommends "high-quality SVG piece sets for crisp
/// rendering at any resolution." No asset pack shipped with this
/// project, so this widget renders pieces as styled Unicode chess
/// glyphs (crisp at any size since they're text, not raster images) —
/// functionally and visually correct today, and a single drop-in swap
/// point for real SVGs later:
///
///   To switch to an SVG piece set, replace the `Text(glyph)` below with
///   `SvgPicture.asset('assets/pieces/$setName/${piece.fenChar}.svg')`
///   (flutter_svg) and delete `_glyphFor`/`_outlineColorFor`. Everything
///   else that depends on this widget (ChessBoard, drag feedback,
///   captured-pieces tray) is unaffected because they only ever pass a
///   [Piece] and a size in.
class ChessPieceWidget extends StatelessWidget {
  const ChessPieceWidget({
    super.key,
    required this.piece,
    required this.size,
  });

  final Piece piece;
  final double size;

  /// Unicode chess symbols. Using the white-piece glyphs for both colors
  /// and coloring them via [_fillColorFor]/[_outlineColorFor] (instead of
  /// mixing white/black glyph codepoints) gives more consistent glyph
  /// shapes across platform fonts.
  static String _glyphFor(PieceType type) => switch (type) {
        PieceType.king => '♔',
        PieceType.queen => '♕',
        PieceType.rook => '♖',
        PieceType.bishop => '♗',
        PieceType.knight => '♘',
        PieceType.pawn => '♙',
      };

  Color _fillColorFor(PieceColor color) =>
      color == PieceColor.white ? const Color(0xFFFAFAFA) : const Color(0xFF1B1B1B);

  Color _outlineColorFor(PieceColor color) =>
      color == PieceColor.white ? const Color(0xFF1B1B1B) : const Color(0xFFFAFAFA);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outline pass: paint the glyph 4x offset in the outline
            // color to fake a stroke (Flutter's Text has no native
            // stroke-only paint mode without a custom painter).
            for (final Offset o in const <Offset>[
              Offset(-0.7, 0),
              Offset(0.7, 0),
              Offset(0, -0.7),
              Offset(0, 0.7),
            ])
              Transform.translate(
                offset: o,
                child: Text(
                  _glyphFor(piece.type),
                  style: TextStyle(
                    fontSize: size * 0.82,
                    height: 1,
                    color: _outlineColorFor(piece.color),
                  ),
                ),
              ),
            Text(
              _glyphFor(piece.type),
              style: TextStyle(
                fontSize: size * 0.82,
                height: 1,
                color: _fillColorFor(piece.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
