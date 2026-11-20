import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/core.dart';

import 'fixtures.dart';

const configs = <String, GeneratorConfig>{
  'w1 core 6x6': GeneratorConfig(size: 6, frogCount: 12, chainLength: 6),
  'w1 rotators 6x6': GeneratorConfig(
      size: 6, frogCount: 14, chainLength: 8, rotatorCount: 3, requireRotatorOnChain: true),
  'w2 7x7 snakes': GeneratorConfig(
      size: 7, frogCount: 18, chainLength: 10, rotatorCount: 4, snakeCount: 3, requireRotatorOnChain: true),
};

void main() {
  group('generator cycle prevention', () {
    for (final entry in configs.entries) {
      test('${entry.key}: 25 seeds, every level acyclic and solvable', () {
        const gen = LevelGenerator();
        for (var seed = 1; seed <= 25; seed++) {
          final g = gen.generate(entry.value, seed: seed);
          expect(g, isNotNull, reason: 'seed $seed produced no level');
          final b = Board(g!.level);
          final order = g.intendedOrder;

          // The intended (reverse-built) order is a valid winning line.
          expect(LevelGenerator.replays(b, order), isTrue, reason: 'seed $seed');

          // Must-clear-first graph of that line is acyclic: every frog on a
          // chain frog's ray (at the moment it is tapped) is removed earlier.
          final stepOf = {for (var i = 0; i < order.length; i++) order[i]: i};
          for (var i = 0; i < order.length; i++) {
            final f = order[i];
            final d = b.facingAtCount(f, i);
            final blockers = b.rayFrogMask(f, d);
            expect(b.raySnake(f, d), isFalse);
            for (var o = 0; o < b.frogCount; o++) {
              if ((blockers >> o) & 1 == 1) {
                expect(stepOf.containsKey(o) && stepOf[o]! < i, isTrue,
                    reason: 'seed $seed: frog $o blocks $f but is not cleared before it');
              }
            }
          }

          // Never deadlocked from the start, and passes every rule.
          expect(Solver(b).minRemaining(b.fullMask), isNotNull);
          final v = LevelValidator.validate(g.level);
          expect(v.ok, isTrue, reason: 'seed $seed: $v');
          expect(g.level.par, lessThanOrEqualTo(order.length));
        }
      });
    }

    test('same seed gives the same level (daily puzzle determinism)', () {
      const gen = LevelGenerator();
      final cfg = configs['w1 rotators 6x6']!;
      final a = gen.generate(cfg, seed: 20261027)!;
      final b = gen.generate(cfg, seed: 20261027)!;
      expect(jsonEncode(a.level.toJson()), jsonEncode(b.level.toJson()));
      final c = gen.generate(cfg, seed: 20261028)!;
      expect(jsonEncode(c.level.toJson()), isNot(jsonEncode(a.level.toJson())));
    });
  });

  group('validator', () {
    test('rejects par < 4', () {
      final v = LevelValidator.validate(fixtureB().copyWith(par: 3));
      expect(v.ok, isFalse);
      expect(v.errors.join(), contains('par 3 < 4'));
    });

    test('rejects a 6x6 board with fewer than 12 frogs', () {
      final l = ascii([
        'e . S . . .',
        '. . . . . .',
        '. . E . . .',
        'S W . N . .',
        '. . . . . .',
        '. . . . . .',
      ], par: 3);
      final v = LevelValidator.validate(l);
      expect(v.errors.join(), contains('6x6 board has 6 frogs'));
    });

    test('rejects too few decoys and a wrong stored par', () {
      // 12 frogs: golden + 10 that must all leave first + 1 decoy.
      final l = ascii([
        'e S S S S S',
        '. S S S S S',
        '. . . . . .',
        '. . . . . .',
        '. . . . . .',
        'N . . . . .',
      ], par: 99);
      final v = LevelValidator.validate(l);
      expect(v.ok, isFalse);
      expect(v.solvedPar, 11);
      expect(v.errors.join(' '), contains('decoys 1/12'));
      expect(v.errors.join(' '), contains('stored par 99'));
    });

    test('budgetSlack must be 99 or 3-7', () {
      final cfg = configs['w1 core 6x6']!;
      final g = const LevelGenerator().generate(cfg, seed: 3)!;
      expect(LevelValidator.validate(g.level.copyWith(budgetSlack: 2)).ok, isFalse);
      expect(LevelValidator.validate(g.level.copyWith(budgetSlack: 8)).ok, isFalse);
      expect(LevelValidator.validate(g.level.copyWith(budgetSlack: 3)).ok, isTrue);
      expect(LevelValidator.validate(g.level.copyWith(budgetSlack: 99)).ok, isTrue);
    });
  });
}
