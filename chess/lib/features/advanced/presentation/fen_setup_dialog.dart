import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../chess_engine/domain/fen.dart';

/// "Position setup mode using FEN input" (Phase 8). A minimal dialog:
/// paste a FEN, validate it against the real parser, load it.
///
/// Validation reuses [Fen.parse] itself rather than a separate regex
/// check — the parser already throws a descriptive [FormatException] on
/// anything structurally wrong, so re-implementing that logic here would
/// just be a second, weaker copy of Phase 2's rules.
Future<String?> showFenSetupDialog(BuildContext context, {String? initialFen}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _FenSetupDialog(initialFen: initialFen),
  );
}

class _FenSetupDialog extends StatefulWidget {
  const _FenSetupDialog({this.initialFen});

  final String? initialFen;

  @override
  State<_FenSetupDialog> createState() => _FenSetupDialogState();
}

class _FenSetupDialogState extends State<_FenSetupDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialFen ?? '');
  String? _error;

  void _submit() {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter a FEN string.');
      return;
    }
    try {
      Fen.parse(text); // throws on anything structurally invalid
      Navigator.of(context).pop(text);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set up a position'),
      content: SizedBox(
        width: 420.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Paste any valid FEN to jump straight to that position — for '
                'setting up puzzles, studying an opening, or resuming a game '
                'from a book.',
                style: TextStyle(fontSize: 11.sp, color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Load position')),
      ],
    );
  }
}
