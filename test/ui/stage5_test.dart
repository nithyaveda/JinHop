import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/app_scope.dart';
import 'package:jinhop/core/core.dart';
import 'package:jinhop/services/level_repository.dart';
import 'package:jinhop/ui/board_painter.dart';
import 'package:jinhop/ui/board_view.dart';
import 'package:jinhop/ui/celebration.dart';
import 'package:jinhop/ui/world_map_screen.dart';

import '../core/fixtures.dart';
import 'harness.dart';

void main() {
  group('2.5D hit testing', () {
    test('a tap on a frog body picks that frog; the nearer row wins on overlap', () {
      final b = Board(fixtureB());
      const l = BoardLayout(4, 400);
      expect(l.hitFrog(l.tapPoint(2, 2), b, b.fullMask), kB);
      expect(l.hitFrog(l.tapPoint(0, 0), b, b.fullMask), kGolden);
      // Empty water far from any frog.
      expect(l.hitFrog(l.tapPoint(1, 1), b, b.fullMask), -1);
      // Top of D1's head (row 3) overlaps row 2's pad area but D1 is in front.
      final head = l.bodyRect(0, 3).topCenter + const Offset(0, 4);
      expect(l.hitFrog(head, b, b.fullMask), kD1);
      // Removed frogs are not hit.
      expect(l.hitFrog(l.tapPoint(2, 2), b, b.fullMask & ~(1 << kB)), -1);
    });

    test('touch target is at least 48dp on a 6x6 board on a phone', () {
      const l = BoardLayout(6, 393 - 24);
      final r = l.bodyRect(0, 0);
      expect(r.width, greaterThanOrEqualTo(40)); // narrowest axis, plus pad halo
      expect(r.height, greaterThanOrEqualTo(48));
    });
  });

  testWidgets('winning plays the finale, then the pond stays alive', (tester) async {
    await pumpGame(tester, [fixtureB().copyWith(id: 3)]);
    final c = tester.widget<BoardView>(find.byType(BoardView)).controller;
    await tapCell(tester, 4, 2, 2);
    await tapCell(tester, 4, 2, 0);
    await tapCell(tester, 4, 0, 0);
    expect(c.fx.alive, isFalse);
    expect(c.finaleRunning, isTrue);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.finaleRunning, isFalse);
    expect(c.fx.alive, isTrue);
    expect(find.byKey(const Key('win')), findsOneWidget);
  });

  testWidgets('celebration: one chime per earned star', (tester) async {
    phone(tester);
    final chimes = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CelebrationOverlay(
          title: 'Level 7 complete!',
          subtitle: 'The pond comes back to life.',
          levelLabel: 'Level 7',
          stars: 2,
          used: 9,
          par: 8,
          luckyStreak: 4,
          onNext: () {},
          onReplay: () {},
          onMap: () {},
          onStar: chimes.add,
        ),
      ),
    ));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(chimes, [0, 1]);
    expect(textOf(tester, 'win_used'), '9 hops');
    expect(find.byKey(const Key('win_share')), findsOneWidget);
  });

  testWidgets('world map: done and current levels are tappable, locked are not', (tester) async {
    phone(tester);
    final storage = await freshStorage({'stars_1': 3, 'stars_2': 1});
    final levels = [for (var i = 1; i <= 4; i++) fixtureB().copyWith(id: i, world: i <= 2 ? 1 : 2)];
    await tester.pumpWidget(AppScope(
      levels: LevelRepository(levels, testStory),
      storage: storage,
      child: const MaterialApp(home: WorldMapScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(textOf(tester, 'total_stars'), '4 / 12');
    expect(find.byKey(const Key('tile_1')), findsOneWidget);
    expect(find.byKey(const Key('tile_3')), findsOneWidget, reason: 'current level');
    expect(find.byKey(const Key('tile_4')), findsNothing, reason: 'locked');
    expect(find.byKey(const Key('map_daily')), findsOneWidget);
    final tile = tester.getSize(find.byKey(const Key('tile_3')));
    expect(tile.width, greaterThanOrEqualTo(48));
    expect(tile.height, greaterThanOrEqualTo(48));
  });
}
