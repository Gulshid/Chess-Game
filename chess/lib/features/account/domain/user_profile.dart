import 'rating.dart';

/// A player's persisted profile: identity, ranked-play rating, game
/// statistics, and puzzle-training progress.
///
/// Stored at `users/{uid}` in Firestore (see
/// `FirestoreProfileRepository`). Kept as a single flat document rather
/// than split across sub-documents — it's small, it's read as a whole
/// on every screen that shows it (profile, leaderboard, the matchmaking
/// display-name field), and Firestore has no join, so one document is
/// simpler than reassembling several.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.avatarEmoji,
    required this.isAnonymous,
    this.rating = Rating.startingRating,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.gamesLost = 0,
    this.gamesDrawn = 0,
    this.puzzleRating = Rating.startingPuzzleRating,
    this.puzzlesSolved = 0,
    this.puzzlesAttempted = 0,
    this.puzzleStreak = 0,
    this.bestPuzzleStreak = 0,
    required this.createdAtEpochMs,
  });

  final String uid;
  final String displayName;

  /// The whole avatar system for this app: one emoji, no image upload
  /// pipeline. Keeps Phase 9 out of the business of storage buckets,
  /// image picking/cropping, and content moderation for user photos —
  /// none of which the roadmap's Phase 9 scope ("User profile: avatar,
  /// username, rating, game statistics") requires by name.
  final String avatarEmoji;

  /// True for a device-only guest session (Firebase anonymous auth —
  /// see `FirestoreMultiplayerRepository`'s pre-Phase-9 use of it).
  /// Anonymous profiles are excluded from the leaderboard (see
  /// `FirestoreProfileRepository.watchLeaderboard`) since they aren't a
  /// durable identity — the same guest reinstalling the app gets a new
  /// uid and a fresh rating.
  final bool isAnonymous;

  /// Elo-style rating for ranked online play. Updated after every
  /// completed online game — see `Rating.updateElo` and
  /// `ProfileRepository.recordGameResult`.
  final int rating;

  final int gamesPlayed;
  final int gamesWon;
  final int gamesLost;
  final int gamesDrawn;

  /// Separate rating track for puzzles ("Puzzle rating system
  /// (simplified Elo-style) to track player improvement" — Phase 8,
  /// wired up to real persistence here in Phase 9). Deliberately not
  /// the same number as [rating]: solving tactics and playing full
  /// games are different skills, and Lichess/chess.com both track them
  /// separately for the same reason.
  final int puzzleRating;
  final int puzzlesSolved;
  final int puzzlesAttempted;

  /// Consecutive puzzles solved without a failed attempt in between —
  /// a lightweight motivational stat alongside the rating number.
  final int puzzleStreak;
  final int bestPuzzleStreak;

  final int createdAtEpochMs;

  double get winRate => gamesPlayed == 0 ? 0 : gamesWon / gamesPlayed;

  double get puzzleAccuracy => puzzlesAttempted == 0 ? 0 : puzzlesSolved / puzzlesAttempted;

  UserProfile copyWith({
    String? displayName,
    String? avatarEmoji,
    bool? isAnonymous,
    int? rating,
    int? gamesPlayed,
    int? gamesWon,
    int? gamesLost,
    int? gamesDrawn,
    int? puzzleRating,
    int? puzzlesSolved,
    int? puzzlesAttempted,
    int? puzzleStreak,
    int? bestPuzzleStreak,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      rating: rating ?? this.rating,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      gamesLost: gamesLost ?? this.gamesLost,
      gamesDrawn: gamesDrawn ?? this.gamesDrawn,
      puzzleRating: puzzleRating ?? this.puzzleRating,
      puzzlesSolved: puzzlesSolved ?? this.puzzlesSolved,
      puzzlesAttempted: puzzlesAttempted ?? this.puzzlesAttempted,
      puzzleStreak: puzzleStreak ?? this.puzzleStreak,
      bestPuzzleStreak: bestPuzzleStreak ?? this.bestPuzzleStreak,
      createdAtEpochMs: createdAtEpochMs,
    );
  }

  factory UserProfile.newPlayer({
    required String uid,
    required String displayName,
    required bool isAnonymous,
    String avatarEmoji = '♟️',
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName,
      avatarEmoji: avatarEmoji,
      isAnonymous: isAnonymous,
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory UserProfile.fromMap(String uid, Map<String, Object?> map) {
    return UserProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? 'Player',
      avatarEmoji: map['avatarEmoji'] as String? ?? '♟️',
      isAnonymous: map['isAnonymous'] as bool? ?? true,
      rating: (map['rating'] as num?)?.toInt() ?? Rating.startingRating,
      gamesPlayed: (map['gamesPlayed'] as num?)?.toInt() ?? 0,
      gamesWon: (map['gamesWon'] as num?)?.toInt() ?? 0,
      gamesLost: (map['gamesLost'] as num?)?.toInt() ?? 0,
      gamesDrawn: (map['gamesDrawn'] as num?)?.toInt() ?? 0,
      puzzleRating: (map['puzzleRating'] as num?)?.toInt() ?? Rating.startingPuzzleRating,
      puzzlesSolved: (map['puzzlesSolved'] as num?)?.toInt() ?? 0,
      puzzlesAttempted: (map['puzzlesAttempted'] as num?)?.toInt() ?? 0,
      puzzleStreak: (map['puzzleStreak'] as num?)?.toInt() ?? 0,
      bestPuzzleStreak: (map['bestPuzzleStreak'] as num?)?.toInt() ?? 0,
      createdAtEpochMs:
          (map['createdAtEpochMs'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'displayName': displayName,
        'avatarEmoji': avatarEmoji,
        'isAnonymous': isAnonymous,
        'rating': rating,
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'gamesLost': gamesLost,
        'gamesDrawn': gamesDrawn,
        'puzzleRating': puzzleRating,
        'puzzlesSolved': puzzlesSolved,
        'puzzlesAttempted': puzzlesAttempted,
        'puzzleStreak': puzzleStreak,
        'bestPuzzleStreak': bestPuzzleStreak,
        'createdAtEpochMs': createdAtEpochMs,
      };
}

/// Selectable avatar emoji — deliberately a short curated list (chess
/// pieces plus a few playful extras) rather than a full emoji picker,
/// which would be a lot of UI for very little value in a chess app.
class AvatarEmojis {
  const AvatarEmojis._();

  static const List<String> all = <String>[
    '♟️', '♞', '♝', '♜', '♛', '♚', '🧠', '🐉', '🦊', '🦁', '🐺', '🎯', '⚡', '🔥', '🌟', '🛡️',
  ];
}
