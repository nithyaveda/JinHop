import 'dart:convert';
import 'dart:io';

import 'package:jinhop/core/core.dart';

/// The 30 committed levels, read straight from assets/levels.
List<Level> loadLevels() => [
      for (var id = 1; id <= 30; id++)
        Level.fromJson(jsonDecode(File('assets/levels/level_${id.toString().padLeft(2, '0')}.json')
            .readAsStringSync()) as Map<String, Object?>)
    ];


/// Builds a Level from a readable grid (see lib/core/ascii_level.dart).
Level ascii(List<String> rows, {int par = 0, int budgetSlack = 5, int id = 0}) =>
    levelFromRows(rows, par: par, budgetSlack: budgetSlack, id: id);

/// Fixture B (par 3). Frog indices (row-major):
///   0 golden (0,0) E     1 A (2,0) S     2 B (2,2) E
///   3 D1 (0,3) S         4 D2 (1,3) W    5 D3 (3,3) N
/// Solution: B, A, golden. D1 and D3 are free decoys; D2 is blocked by D1.
const fixtureBRows = [
  'e . S .',
  '. . . .',
  '. . E .',
  'S W . N',
];
const kGolden = 0, kA = 1, kB = 2, kD1 = 3, kD2 = 4, kD3 = 5;

Level fixtureB({int budgetSlack = 5}) => ascii(fixtureBRows, par: 3, budgetSlack: budgetSlack);

/// Rotator fixture. Indices: 0 golden (0,0) N, 1 R (1,1) rotator base N,
/// 2..5 free decoys on the bottom row facing S.
const rotatorRows = [
  'n . . .',
  '. Nr . .',
  '. . . .',
  'S S S S',
];
const kR = 1;

/// Reference breadth-first search (no heuristic, no cache) used to check the
/// A* solver gives true shortest distances.
int? bfsDistance(Board board, int start) {
  if (board.isWon(start)) return 0;
  var frontier = <int>{start};
  final seen = <int>{start};
  var depth = 0;
  while (frontier.isNotEmpty) {
    depth++;
    final next = <int>{};
    for (final m in frontier) {
      for (final f in board.tappableFrogs(m)) {
        final c = m & ~(1 << f);
        if (board.isWon(c)) return depth;
        if (seen.add(c)) next.add(c);
      }
    }
    frontier = next;
  }
  return null;
}
