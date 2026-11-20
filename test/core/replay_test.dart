import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/core.dart';
import 'package:jinhop/ui/board_controller.dart';

import 'fixtures.dart';

void main() {
  test('no reverse replay: a win goes straight to Jin Chan\'s leap, the board stays as played', () {
    final c = BoardController(fixtureB());
    for (final f in [kB, kA]) {
      expect(c.tapFrog(f), TapOutcome.removed);
    }
    expect(c.tapFrog(kGolden), TapOutcome.won);
    expect(c.finaleRunning, isTrue);
    expect(c.fx.phaseBUs, 0, reason: 'the golden leap starts right away');
    expect(c.fx.jumps.where((j) => j.frog == kGolden), isEmpty,
        reason: 'the leap is drawn by the finale, not as a second hop');
    for (final f in [kB, kA, kGolden]) {
      expect(c.session.isFrogPresent(f), isFalse, reason: 'frogs that went home never hop back');
    }
  });
}
