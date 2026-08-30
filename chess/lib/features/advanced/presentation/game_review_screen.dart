import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../chess_engine/domain/models/move.dart';
import '../domain/game_review_service.dart';
import '../domain/move_annotation.dart';

/// "Game review summary after each game highlighting blunders/mistakes/
/// good moves (using engine eval deltas)" — Phase 8.
///
/// Takes the already-played move list (from a just-finished `GameProvider`
/// game, or an imported PGN loaded into [AnalysisProvider]) and runs
/// [GameReviewService] over it, then shows a scorecard summary followed
/// by a tappable per-move timeline. Tapping a row opens the position in
/// the analysis board at that ply, which is the natural next step after
/// "show me where I went wrong."
class GameReviewScreen extends StatefulWidget {
  const GameReviewScreen({
    super.key,
    required this.moves,
    this.startingFen,
    required this.onOpenInAnalysis,
  });

  final List<Move> moves;
  final String? startingFen;
  final void Function(int plyIndex) onOpenInAnalysis;

  @override
  State<GameReviewScreen> createState() => _GameReviewScreenState();
}

class _GameReviewScreenState extends State<GameReviewScreen> {
  late final Future<List<AnnotatedMove>> _future = GameReviewService.review(
    moves: widget.moves,
    startingFen: widget.startingFen,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game review')),
      body: FutureBuilder<List<AnnotatedMove>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<AnnotatedMove> moves = snapshot.data!;
          return Column(
            children: [
              _Scorecard(moves: moves),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: moves.length,
                  itemBuilder: (context, i) => _MoveRow(
                    move: moves[i],
                    onTap: () => widget.onOpenInAnalysis(moves[i].plyIndex),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Scorecard extends StatelessWidget {
  const _Scorecard({required this.moves});

  final List<AnnotatedMove> moves;

  @override
  Widget build(BuildContext context) {
    final Map<MoveQuality, int> counts = <MoveQuality, int>{
      for (final MoveQuality q in MoveQuality.values) q: 0,
    };
    for (final AnnotatedMove m in moves) {
      counts[m.quality] = (counts[m.quality] ?? 0) + 1;
    }

    return Padding(
      padding: EdgeInsets.all(12.w),
      child: Wrap(
        spacing: 12.w,
        runSpacing: 8.h,
        children: [
          for (final MoveQuality q in MoveQuality.values)
            if (counts[q]! > 0)
              Chip(
                avatar: CircleAvatar(
                  backgroundColor: _colorFor(q),
                  radius: 8.w,
                ),
                label: Text('${q.label}: ${counts[q]}'),
              ),
        ],
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.move, required this.onTap});

  final AnnotatedMove move;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int moveNumber = move.plyIndex ~/ 2 + 1;
    final String prefix = move.isWhiteMove ? '$moveNumber.' : '$moveNumber...';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(backgroundColor: _colorFor(move.quality), radius: 14.w),
      title: Text('$prefix ${move.san}'),
      subtitle: Text(move.quality.label),
      trailing: move.centipawnLoss > 0
          ? Text('-${(move.centipawnLoss / 100).toStringAsFixed(1)}')
          : null,
    );
  }
}

Color _colorFor(MoveQuality q) => switch (q) {
      MoveQuality.best => const Color(0xFF00C853),
      MoveQuality.good => const Color(0xFF66BB6A),
      MoveQuality.inaccuracy => const Color(0xFFFFC107),
      MoveQuality.mistake => const Color(0xFFFF7043),
      MoveQuality.blunder => const Color(0xFFE53935),
    };
