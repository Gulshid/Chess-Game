import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constant/app_colors.dart';
import '../domain/user_profile.dart';
import 'auth_provider.dart';
import 'leaderboard_screen.dart';
import 'saved_games_screen.dart';
import 'settings_screen.dart';
import 'sign_in_screen.dart';

/// "User profile: avatar, username, rating, game statistics
/// (wins/losses/draws)" (Phase 9) — the account hub screen, also
/// linking out to [SavedGamesScreen], [LeaderboardScreen], and
/// [SettingsScreen] so this doubles as the app's account/settings
/// entry point from [StartScreen].
///
/// Visual pass only: a gold-ringed avatar on a gradient backdrop, stat
/// tiles with icons instead of plain numbers, and the same rounded
/// "surface card" grouping used on [SettingsScreen] for the navigation
/// rows. All the underlying [AuthProvider] calls are unchanged.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      context.read<AuthProvider>().updateDisplayName(name);
    }
  }

  Future<void> _pickAvatar(BuildContext context) async {
    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final String emoji in AvatarEmojis.all)
                IconButton(
                  iconSize: 32.sp,
                  onPressed: () => Navigator.of(context).pop(emoji),
                  icon: Text(emoji, style: TextStyle(fontSize: 28.sp)),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && context.mounted) {
      context.read<AuthProvider>().updateAvatar(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final UserProfile? profile = auth.profile;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
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
            child: auth.isLoading || profile == null
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 24.h),
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: () => _pickAvatar(context),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: AppColors.goldGradient),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.gold.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 44.r,
                                backgroundColor: AppColors.surface,
                                child: Text(profile.avatarEmoji, style: TextStyle(fontSize: 40.sp)),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => _editName(context, profile.displayName),
                            icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white70),
                            label: Text(
                              profile.displayName,
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (profile.isAnonymous)
                          Center(
                            child: Text(
                              'Playing as a guest — progress is only on this device.',
                              style: TextStyle(fontSize: 12.sp, color: Colors.white54),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(height: 24.h),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.military_tech_rounded,
                                label: 'Rating',
                                value: '${profile.rating}',
                                accent: AppColors.gold,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.extension_rounded,
                                label: 'Puzzle rating',
                                value: '${profile.puzzleRating}',
                                accent: AppColors.seed,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.sports_esports_rounded,
                                label: 'Games',
                                value: '${profile.gamesPlayed}',
                                accent: Colors.white70,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.trending_up_rounded,
                                label: 'Win rate',
                                value: '${(profile.winRate * 100).round()}%',
                                accent: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Text(
                            '${profile.gamesWon}W · ${profile.gamesLost}L · ${profile.gamesDrawn}D  ·  '
                            'Puzzles: ${profile.puzzlesSolved} solved, best streak ${profile.bestPuzzleStreak}',
                            style: TextStyle(fontSize: 12.sp, color: Colors.white60),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.history),
                                title: const Text('Saved games', style: TextStyle(color: Colors.white)),
                                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const SavedGamesScreen()),
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.leaderboard_outlined),
                                title:
                                    const Text('Leaderboard', style: TextStyle(color: Colors.white)),
                                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),
                        if (profile.isAnonymous)
                          FilledButton.icon(
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('Create an account to save your progress'),
                            onPressed: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const SignInScreen())),
                          )
                        else
                          OutlinedButton.icon(
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign out'),
                            onPressed: () => auth.signOut(),
                          ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 20),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          SizedBox(height: 4.h),
          Text(label, style: TextStyle(fontSize: 11.sp, color: Colors.white60)),
        ],
      ),
    );
  }
}
