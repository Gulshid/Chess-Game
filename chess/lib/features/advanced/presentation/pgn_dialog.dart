import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// "Full PGN import/export (with headers...)" (Phase 8).
///
/// One dialog handles both directions via two tabs rather than two
/// separate dialogs, since they share the same text-area-plus-copy/paste
/// shape and a player moving between "export this game" and "import a
/// different one" is a single, related task.
///
/// Export mode shows [exportText] read-only with a copy button. Import
/// mode is a free-text field whose content is handed back to the caller
/// via the returned Future when "Load game" is pressed — actually
/// parsing/validating the PGN is [AnalysisProvider.loadPgn]'s job, not
/// this dialog's, so a bad paste surfaces as a normal error snackbar on
/// the caller's side rather than duplicating parser logic here.
Future<String?> showPgnDialog(
  BuildContext context, {
  required String exportText,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PgnDialog(exportText: exportText),
  );
}

class _PgnDialog extends StatefulWidget {
  const _PgnDialog({required this.exportText});

  final String exportText;

  @override
  State<_PgnDialog> createState() => _PgnDialogState();
}

class _PgnDialogState extends State<_PgnDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final TextEditingController _importController = TextEditingController();

  @override
  void dispose() {
    _tabController.dispose();
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PGN'),
      content: SizedBox(
        width: 460.w,
        height: 360.h,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [Tab(text: 'Export'), Tab(text: 'Import')],
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ExportTab(text: widget.exportText),
                  _ImportTab(controller: _importController),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            if (_tabController.index != 1) return;
            final String text = _importController.text.trim();
            if (text.isEmpty) return;
            Navigator.of(context).pop(text);
          },
          child: const Text('Load game'),
        ),
      ],
    );
  }
}

class _ExportTab extends StatelessWidget {
  const _ExportTab({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: SingleChildScrollView(
              child: SelectableText(text, style: TextStyle(fontSize: 12.sp)),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copy to clipboard'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('PGN copied')));
            }
          },
        ),
      ],
    );
  }
}

class _ImportTab extends StatelessWidget {
  const _ImportTab({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'Paste PGN text here…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        SizedBox(height: 8.h),
        OutlinedButton.icon(
          icon: const Icon(Icons.paste),
          label: const Text('Paste from clipboard'),
          onPressed: () async {
            final ClipboardData? data = await Clipboard.getData('text/plain');
            if (data?.text != null) controller.text = data!.text!;
          },
        ),
      ],
    );
  }
}
