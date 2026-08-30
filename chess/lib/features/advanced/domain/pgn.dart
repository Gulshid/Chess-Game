/// A parsed PGN game: header tag pairs plus the SAN moves in order.
///
/// Deliberately doesn't carry a result-derived [GameStatus] or a
/// resolved [Move] list itself — turning [sanMoves] into engine [Move]s
/// requires replaying them one at a time against a live position (see
/// `MoveResolver`), which is a job for the caller (the analysis board
/// provider), not this pure-text parser.
class ParsedPgn {
  const ParsedPgn({required this.headers, required this.sanMoves});

  final Map<String, String> headers;
  final List<String> sanMoves;

  String? get event => headers['Event'];
  String? get white => headers['White'];
  String? get black => headers['Black'];
  String? get result => headers['Result'];
  String? get date => headers['Date'];

  /// The starting position for this game, as a FEN, if the PGN carried a
  /// `[FEN "..."]` header (used for puzzle/position-setup exports where
  /// the game didn't start from the standard position). Null means
  /// "standard starting position".
  String? get startingFen => headers['SetUp'] == '1' ? headers['FEN'] : null;
}

/// Generates and parses Portable Game Notation (PGN) text.
///
/// Phase 0's tech-stack notes call for PGN support "from the very start"
/// of the engine (Phase 2), and it is — `ChessEngine.sanHistory` is the
/// per-move SAN list this class serializes. What Phase 2 didn't need was
/// full *file*-level PGN (the seven-tag header block, move-number
/// formatting, a parser for pasted-in games) since nothing consumed it
/// yet. That's this file's job, added here in Phase 8 alongside the
/// features that actually need it: sharing a finished game, and loading
/// someone else's game into the analysis board.
class Pgn {
  const Pgn._();

  /// The PGN "Seven Tag Roster" — every PGN-reading tool expects these
  /// tags to be present, in this order, even when the project doesn't
  /// track some of them yet (e.g. no ratings/tournament system before
  /// Phase 9) — hence the `Unknown`/`?` placeholders below rather than
  /// omitting the tag entirely.
  static String generate({
    required List<String> sanMoves,
    String event = 'Casual Game',
    String site = 'Flutter Chess',
    DateTime? date,
    String white = 'White',
    String black = 'Black',
    String result = '*',
    String? startingFen,
  }) {
    final DateTime d = date ?? DateTime.now();
    final String dateTag =
        '${d.year.toString().padLeft(4, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.day.toString().padLeft(2, '0')}';

    final StringBuffer out = StringBuffer();
    out.writeln('[Event "$event"]');
    out.writeln('[Site "$site"]');
    out.writeln('[Date "$dateTag"]');
    out.writeln('[Round "1"]');
    out.writeln('[White "$white"]');
    out.writeln('[Black "$black"]');
    out.writeln('[Result "$result"]');
    if (startingFen != null) {
      out.writeln('[SetUp "1"]');
      out.writeln('[FEN "$startingFen"]');
    }
    out.writeln();

    final StringBuffer moveText = StringBuffer();
    for (int i = 0; i < sanMoves.length; i++) {
      final bool isWhiteMove = i.isEven;
      if (isWhiteMove) {
        moveText.write('${(i ~/ 2) + 1}. ');
      }
      moveText.write(sanMoves[i]);
      moveText.write(' ');
    }
    moveText.write(result);

    out.write(_wrap(moveText.toString().trim(), 80));
    return out.toString();
  }

  /// Parses PGN text into header tags + an ordered SAN move list.
  ///
  /// This is intentionally forgiving about whitespace/line-wrapping (real
  /// PGN files wrap move text at an arbitrary column) but strict about
  /// stripping content it doesn't model: numeric move-number markers
  /// (`12.`, `12...`), inline `{comments}`, `(variations)`, and NAG
  /// glyphs (`$1`) are all discarded rather than preserved, since nothing
  /// downstream (the analysis board's linear replay) has anywhere to put
  /// them yet.
  ///
  /// Throws [FormatException] if no move text can be found at all.
  static ParsedPgn parse(String pgn) {
    final Map<String, String> headers = <String, String>{};
    final RegExp tagPattern = RegExp(r'^\s*\[(\w+)\s+"([^"]*)"\]\s*$', multiLine: true);
    for (final RegExpMatch match in tagPattern.allMatches(pgn)) {
      headers[match.group(1)!] = match.group(2)!;
    }

    String body = pgn.replaceAll(tagPattern, '');

    // Strip comments and (nested-once) variations — a full recursive
    // parser isn't warranted for a hand-typed/pasted casual game.
    body = body.replaceAll(RegExp(r'\{[^}]*\}'), '');
    body = body.replaceAll(RegExp(r'\([^()]*\)'), '');
    body = body.replaceAll(RegExp(r'\$\d+'), '');

    final List<String> tokens = body.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    const Set<String> resultTokens = <String>{'1-0', '0-1', '1/2-1/2', '*'};
    final List<String> sanMoves = <String>[];
    for (final String token in tokens) {
      if (resultTokens.contains(token)) continue;
      // Move-number markers: "1.", "12...", "1.e4" (no space after dot).
      final String withoutNumber = token.replaceFirst(RegExp(r'^\d+\.+'), '');
      if (withoutNumber.isEmpty) continue;
      sanMoves.add(withoutNumber);
    }

    if (sanMoves.isEmpty && headers.isEmpty) {
      throw const FormatException('No PGN header tags or move text found.');
    }

    return ParsedPgn(headers: headers, sanMoves: sanMoves);
  }

  static String _wrap(String text, int width) {
    final List<String> words = text.split(' ');
    final StringBuffer out = StringBuffer();
    int lineLength = 0;
    for (final String word in words) {
      if (lineLength + word.length + 1 > width) {
        out.writeln();
        lineLength = 0;
      } else if (lineLength > 0) {
        out.write(' ');
        lineLength++;
      }
      out.write(word);
      lineLength += word.length;
    }
    return out.toString();
  }
}
