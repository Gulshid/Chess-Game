import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../advanced/presentation/analysis_board_screen.dart';
import '../data/firestore_saved_games_repository.dart';
import '../data/hive_cached_saved_games_repository.dart';
import '../data/saved_games_repository.dart';
import '../domain/saved_game.dart';
import 'auth_provider.dart';

/// "Cloud save for game history ... with local caching for offline
/// access" (Phase 9) — lists every [SavedGame] for the signed-in uid,
/// most recent first, and opens any of them in [AnalysisBoardScreen]
/// for review.
class SavedGamesScreen extends StatefulWidget {
  const SavedGamesScreen({super.key, SavedGamesRepository? repository})
      : repository = repository ??
            const _LazySavedGamesRepository();

  final SavedGamesRepository repository;

  @override
  State<SavedGamesScreen> createState() => _SavedGamesScreenState();
}

/// Same lazy-construction trick [MatchmakingScreen] uses for its
/// repository — see that class's `_LazyFirestoreRepository` doc for why
/// (importing this screen shouldn't require Firebase to already be
/// initialized).
class _LazySavedGamesRepository implements SavedGamesRepository {
  const _LazySavedGamesRepository();

  SavedGamesRepository get _delegate =>
      HiveCachedSavedGamesRepository(cloud: FirestoreSavedGamesRepository());

  @override
  Future<void> saveGame(String uid, SavedGame game) => _delegate.saveGame(uid, game);
  @override
  Stream<List<SavedGame>> watchGames(String uid) => _delegate.watchGames(uid);
  @override
  Future<void> deleteGame(String uid, String gameId) => _delegate.deleteGame(uid, gameId);
}

class _SavedGamesScreenState extends State<SavedGamesScreen> {
  String? _streamUid;
  Stream<List<SavedGame>>? _stream;

  Stream<List<SavedGame>> _streamFor(String uid) {
    // Cached per uid rather than called fresh from `build` — a plain
    // `widget.repository.watchGames(uid)` inline in `StreamBuilder`
    // would open a brand-new stream (and Hive/Firestore subscription)
    // on every rebuild this screen gets from `context.watch<AuthProvider>()`
    // below, which would flash the loading state each time.
    if (_streamUid != uid) {
      _streamUid = uid;
      _stream = widget.repository.watchGames(uid);
    }
    return _stream!;
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = context.watch<AuthProvider>().user?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved games')),
      body: SafeArea(
        child: uid == null
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<List<SavedGame>>(
                stream: _streamFor(uid),
                builder: (context, snapshot) {
                  final List<SavedGame> games = snapshot.data ?? const <SavedGame>[];
                  if (snapshot.connectionState == ConnectionState.waiting && games.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (games.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Text(
                          'No saved games yet — finished games are saved here automatically.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.sp, color: Colors.white70),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: games.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final SavedGame game = games[index];
                      return Dismissible(
                        key: ValueKey(game.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: const Color(0xFFE53935),
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) => widget.repository.deleteGame(uid, game.id),
                        child: ListTile(
                          leading: _OutcomeBadge(outcome: game.outcome),
                          title: Text(game.opponentLabel),
                          subtitle: Text(
                            '${_sourceLabel(game.source)} · ${game.moveCount} moves · '
                            '${_formatDate(game.playedAtEpochMs)}',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AnalysisBoardScreen(initialPgn: game.pgn),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  String _sourceLabel(SavedGameSource source) => switch (source) {
        SavedGameSource.local => 'Local 2-player',
        SavedGameSource.ai => 'vs. AI',
        SavedGameSource.online => 'Online',
        SavedGameSource.puzzle => 'Puzzle',
      };

  String _formatDate(int epochMs) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(epochMs);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge({required this.outcome});
  final SavedGameOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (outcome) {
      SavedGameOutcome.win => (Icons.emoji_events_outlined, const Color(0xFF00C853)),
      SavedGameOutcome.loss => (Icons.close, const Color(0xFFE53935)),
      SavedGameOutcome.draw => (Icons.remove, const Color(0xFFFFC107)),
      SavedGameOutcome.unknown => (Icons.remove_red_eye_outlined, Colors.white54),
    };
    return CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color));
  }
}
