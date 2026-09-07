import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../chess_engine/domain/models/piece.dart';

/// Renders a single chess piece using the bundled "cburnett" SVG piece
/// set (`assets/pieces/cburnett/`) — the same widely-recognized Staunton
/// style used by most serious chess platforms. Crisp at any resolution
/// since it's vector art, not raster images.
///
/// Falls back to the original styled Unicode glyph rendering if an SVG
/// asset fails to load (e.g. `pubspec.yaml` hasn't been updated to
/// declare the `assets/pieces/cburnett/` folder yet), so the app never
/// shows a blank square while that's being wired up.
class ChessPieceWidget extends StatelessWidget {
  const ChessPieceWidget({
    super.key,
    required this.piece,
    required this.size,
    this.elevated = false,
  });

  final Piece piece;
  final double size;

  /// True while this piece is the one being dragged (rendered in the
  /// drag feedback) — adds a soft drop shadow so a lifted piece reads as
  /// physically above the board rather than just bigger.
  final bool elevated;

  static String _assetKeyFor(Piece piece) {
    final String colorPrefix = piece.color == PieceColor.white ? 'w' : 'b';
    final String typeLetter = switch (piece.type) {
      PieceType.king => 'K',
      PieceType.queen => 'Q',
      PieceType.rook => 'R',
      PieceType.bishop => 'B',
      PieceType.knight => 'N',
      PieceType.pawn => 'P',
    };
    return '$colorPrefix$typeLetter';
  }

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

  Widget _fallbackGlyph() {
    return Stack(
      alignment: Alignment.center,
      children: [
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final double padding = size * 0.09;
    final Widget svg = SvgPicture.asset(
      'assets/pieces/cburnett/${_assetKeyFor(piece)}.svg',
      width: size - padding * 2,
      height: size - padding * 2,
      placeholderBuilder: (context) => _fallbackGlyph(),
      errorBuilder: (context, error, stackTrace) => _fallbackGlyph(),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: size * 0.22,
                      offset: Offset(0, size * 0.10),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: size * 0.06,
                      offset: Offset(0, size * 0.03),
                    ),
                  ],
          ),
          child: svg,
        ),
      ),
    );
  }
}
