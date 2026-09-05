import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

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
      builder: (context) => SafeArea(
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
          body: auth.isLoading || profile == null
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: ListView(
                    padding: EdgeInsets.all(20.w),
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: () => _pickAvatar(context),
                          child: CircleAvatar(
                            radius: 44.r,
                            child: Text(profile.avatarEmoji, style: TextStyle(fontSize: 40.sp)),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _editName(context, profile.displayName),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text(
                            profile.displayName,
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
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
                            child: _StatCard(label: 'Rating', value: '${profile.rating}'),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _StatCard(
                              label: 'Puzzle rating',
                              value: '${profile.puzzleRating}',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(label: 'Games', value: '${profile.gamesPlayed}'),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _StatCard(
                              label: 'Win rate',
                              value: '${(profile.winRate * 100).round()}%',
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
                          style: TextStyle(fontSize: 12.sp, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: const Text('Saved games'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const SavedGamesScreen())),
                      ),
                      ListTile(
                        leading: const Icon(Icons.leaderboard_outlined),
                        title: const Text('Leaderboard'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
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
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800)),
          SizedBox(height: 4.h),
          Text(label, style: TextStyle(fontSize: 11.sp, color: Colors.white70)),
        ],
      ),
    );
  }
}
