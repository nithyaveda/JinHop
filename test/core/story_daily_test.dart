import 'package:jinhop/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ui/harness.dart' show testStory;

void main() {
  group('StoryBook', () {
    test('beat after a level, world end + next world start at the landmark', () {
      expect(testStory.cardsAfter(1).map((c) => c.text), ['Story one.']);
      expect(testStory.cardsAfter(2).map((c) => c.text), ['Story two.', 'Story three.']);
      expect(testStory.cardsAfter(3), isEmpty);
      expect(testStory.worldOf(3)!.name, 'Test Marsh');
      expect(testStory.worldOf(99), isNull);
    });

    test('card keys are stable and unique', () {
      final keys = [for (var i = 1; i <= 4; i++) ...testStory.cardsAfter(i).map((c) => c.key)];
      expect(keys.toSet().length, keys.length);
      expect(keys, contains('w1_after1'));
    });
  });

  group('daily', () {
    test('same date -> same puzzle; different date -> different puzzle', () {
      final a = dailyLevel(DateTime(2026, 10, 29));
      final b = dailyLevel(DateTime(2026, 10, 29, 23, 59));
      final c = dailyLevel(DateTime(2026, 10, 30));
      String sig(Level l) => l.frogs.map((f) => '${f.x},${f.y},${f.facing.index}').join(';');
      expect(sig(a), sig(b));
      expect(sig(a), isNot(sig(c)));
      expect(a.id, kDailyLevelId);
    });

    test('daily puzzles are solvable and valid for a month', () {
      for (var d = 1; d <= 30; d++) {
        final l = dailyLevel(DateTime(2026, 11, d));
        final b = Board(l);
        final par = Solver(b).minRemaining(b.fullMask);
        expect(par, isNotNull, reason: 'day $d');
        expect(l.par, par, reason: 'day $d');
        expect(l.frogs.length, greaterThanOrEqualTo(12));
      }
    });
  });

  group('LuckyStreak', () {
    test('consecutive days grow the streak; same day changes nothing', () {
      var s = const LuckyStreak();
      s = s.solvedOn(100).solvedOn(101).solvedOn(101).solvedOn(102);
      expect(s.count, 3);
      expect(s.currentOn(102), 3);
      expect(s.currentOn(103), 3);
    });

    test('one missed day is forgiven once', () {
      var s = const LuckyStreak().solvedOn(100).solvedOn(101);
      expect(s.currentOn(103), 2, reason: 'token still available');
      s = s.solvedOn(103);
      expect(s.count, 3);
      expect(s.tokenAvailable, isFalse);
      expect(s.currentOn(105), 0, reason: 'token already used');
      s = s.solvedOn(105);
      expect(s.count, 1);
    });

    test('a long gap resets', () {
      final s = const LuckyStreak().solvedOn(100).solvedOn(110);
      expect(s.count, 1);
      expect(s.tokenAvailable, isTrue);
    });
  });
}
