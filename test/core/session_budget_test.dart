import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/core.dart';

import 'fixtures.dart';

void main() {
  group('budget', () {
    test('a valid tap costs 1', () {
      final s = GameSession(fixtureB());
      expect(s.tap(kB), TapOutcome.removed);
      expect(s.budgetUsed, 1);
      expect(s.validTapCount, 1);
    });

    test('an invalid tap costs 0 and changes nothing', () {
      final s = GameSession(fixtureB());
      expect(s.tap(kA), TapOutcome.blocked);
      expect(s.tap(kD2), TapOutcome.blocked);
      expect(s.tap(kGolden), TapOutcome.blocked);
      expect(s.budgetUsed, 0);
      expect(s.mask, s.board.fullMask);
    });

    test('there is no undo: hops are final', () {
      final s = GameSession(fixtureB());
      s.tap(kB);
      expect(s.budgetUsed, 1);
      expect(s.isFrogPresent(kB), isFalse);
    });

    test('failure triggers at exactly cap + 1', () {
      final s = GameSession(fixtureB(budgetSlack: 2)); // cap 5
      expect(s.cap, 5);
      for (final f in [kD1, kD3, kD2, kB, kA]) {
        expect(s.tap(f), TapOutcome.removed);
      }
      expect(s.budgetUsed, 5);
      expect(s.status, isNot(SessionStatus.failed));
      expect(s.tapsLeft, 0);
      expect(s.tap(kGolden), TapOutcome.failed);
      expect(s.budgetUsed, 6);
      expect(s.status, SessionStatus.failed);
      expect(s.failReason, FailReason.hops);
      expect(s.isFrogPresent(kGolden), isTrue, reason: 'failing tap is not applied');
      expect(s.tap(kGolden), TapOutcome.ignored);
    });

    test('winning exactly at the cap is allowed', () {
      final s = GameSession(fixtureB(budgetSlack: 2)); // cap 5
      for (final f in [kD1, kD3, kB, kA]) {
        expect(s.tap(f), TapOutcome.removed);
      }
      expect(s.tap(kGolden), TapOutcome.won);
      expect(s.budgetUsed, 5);
      expect(s.status, SessionStatus.won);
    });

    test('restart is free and resets the board and the clock', () {
      final s = GameSession(fixtureB(budgetSlack: 2));
      s.tap(kD1);
      s.tick(5000);
      s.restart();
      expect(s.budgetUsed, 0);
      expect(s.elapsedMs, 0);
      expect(s.mask, s.board.fullMask);
      expect(s.status, SessionStatus.playing);
    });
  });

  group('timer', () {
    test('world 1 has 60 s, world 2 and the daily pond 90 s, tutorial none', () {
      expect(timeLimitFor(fixtureB().copyWith(world: 1)), 60);
      expect(timeLimitFor(fixtureB().copyWith(world: 2)), 90);
      expect(timeLimitFor(fixtureB().copyWith(world: 0)), 90);
      expect(timeLimitFor(fixtureB(budgetSlack: 99).copyWith(world: 1)), isNull);
      expect(GameSession(fixtureB(budgetSlack: 99)).isTimed, isFalse);
    });

    test('counts down and fails at zero; time never changes stars', () {
      final s = GameSession(fixtureB().copyWith(world: 1));
      expect(s.timeLeftMs, 60000);
      expect(s.tick(59999), isFalse);
      expect(s.timeLeftMs, 1);
      expect(s.status, isNot(SessionStatus.failed));
      expect(s.tick(1), isTrue);
      expect(s.status, SessionStatus.failed);
      expect(s.failReason, FailReason.time);
      expect(s.tap(kB), TapOutcome.ignored);
      expect(s.tick(1000), isFalse, reason: 'clock stops once failed');

      final w = GameSession(fixtureB().copyWith(world: 1));
      w.tick(59000);
      for (final f in [kB, kA]) {
        w.tap(f);
      }
      expect(w.tap(kGolden), TapOutcome.won);
      expect(w.stars, 3);
      expect(w.tick(5000), isFalse, reason: 'clock stops once won');
    });
  });

  group('hints', () {
    test('two free hints per level, more can be granted, restart keeps them used', () {
      final s = GameSession(fixtureB());
      expect(s.hintsLeft, kFreeHints);
      expect(s.hint(), isNotNull);
      expect(s.hint(), isNotNull);
      expect(s.hintsLeft, 0);
      expect(s.hint(), isNull);
      s.restart();
      expect(s.hintsLeft, 0);
      s.grantHint();
      expect(s.hintsLeft, 1);
      expect(s.hint(), isNotNull);
      expect(s.hintsLeft, 0);
    });
  });

  group('stars', () {
    test('thresholds: <= par 3, <= par+2 2, else 1', () {
      expect(starsFor(3, 3), 3);
      expect(starsFor(2, 3), 3);
      expect(starsFor(4, 3), 2);
      expect(starsFor(5, 3), 2);
      expect(starsFor(6, 3), 1);
    });

    int play(List<int> taps) {
      final s = GameSession(fixtureB());
      for (final f in taps) {
        s.tap(f);
      }
      expect(s.status, SessionStatus.won);
      return s.stars;
    }

    test('at par -> 3 stars', () => expect(play([kB, kA, kGolden]), 3));
    test('at par+2 -> 2 stars', () => expect(play([kD1, kD3, kB, kA, kGolden]), 2));
    test('at par+3 -> 1 star', () => expect(play([kD1, kD3, kD2, kB, kA, kGolden]), 1));
  });

  test('levels with budgetSlack 99 (L1-5) never fail', () {
    final s = GameSession(fixtureB(budgetSlack: 99));
    expect(s.hasCap, isFalse);
    expect(s.tapsLeft, isNull);
    for (final f in [kD1, kD3, kD2, kB, kA]) {
      s.tap(f);
      expect(s.status, isNot(SessionStatus.failed));
    }
    expect(s.tap(kGolden), TapOutcome.won);
    expect(s.stars, 1);
  });

  group('restless nudge', () {
    test('triggers when minRemaining exceeds the remaining budget', () {
      final s = GameSession(fixtureB(budgetSlack: 2)); // cap 5, par 3
      s.tap(kD1); // used 1, left 4, need 3
      expect(s.status, SessionStatus.playing);
      s.tap(kD3); // used 2, left 3, need 3
      expect(s.status, SessionStatus.playing);
      s.tap(kD2); // used 3, left 2, need 3
      expect(s.minRemaining, 3);
      expect(s.status, SessionStatus.restless);
      // Restless does not block play; it never auto-fails early.
      expect(s.tap(kB), TapOutcome.removed); // used 4
      expect(s.status, SessionStatus.restless);
    });

    test('triggers on an unwinnable (deadlocked) state', () {
      final s = GameSession(ascii(['. . X .', 'e . Wr .', '. . X .', 'S . . .'], par: 4));
      expect(s.status, SessionStatus.restless);
      expect(s.minRemaining, isNull);
    });
  });
}
