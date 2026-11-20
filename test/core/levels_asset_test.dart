import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/core.dart';

import 'fixtures.dart';

void main() {
  final levels = loadLevels();

  test('30 levels, ids 1-30, worlds 15 + 15', () {
    expect(levels.map((l) => l.id), List.generate(30, (i) => i + 1));
    expect(levels.where((l) => l.world == 1).length, 15);
    expect(levels.where((l) => l.world == 2).length, 15);
  });

  test('every committed level passes the validator with the solver par', () {
    for (final l in levels) {
      final v = LevelValidator.validate(l);
      expect(v.ok, isTrue, reason: 'L${l.id}: $v');
    }
  });

  test('levels 1-5: core rule only and never fail', () {
    for (final l in levels.take(5)) {
      expect(l.budgetSlack, 99, reason: 'L${l.id}');
      expect(l.rotatorCount, 0);
      expect(l.snakes, isEmpty);
    }
  });

  test('levels 6+: slack 3-7; L6-8 introduce rotators; W2 has snakes', () {
    for (final l in levels.skip(5)) {
      expect(l.budgetSlack, inInclusiveRange(3, 7), reason: 'L${l.id}');
      expect(l.rotatorCount, greaterThan(0), reason: 'L${l.id}');
    }
    for (final l in levels.where((l) => l.world == 1)) {
      expect(l.snakes, isEmpty);
    }
    for (final l in levels.where((l) => l.world == 2)) {
      expect(l.snakes, isNotEmpty, reason: 'L${l.id}');
    }
    expect(levels[5].rotatorIntro, isTrue);
  });

  test('L1 teaches by play: some decoy is blocked at the start', () {
    final b = Board(levels.first);
    final path = Solver(b).solutionPath(b.fullMask)!.toSet();
    expect([
      for (var f = 0; f < b.frogCount; f++)
        if (!path.contains(f) && !b.canTap(b.fullMask, f)) f
    ], isNotEmpty);
  });

  test('worlds.json: 15-level worlds cover every level, landmarks, intro, short cards', () {
    final book = StoryBook.fromJson(jsonDecode(File('assets/worlds.json').readAsStringSync()) as Map<String, Object?>);
    expect(book.intro.length, 4);
    expect(book.worlds.map((w) => (w.first, w.last)), [(1, 15), (16, 30)]);
    for (final l in levels) {
      expect(book.worldOf(l.id)!.id, l.world, reason: 'L${l.id}');
    }
    for (final w in book.worlds) {
      expect(w.levelCount, 15);
      expect(w.landmark, isNotEmpty);
      expect(w.end, isNotNull);
    }
    final all = [
      ...book.intro,
      for (final w in book.worlds) ...[if (w.start != null) w.start!, if (w.end != null) w.end!, ...w.beats.values],
    ];
    for (final c in all) {
      expect(c.text.split(RegExp(r'\s+')).length, lessThanOrEqualTo(40), reason: c.key);
    }
    expect(book.cardsAfter(5).map((c) => c.key), ['w1_after5']);
    expect(book.cardsAfter(8), isEmpty);
    expect(book.cardsAfter(15).map((c) => c.key), ['w1_end', 'w2_start']);
    expect(book.cardsAfter(30).map((c) => c.key), ['w2_end']);
    expect(book.cardsAfter(3), isEmpty);
  });
}
