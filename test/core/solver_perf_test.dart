import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/core.dart';

import 'fixtures.dart';

void main() {
  test('minRemaining stays under 16ms per move on the hardest level (cold cache)', () {
    // Hardest committed level: highest par, then most frogs.
    final levels = loadLevels()
      ..sort((a, b) => a.par != b.par ? b.par - a.par : b.frogs.length - a.frogs.length);
    final hardest = levels.first;
    final b = Board(hardest);

    // Warm up the VM JIT on a throwaway solver.
    Solver(b).minRemaining(b.fullMask);

    final rng = Rng(99);
    final states = <int>[b.fullMask];
    for (var walk = 0; walk < 60; walk++) {
      var m = b.fullMask;
      final steps = 1 + rng.nextInt(8);
      for (var i = 0; i < steps; i++) {
        final moves = b.tappableFrogs(m).where((f) => f != b.goldenIndex).toList();
        if (moves.isEmpty) break;
        m &= ~(1 << rng.pick(moves));
      }
      states.add(m);
    }

    var worstUs = 0;
    var totalUs = 0;
    var worstNodes = 0;
    for (final m in states) {
      final s = Solver(b); // cold cache: the worst case per move
      final sw = Stopwatch()..start();
      s.minRemaining(m);
      sw.stop();
      totalUs += sw.elapsedMicroseconds;
      if (sw.elapsedMicroseconds > worstUs) worstUs = sw.elapsedMicroseconds;
      if (s.lastExpanded > worstNodes) worstNodes = s.lastExpanded;
    }
    // ignore: avoid_print
    print('solver perf: L${hardest.id}, par ${hardest.par}, ${b.frogCount} frogs, '
        '${states.length} states, avg ${(totalUs / states.length / 1000).toStringAsFixed(2)} ms, '
        'worst ${(worstUs / 1000).toStringAsFixed(2)} ms, worst nodes $worstNodes');
    expect(worstUs, lessThan(16000));
  });
}
