import 'package:flutter/services.dart';

/// Centralizes the roadmap's "Sound design pass: move, capture, check,
/// checkmate/game-start/end sounds" and "Add haptic feedback on
/// move/capture for a premium feel" line items (Phase 11 — the second
/// one was actually listed under Phase 5, but neither was wired up to
/// anything until now; `AppSettings.soundEnabled`/`hapticsEnabled` have
/// existed as persisted toggles since Phase 9 with nothing reading them).
///
/// This app ships no bundled audio assets, so rather than pulling in an
/// audio-player dependency and an asset pipeline just for a handful of
/// short UI cues, feedback is built entirely on framework APIs that need
/// neither: [SystemSound] plays the platform's own short click/alert
/// sounds, and [HapticFeedback] drives the device's taptic engine. Both
/// work out of the box on a real device today. If this project later
/// ships a proper sound-effects asset pack, only this file needs to
/// change — swap each `SystemSound.play(...)` call below for e.g.
/// `AudioPlayer.play(AssetSource('sounds/capture.mp3'))`; every call
/// site elsewhere in the app already goes through one of the named
/// events here rather than touching a sound API directly.
///
/// Every method takes the caller's current sound/haptics preference as
/// an explicit parameter rather than this class reading
/// `SettingsProvider` itself. That keeps `GameFeedbackService` free of
/// any `BuildContext` or provider dependency, which is what makes it
/// trivially unit-testable (see `game_feedback_service_test.dart`) and
/// usable from anywhere — including the pure-Dart engine/provider layer,
/// which has no widget tree to read settings from.
class GameFeedbackService {
  const GameFeedbackService._();

  /// A normal, non-capturing, non-castling move landed.
  static void playMove({required bool soundEnabled, required bool hapticsEnabled}) {
    if (soundEnabled) SystemSound.play(SystemSoundType.click);
    if (hapticsEnabled) HapticFeedback.selectionClick();
  }

  /// A move captured an enemy piece. Deliberately heavier than
  /// [playMove] so a capture actually *feels* different, per the
  /// roadmap's "capture animations, check indication, and move sound
  /// effects" — distinct feedback per event, not one generic "tap".
  static void playCapture({required bool soundEnabled, required bool hapticsEnabled}) {
    if (soundEnabled) SystemSound.play(SystemSoundType.click);
    if (hapticsEnabled) HapticFeedback.mediumImpact();
  }

  /// Castling. Grouped with capture-weight feedback since it's also a
  /// "bigger" move than an ordinary single-piece shuffle (two pieces
  /// move on the board at once).
  static void playCastle({required bool soundEnabled, required bool hapticsEnabled}) {
    if (soundEnabled) SystemSound.play(SystemSoundType.click);
    if (hapticsEnabled) HapticFeedback.mediumImpact();
  }

  /// The side to move has just been put in check (but the game isn't
  /// over — see [playGameEnd] for checkmate, which fires this in
  /// addition to a distinct game-over cue rather than instead of it).
  static void playCheck({required bool soundEnabled, required bool hapticsEnabled}) {
    if (soundEnabled) SystemSound.play(SystemSoundType.alert);
    if (hapticsEnabled) HapticFeedback.heavyImpact();
  }

  /// The game just ended. [won] and [drawn] shape the haptic pattern
  /// only — a real win should feel different from a resignation into a
  /// draw or a loss — since there's no separate "victory" system sound
  /// to reach for; the alert sound is shared across every outcome.
  static void playGameEnd({
    required bool soundEnabled,
    required bool hapticsEnabled,
    required bool won,
    required bool drawn,
  }) {
    if (soundEnabled) SystemSound.play(SystemSoundType.alert);
    if (!hapticsEnabled) return;
    if (won) {
      HapticFeedback.heavyImpact();
    } else if (drawn) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.lightImpact();
    }
  }
}
