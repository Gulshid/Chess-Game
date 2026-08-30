/// "Turn timers / chess clocks (blitz, rapid, classical time controls)
/// with increment support" — Phase 7.
///
/// Values are stored in seconds (not [Duration]) so a [TimeControl] can
/// be written straight into a Firestore document field without a custom
/// codec — Firestore documents are plain JSON-like maps under the hood.
class TimeControl {
  const TimeControl({
    required this.label,
    required this.initialSeconds,
    required this.incrementSeconds,
  });

  final String label;
  final int initialSeconds;
  final int incrementSeconds;

  Map<String, Object?> toJson() => <String, Object?>{
        'label': label,
        'initialSeconds': initialSeconds,
        'incrementSeconds': incrementSeconds,
      };

  static TimeControl fromJson(Map<String, Object?> json) => TimeControl(
        label: json['label'] as String? ?? 'Custom',
        initialSeconds: (json['initialSeconds'] as num?)?.toInt() ?? 600,
        incrementSeconds: (json['incrementSeconds'] as num?)?.toInt() ?? 0,
      );

  static const TimeControl bullet1 = TimeControl(
    label: 'Bullet · 1+0',
    initialSeconds: 60,
    incrementSeconds: 0,
  );

  static const TimeControl blitz3 = TimeControl(
    label: 'Blitz · 3+2',
    initialSeconds: 180,
    incrementSeconds: 2,
  );

  static const TimeControl blitz5 = TimeControl(
    label: 'Blitz · 5+0',
    initialSeconds: 300,
    incrementSeconds: 0,
  );

  static const TimeControl rapid10 = TimeControl(
    label: 'Rapid · 10+0',
    initialSeconds: 600,
    incrementSeconds: 0,
  );

  static const TimeControl classical30 = TimeControl(
    label: 'Classical · 30+0',
    initialSeconds: 1800,
    incrementSeconds: 0,
  );

  static const List<TimeControl> presets = <TimeControl>[
    bullet1,
    blitz3,
    blitz5,
    rapid10,
    classical30,
  ];
}
