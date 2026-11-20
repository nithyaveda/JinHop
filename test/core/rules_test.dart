import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/core.dart';

import 'fixtures.dart';


void main() {
  group('ray rule', () {
    test('frog on the ray blocks, removing it frees the ray', () {
      final b = Board(fixtureB());
      final m = b.fullMask;
      expect(b.canTap(m, kGolden), isFalse);
      expect(b.canTap(m, kA), isFalse);
      expect(b.canTap(m, kB), isTrue);
      final m1 = b.resolveTap(m, kB)!;
      expect(b.canTap(m1, kA), isTrue);
      final m2 = b.resolveTap(m1, kA)!;
      expect(b.canTap(m2, kGolden), isTrue);
      expect(b.isWon(b.resolveTap(m2, kGolden)!), isTrue);
    });

    test('blocked tap does not change the state', () {
      final b = Board(fixtureB());
      expect(b.resolveTap(b.fullMask, kA), isNull);
    });

    test('snake on the ray blocks forever', () {
      final b = Board(ascii(['e X . .', '. . . .', '. . . .', 'N . . .']));
      expect(b.canTap(b.fullMask, 0), isFalse);
      expect(Solver(b).minRemaining(b.fullMask), isNull);
    });

    test('first blocker reports frog or snake', () {
      final b = Board(fixtureB());
      expect(b.firstBlocker(b.fullMask, kGolden), kA);
      expect(b.firstBlocker(b.fullMask, kB), -1);
      final s = Board(ascii(['e X . .', '. . . .', '. . . .', 'N . . .']));
      expect(s.firstBlocker(s.fullMask, 0), -2);
    });
  });

  group('rotator orientation', () {
    test('facing = base + (validTapCount mod 4) clockwise', () {
      final b = Board(ascii(rotatorRows));
      expect(b.onRotator[kR], isTrue);
      expect(b.onRotator[0], isFalse);
      const expected = [Facing.n, Facing.e, Facing.s, Facing.w, Facing.n, Facing.e, Facing.s, Facing.w];
      for (var k = 0; k < expected.length; k++) {
        expect(b.facingAtCount(kR, k), expected[k], reason: 'after $k valid taps');
        // Normal pads never turn.
        expect(b.facingAtCount(0, k), Facing.n);
      }
    });

    test('orientation follows real taps on the board', () {
      final b = Board(ascii(rotatorRows));
      var m = b.fullMask;
      expect(b.facingOf(m, kR), Facing.n);
      m = b.resolveTap(m, 2)!; // decoy (0,3)
      expect(b.facingOf(m, kR), Facing.e);
      m = b.resolveTap(m, 4)!; // decoy (2,3)
      expect(b.facingOf(m, kR), Facing.s);
      // Facing S, the decoy at (1,3) is in the way.
      expect(b.canTap(m, kR), isFalse);
      // One more tap turns it W: free again ("blocked now, free later").
      m = b.resolveTap(m, 5)!;
      expect(b.facingOf(m, kR), Facing.w);
      expect(b.canTap(m, kR), isTrue);
    });

    test('full turn after 4 taps returns to base', () {
      final b = Board(ascii(rotatorRows));
      var m = b.fullMask;
      for (final f in [2, 3, 4, 5]) {
        m = b.resolveTap(m, f)!;
      }
      expect(b.validTapCount(m), 4);
      expect(b.facingOf(m, kR), Facing.n);
    });
  });

  group('level JSON', () {
    test('round trip keeps everything', () {
      final l = ascii(rotatorRows, par: 4, budgetSlack: 6, id: 9);
      final back = Level.fromJson(l.toJson());
      expect(back.toJson(), l.toJson());
      expect(back.budgetSlack, 6);
      expect(back.padAt(1, 1), PadType.rotator);
    });

    test('budgetSlack defaults to 5', () {
      final j = ascii(rotatorRows).toJson()..remove('budgetSlack');
      expect(Level.fromJson(j).budgetSlack, 5);
    });
  });
}
