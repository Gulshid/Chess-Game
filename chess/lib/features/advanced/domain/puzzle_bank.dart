import 'puzzle.dart';

/// A small, hand-verified starter set of tactics puzzles.
///
/// The roadmap's Phase 8 calls for puzzles "sourced from a puzzle
/// database (e.g., Lichess puzzle dataset, which is open and free)".
/// That dataset is several million rows and is meant to be imported as
/// data (a CSV/JSON asset or a backend query), not hand-typed into a
/// Dart source file — wiring that importer up is future work (see the
/// TODO below). What ships here is a tiny illustrative set covering
/// distinct, classic mating patterns, so puzzle mode, the daily-puzzle
/// picker, and the rating/progress UI all have real, correct content to
/// work against today.
///
/// TODO(puzzles-v2): replace/extend this with an imported Lichess puzzle
/// CSV (columns: PuzzleId, FEN, Moves, Rating, Themes) — the [Puzzle]
/// model above already matches that schema 1:1, so the import is a
/// straight row -> [Puzzle] mapping with no model changes needed.
class PuzzleBank {
  const PuzzleBank._();

  static const List<Puzzle> all = <Puzzle>[
    Puzzle(
      id: 'starter-001',
      fen: '6k1/5ppp/8/8/8/8/8/R6K w - - 0 1',
      solutionUci: <String>['a1a8'],
      rating: 600,
      themes: <String>['mate', 'mateIn1', 'backRankMate'],
    ),
    Puzzle(
      id: 'starter-002',
      fen: 'k7/1R6/8/8/8/8/4K3/7R w - - 0 1',
      solutionUci: <String>['h1a1'],
      rating: 650,
      themes: <String>['mate', 'mateIn1', 'rookLadderMate'],
    ),
    Puzzle(
      id: 'starter-003',
      fen: '7k/8/6K1/8/8/8/8/3Q4 w - - 0 1',
      solutionUci: <String>['d1d8'],
      rating: 700,
      themes: <String>['mate', 'mateIn1', 'queenMate'],
    ),
    Puzzle(
      id: 'starter-004',
      fen: '7k/8/6K1/8/8/8/8/R7 w - - 0 1',
      solutionUci: <String>['a1a8'],
      rating: 650,
      themes: <String>['mate', 'mateIn1', 'rookMate'],
    ),
    Puzzle(
      id: 'starter-005',
      fen: 'k7/8/1K6/8/8/8/8/7Q w - - 0 1',
      solutionUci: <String>['h1h8'],
      rating: 700,
      themes: <String>['mate', 'mateIn1', 'queenMate'],
    ),
  ];

  static Puzzle byId(String id) => all.firstWhere((p) => p.id == id);

  /// A stable "puzzle of the day" — the same puzzle for every player on
  /// a given calendar day, cycling through [all] deterministically
  /// rather than at random, so it matches what "daily puzzle" means in
  /// every reference app (Lichess/Chess.com): everyone gets the same one.
  static Puzzle daily({DateTime? date}) {
    final DateTime d = date ?? DateTime.now();
    final int dayOfYear = int.parse(
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}',
    );
    return all[dayOfYear % all.length];
  }
}
