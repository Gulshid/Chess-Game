import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../core/constant/app_colors.dart';
import '../core/constant/app_constants.dart';
import '../features/account/presentation/auth_provider.dart';
import '../features/account/presentation/profile_screen.dart';
import '../features/advanced/domain/puzzle_bank.dart';
import '../features/advanced/presentation/analysis_board_screen.dart';
import '../features/advanced/presentation/puzzle_screen.dart';
import '../features/ai/presentation/new_game_dialog.dart';
import '../features/multiplayer/presentation/matchmaking_screen.dart';
import '../providers/game_provider.dart';
import 'game_screen.dart';

/// The app's landing screen: picks how to start a game and hands off to
/// [GameScreen]. Redesigned with a branded hero header (app mark + name,
/// finally shown on the very first screen) and a staggered fade/slide
/// entrance for the action list, on top of a layered gradient backdrop —
/// replacing the previous plain `Center` + flat button column.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Staggers [child]'s fade/slide-in by [index] out of a shared
  /// timeline, so the hero, then each menu item, settle in one after
  /// another instead of the whole screen popping in at once.
  Widget _staggered(int index, Widget child) {
    final double start = (0.08 * index).clamp(0.0, 0.7);
    final double end = (start + 0.4).clamp(0.0, 1.0);
    final CurvedAnimation curved = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * 18),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _startLocalGame(BuildContext context) async {
    context.read<GameProvider>().startGameVsAi(aiPlaysAs: null);
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  Future<void> _startAiGame(BuildContext context) async {
    final NewGameSelection? selection = await showNewGameDialog(context);
    if (selection == null || !context.mounted) return;
    context.read<GameProvider>().startGameVsAi(
          aiPlaysAs: selection.aiPlaysAs,
          difficulty: selection.difficulty,
        );
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final String emoji = auth.profile?.avatarEmoji ?? '♟️';
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: IconButton(
                  tooltip: 'Profile',
                  icon: auth.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          child: Text(emoji, style: const TextStyle(fontSize: 18)),
                        ),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                ),
              );
            },
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.heroGradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
            child: Column(
              children: [
                SizedBox(height: 12.h),
                _staggered(0, _HeroBadge()),
                SizedBox(height: 10.h),
                _staggered(
                  1,
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        const LinearGradient(colors: AppColors.goldGradient).createShader(bounds),
                    child: Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                _staggered(
                  2,
                  Text(
                    'Play a friend on this device, or challenge the AI.',
                    style: TextStyle(fontSize: 13.sp, color: Colors.white60),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 32.h),
                _staggered(
                  3,
                  _MenuCard(
                    icon: Icons.smart_toy_rounded,
                    title: 'Play vs AI',
                    subtitle: 'Pick a difficulty and colour',
                    accent: AppColors.seed,
                    filled: true,
                    onTap: () => _startAiGame(context),
                  ),
                ),
                SizedBox(height: 12.h),
                _staggered(
                  4,
                  _MenuCard(
                    icon: Icons.people_alt_rounded,
                    title: 'Local 2-player',
                    subtitle: 'Pass and play on this device',
                    accent: Colors.white,
                    onTap: () => _startLocalGame(context),
                  ),
                ),
                SizedBox(height: 12.h),
                _staggered(
                  5,
                  _MenuCard(
                    icon: Icons.public_rounded,
                    title: 'Play online',
                    subtitle: 'Find an opponent to match with',
                    accent: AppColors.accent,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MatchmakingScreen()),
                      );
                    },
                  ),
                ),
                SizedBox(height: 12.h),
                _staggered(
                  6,
                  _MenuCard(
                    icon: Icons.query_stats_rounded,
                    title: 'Analysis board',
                    subtitle: 'Explore positions move by move',
                    accent: Colors.white,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AnalysisBoardScreen()),
                      );
                    },
                  ),
                ),
                SizedBox(height: 12.h),
                _staggered(
                  7,
                  _MenuCard(
                    icon: Icons.extension_rounded,
                    title: 'Daily puzzle',
                    subtitle: 'A fresh tactic every day',
                    accent: AppColors.gold,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PuzzleScreen(puzzle: PuzzleBank.daily()),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small circular crown badge shown above the app name — echoes the
/// splash screen's mark so the two screens read as one brand moment
/// instead of the badge appearing out of nowhere on the splash then
/// never again.
class _HeroBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.goldGradient,
        ),
        boxShadow: [
          BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 1),
        ],
      ),
      child: Icon(Icons.grid_4x4_rounded, size: 34, color: AppColors.scaffoldBackground),
    );
  }
}

/// A tappable action card used for every entry on the start menu.
/// Replaces the old plain `FilledButton`/`OutlinedButton` column with a
/// consistent icon + title + subtitle row, a scale-down press animation,
/// and an accent-tinted icon chip so each destination reads distinctly
/// at a glance instead of everything being the same shape of button.
class _MenuCard extends StatefulWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: widget.filled
                ? AppColors.seed.withValues(alpha: 0.16)
                : AppColors.surface.withValues(alpha: 0.7),
            border: Border.all(
              color: widget.filled
                  ? AppColors.seed.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accent.withValues(alpha: 0.16),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }
}
