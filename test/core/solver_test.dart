import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/core.dart';

import 'fixtures.dart';

/// Rotator deadlock: golden (0,1) E is blocked only by rotator frog R (2,1),
/// base W. R's N and S exits are snakes, W points back at the golden frog, so
/// R can only leave facing E, which needs validTapCount = 2 (mod 4). Only one
/// other frog (D, free) exists, so phase 2 is unreachable: deadlock.
/// Indices: 0 golden, 1 R, 2 D.
const rotatorDeadlockRows = [
  '. . X .',
  'e . Wr .',
  '. . X .',
  'S . . .',
];

/// Same board with a second free decoy: phase 2 becomes reachable.
const rotatorSolvableRows = [
  '. . X .',
  'e . Wr .',
  '. . X .',
  'S . . S',
];

void main() {
  test('fixture B: par 3, hint and path follow B -> A -> golden', () {
    final b = Board(fixtureB());
    final s = Solver(b);
    expect(s.minRemaining(b.fullMask), 3);
    expect(s.hint(b.fullMask), kB);
    expect(s.solutionPath(b.fullMask), [kB, kA, kGolden]);
    // Hint is recomputed from the CURRENT state, even off the best path.
    final afterDecoy = b.resolveTap(b.fullMask, kD1)!;
    expect(s.minRemaining(afterDecoy), 3);
    expect(s.hint(afterDecoy), kB);
    final ready = b.resolveTap(b.resolveTap(b.fullMask, kB)!, kA)!;
    expect(s.minRemaining(ready), 1);
    expect(s.hint(ready), kGolden);
  });

  test('minRemaining is null on the rotator-deadlock fixture', () {
    final b = Board(ascii(rotatorDeadlockRows));
    final s = Solver(b);
    expect(s.minRemaining(b.fullMask), isNull);
    expect(s.hint(b.fullMask), isNull);
    // Also null after the only possible tap.
    expect(s.minRemaining(b.resolveTap(b.fullMask, 2)!), isNull);
  });

  test('one more decoy makes the rotator fixture solvable in 4', () {
    final b = Board(ascii(rotatorSolvableRows));
    final s = Solver(b);
    expect(s.minRemaining(b.fullMask), 4);
    final path = s.solutionPath(b.fullMask)!;
    expect(path.length, 4);
    expect(path[2], 1, reason: 'R leaves third, when facing E');
    expect(path.last, 0);
  });

  test('must-clear cycle between fixed frogs is detected as unwinnable', () {
    // golden (0,0) E blocked by F (2,0) facing W... which is blocked by golden.
    final b = Board(ascii(['e . W .', '. . . .', '. . . .', 'S . . .']));
    final s = Solver(b);
    expect(s.heuristic(b.fullMask), isNull);
    expect(s.minRemaining(b.fullMask), isNull);
  });

  test('A* distances equal plain BFS on random reachable states', () {
    const gen = LevelGenerator();
    const cfg = GeneratorConfig(size: 6, frogCount: 13, chainLength: 7, rotatorCount: 3, snakeCount: 1);
    var compared = 0;
    for (var seed = 1; seed <= 6; seed++) {
      final g = gen.generate(cfg, seed: seed);
      expect(g, isNotNull, reason: 'seed $seed');
      final b = Board(g!.level);
      final rng = Rng(seed * 31);
      for (var walk = 0; walk < 15; walk++) {
        var m = b.fullMask;
        final steps = rng.nextInt(6);
        for (var i = 0; i < steps; i++) {
          final moves = b.tappableFrogs(m).where((f) => f != b.goldenIndex).toList();
          if (moves.isEmpty) break;
          m &= ~(1 << rng.pick(moves));
        }
        final fresh = Solver(b);
        expect(fresh.minRemaining(m), bfsDistance(b, m), reason: 'seed $seed walk $walk');
        compared++;
      }
    }
    expect(compared, 90);
  });
}
