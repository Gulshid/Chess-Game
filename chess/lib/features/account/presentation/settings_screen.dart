import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constant/app_colors.dart';
import '../../ai/domain/ai_difficulty.dart';
import '../../board_ui/domain/board_theme.dart';
import '../../multiplayer/domain/time_control.dart';
import 'settings_provider.dart';

/// "Persist user preferences: board theme, piece set, sound/haptics
/// toggle, default time control" (Phase 9). Every control here writes
/// straight through [SettingsProvider], which persists via
/// [HiveSettingsRepository] on each change — there's no separate "Save"
/// button, matching how [GameScreen]'s existing board-theme picker
/// already behaves (just without the persistence, before this phase).
///
/// Visually, each section is now its own rounded card instead of a flat
/// list with dividers, and every toggle/radio uses the app's gold accent
/// instead of the default Material primary tint — same controls, same
/// [SettingsProvider] calls, just grouped and colored consistently with
/// the rest of the app.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final settings = settingsProvider.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
              children: [
                _SectionHeader('Board'),
                _SectionCard(
                  children: [
                    for (final BoardTheme theme in BoardTheme.all)
                      RadioListTile<String>(
                        value: theme.name,
                        groupValue: settings.boardThemeName,
                        activeColor: AppColors.gold,
                        title: Text(theme.name, style: const TextStyle(color: Colors.white)),
                        secondary: _ThemeSwatch(theme: theme),
                        onChanged: (value) {
                          if (value != null) settingsProvider.setBoardTheme(value);
                        },
                      ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Show legal move dots',
                          style: TextStyle(color: Colors.white)),
                      secondary: const Icon(Icons.radio_button_checked_rounded),
                      activeThumbColor: AppColors.gold,
                      value: settings.showLegalMoveDots,
                      onChanged: settingsProvider.setShowLegalMoveDots,
                    ),
                    SwitchListTile(
                      title: const Text('Show board coordinates',
                          style: TextStyle(color: Colors.white)),
                      secondary: const Icon(Icons.grid_on_rounded),
                      activeThumbColor: AppColors.gold,
                      value: settings.showCoordinates,
                      onChanged: settingsProvider.setShowCoordinates,
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                _SectionHeader('Sound & feedback'),
                _SectionCard(
                  children: [
                    SwitchListTile(
                      title: const Text('Move & capture sounds',
                          style: TextStyle(color: Colors.white)),
                      secondary: const Icon(Icons.volume_up_rounded),
                      activeThumbColor: AppColors.gold,
                      value: settings.soundEnabled,
                      onChanged: settingsProvider.setSoundEnabled,
                    ),
                    SwitchListTile(
                      title: const Text('Haptic feedback',
                          style: TextStyle(color: Colors.white)),
                      secondary: const Icon(Icons.vibration_rounded),
                      activeThumbColor: AppColors.gold,
                      value: settings.hapticsEnabled,
                      onChanged: settingsProvider.setHapticsEnabled,
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                _SectionHeader('Defaults for new games'),
                _SectionCard(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.smart_toy_rounded),
                      title: const Text('Default AI difficulty',
                          style: TextStyle(color: Colors.white)),
                      trailing: DropdownButton<AiDifficulty>(
                        value: settings.defaultAiDifficulty,
                        dropdownColor: AppColors.surfaceElevated,
                        underline: const SizedBox.shrink(),
                        onChanged: (value) {
                          if (value != null) settingsProvider.setDefaultAiDifficulty(value);
                        },
                        items: [
                          for (final AiDifficulty d in AiDifficulty.values)
                            DropdownMenuItem(
                              value: d,
                              child: Text(d.label, style: const TextStyle(color: Colors.white)),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('Default time control',
                          style: TextStyle(color: Colors.white)),
                      trailing: DropdownButton<String>(
                        value: settings.defaultTimeControlLabel,
                        dropdownColor: AppColors.surfaceElevated,
                        underline: const SizedBox.shrink(),
                        onChanged: (value) {
                          if (value != null) settingsProvider.setDefaultTimeControlLabel(value);
                        },
                        items: [
                          for (final TimeControl tc in TimeControl.presets)
                            DropdownMenuItem(
                              value: tc.label,
                              child: Text(tc.label, style: const TextStyle(color: Colors.white)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 16.h, 4.w, 8.h),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme});
  final BoardTheme theme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 32.w,
        height: 32.w,
        child: Column(
          children: [
            Expanded(child: Container(color: theme.lightSquare)),
            Expanded(child: Container(color: theme.darkSquare)),
          ],
        ),
      ),
    );
  }
}
