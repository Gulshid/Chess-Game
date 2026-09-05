import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

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
              children: [
                _SectionHeader('Board'),
                for (final BoardTheme theme in BoardTheme.all)
                  RadioListTile<String>(
                    value: theme.name,
                    groupValue: settings.boardThemeName,
                    title: Text(theme.name),
                    secondary: _ThemeSwatch(theme: theme),
                    onChanged: (value) {
                      if (value != null) settingsProvider.setBoardTheme(value);
                    },
                  ),
                SwitchListTile(
                  title: const Text('Show legal move dots'),
                  value: settings.showLegalMoveDots,
                  onChanged: settingsProvider.setShowLegalMoveDots,
                ),
                SwitchListTile(
                  title: const Text('Show board coordinates'),
                  value: settings.showCoordinates,
                  onChanged: settingsProvider.setShowCoordinates,
                ),
                const Divider(),
                _SectionHeader('Sound & feedback'),
                SwitchListTile(
                  title: const Text('Move & capture sounds'),
                  value: settings.soundEnabled,
                  onChanged: settingsProvider.setSoundEnabled,
                ),
                SwitchListTile(
                  title: const Text('Haptic feedback'),
                  value: settings.hapticsEnabled,
                  onChanged: settingsProvider.setHapticsEnabled,
                ),
                const Divider(),
                _SectionHeader('Defaults for new games'),
                ListTile(
                  title: const Text('Default AI difficulty'),
                  trailing: DropdownButton<AiDifficulty>(
                    value: settings.defaultAiDifficulty,
                    onChanged: (value) {
                      if (value != null) settingsProvider.setDefaultAiDifficulty(value);
                    },
                    items: [
                      for (final AiDifficulty d in AiDifficulty.values)
                        DropdownMenuItem(value: d, child: Text(d.label)),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('Default time control'),
                  trailing: DropdownButton<String>(
                    value: settings.defaultTimeControlLabel,
                    onChanged: (value) {
                      if (value != null) settingsProvider.setDefaultTimeControlLabel(value);
                    },
                    items: [
                      for (final TimeControl tc in TimeControl.presets)
                        DropdownMenuItem(value: tc.label, child: Text(tc.label)),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 4.h),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.primary,
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
    return SizedBox(
      width: 32.w,
      height: 32.w,
      child: Column(
        children: [
          Expanded(child: Container(color: theme.lightSquare)),
          Expanded(child: Container(color: theme.darkSquare)),
        ],
      ),
    );
  }
}
