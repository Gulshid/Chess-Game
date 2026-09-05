import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../account/domain/rating.dart';
import '../../account/presentation/auth_provider.dart';
import '../../account/presentation/settings_provider.dart';
import '../data/firestore_multiplayer_repository.dart';
import '../data/multiplayer_repository.dart';
import '../domain/online_game.dart';
import '../domain/time_control.dart';
import 'online_game_screen.dart';

/// "Matchmaking queue (random opponent) and private game invites
/// (shareable game codes/links)" — Phase 7.
///
/// Owns its own [MultiplayerRepository] instance (a
/// [FirestoreMultiplayerRepository] by default) so this screen and
/// everything it pushes ([OnlineGameScreen]) work purely off dependency
/// injection through the constructor — a widget test can supply a fake
/// repository instead, per [MultiplayerRepository]'s own class doc.
class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key, MultiplayerRepository? repository})
      : repository = repository ?? const _LazyFirestoreRepository();

  final MultiplayerRepository repository;

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

/// Defers actually constructing [FirebaseFirestore.instance] /
/// [FirebaseAuth.instance] until a call is made — importing this screen
/// (e.g. from [StartScreen]) shouldn't throw if `Firebase.initializeApp`
/// hasn't run yet (see `main.dart`'s guarded init and
/// `FIREBASE_SETUP.md`); only actually trying to play online should.
class _LazyFirestoreRepository implements MultiplayerRepository {
  const _LazyFirestoreRepository();

  FirestoreMultiplayerRepository get _delegate => FirestoreMultiplayerRepository();

  @override
  String get currentUid => _delegate.currentUid;
  @override
  Future<void> ensureSignedIn() => _delegate.ensureSignedIn();
  @override
  Future<OnlineGame> createPrivateGame({
    required TimeControl timeControl,
    required String displayName,
    required int rating,
  }) =>
      _delegate.createPrivateGame(timeControl: timeControl, displayName: displayName, rating: rating);
  @override
  Future<OnlineGame> joinPrivateGame({
    required String code,
    required String displayName,
    required int rating,
  }) =>
      _delegate.joinPrivateGame(code: code, displayName: displayName, rating: rating);
  @override
  Future<OnlineGame> findQuickMatch({
    required TimeControl timeControl,
    required String displayName,
    required int rating,
  }) =>
      _delegate.findQuickMatch(timeControl: timeControl, displayName: displayName, rating: rating);
  @override
  Future<void> cancelQuickMatch() => _delegate.cancelQuickMatch();
  @override
  Future<String?> findCodeForGame(String gameId) => _delegate.findCodeForGame(gameId);
  @override
  Stream<OnlineGame> watchGame(String gameId) => _delegate.watchGame(gameId);
  @override
  Future<void> submitMove({
    required String gameId,
    required String uciMove,
    required String sanMove,
    required String resultingFen,
    required int remainingMs,
  }) =>
      _delegate.submitMove(
        gameId: gameId,
        uciMove: uciMove,
        sanMove: sanMove,
        resultingFen: resultingFen,
        remainingMs: remainingMs,
      );
  @override
  Future<void> resign({required String gameId}) => _delegate.resign(gameId: gameId);
  @override
  Future<void> offerDraw({required String gameId}) => _delegate.offerDraw(gameId: gameId);
  @override
  Future<void> respondToDrawOffer({required String gameId, required bool accept}) =>
      _delegate.respondToDrawOffer(gameId: gameId, accept: accept);
  @override
  Future<void> claimTimeout({required String gameId, required winner}) =>
      _delegate.claimTimeout(gameId: gameId, winner: winner);
  @override
  Future<void> reportGameOver({required String gameId, required status, required reason}) =>
      _delegate.reportGameOver(gameId: gameId, status: status, reason: reason);
  @override
  Future<void> sendHeartbeat({required String gameId}) => _delegate.sendHeartbeat(gameId: gameId);
  @override
  Future<void> leaveGame({required String gameId}) => _delegate.leaveGame(gameId: gameId);
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Player');
  final TextEditingController _codeController = TextEditingController();
  late TimeControl _selectedTimeControl;

  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Phase 9: prefill the display name from the signed-in profile
    // (rather than the "Player" placeholder every session used to
    // start with) and default the time control to the player's saved
    // preference — both editable here as before, this just picks a
    // better starting point.
    final String profileName = context.read<AuthProvider>().displayName;
    if (profileName.isNotEmpty && profileName != 'Player') {
      _nameController.text = profileName;
    }
    _selectedTimeControl = context.read<SettingsProvider>().settings.defaultTimeControl;
  }

  @override
  void dispose() {
    if (_isSearching) widget.repository.cancelQuickMatch();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _openGame(OnlineGame game) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(repository: widget.repository, gameId: game.id),
      ),
    );
  }

  Future<void> _quickMatch() async {
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final OnlineGame game = await widget.repository.findQuickMatch(
        timeControl: _selectedTimeControl,
        displayName: _nameController.text.trim().isEmpty ? 'Player' : _nameController.text.trim(),
        rating: context.read<AuthProvider>().profile?.rating ?? Rating.startingRating,
      );
      _openGame(game);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _error = 'Could not find a match: $e';
      });
    }
  }

  Future<void> _cancelSearch() async {
    await widget.repository.cancelQuickMatch();
    if (mounted) setState(() => _isSearching = false);
  }

  Future<void> _createPrivateGame() async {
    try {
      final OnlineGame game = await widget.repository.createPrivateGame(
        timeControl: _selectedTimeControl,
        displayName: _nameController.text.trim().isEmpty ? 'Player' : _nameController.text.trim(),
        rating: context.read<AuthProvider>().profile?.rating ?? Rating.startingRating,
      );
      if (!mounted) return;
      final String? code = await widget.repository.findCodeForGame(game.id);
      if (!mounted) return;
      if (code != null) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Share this code'),
            content: SelectableText(code, style: TextStyle(fontSize: 28.sp, letterSpacing: 4)),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Code copied')));
                },
                child: const Text('Copy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Waiting for opponent…'),
              ),
            ],
          ),
        );
      }
      _openGame(game);
    } catch (e) {
      setState(() => _error = 'Could not create game: $e');
    }
  }

  Future<void> _joinPrivateGame() async {
    final String code = _codeController.text.trim();
    if (code.isEmpty) return;
    try {
      final OnlineGame game = await widget.repository.joinPrivateGame(
        code: code,
        displayName: _nameController.text.trim().isEmpty ? 'Player' : _nameController.text.trim(),
        rating: context.read<AuthProvider>().profile?.rating ?? Rating.startingRating,
      );
      _openGame(game);
    } on GameNotFoundException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not join game: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Play online')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16.h),
              Text('Time control', style: TextStyle(fontSize: 13.sp, color: Colors.white70)),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  for (final TimeControl tc in TimeControl.presets)
                    ChoiceChip(
                      label: Text(tc.label),
                      selected: _selectedTimeControl.label == tc.label,
                      onSelected: (_) => setState(() => _selectedTimeControl = tc),
                    ),
                ],
              ),
              SizedBox(height: 24.h),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Color(0xFFE53935))),
                SizedBox(height: 12.h),
              ],
              if (_isSearching)
                // Keyed so Flutter tears this subtree down and builds a
                // fresh one instead of trying to reconcile it in place
                // against the very differently-shaped "else" branch below
                // (which has a focused TextField in it) — swapping
                // dissimilar subtrees at the same list position without a
                // key is what triggers the semantics
                // `!semantics.parentDataDirty` assertion some users hit
                // here; distinct keys make each branch its own Element so
                // the framework never tries to diff one against the other.
                KeyedSubtree(
                  key: const ValueKey('searching'),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      SizedBox(height: 12.h),
                      const Text('Searching for an opponent…'),
                      SizedBox(height: 12.h),
                      OutlinedButton(onPressed: _cancelSearch, child: const Text('Cancel')),
                    ],
                  ),
                )
              else
                KeyedSubtree(
                  key: const ValueKey('idle'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.bolt),
                        label: const Text('Quick match'),
                        onPressed: _quickMatch,
                      ),
                      SizedBox(height: 12.h),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.link),
                        label: const Text('Create private game'),
                        onPressed: _createPrivateGame,
                      ),
                      SizedBox(height: 20.h),
                      const Divider(),
                      SizedBox(height: 12.h),
                      Text(
                        'Join a private game',
                        style: TextStyle(fontSize: 13.sp, color: Colors.white70),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                hintText: '6-letter code',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          FilledButton(onPressed: _joinPrivateGame, child: const Text('Join')),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}