import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/ui/board_view.dart';

import '../core/fixtures.dart';
import 'harness.dart';

void main() {
  testWidgets('cells are at least 48dp even on a 7x7 board', (tester) async {
    await pumpGame(tester, [fixtureB()]);
    expect(tester.getRect(find.byType(BoardView)).width / 7, greaterThanOrEqualTo(48));
  });

  testWidgets('blocked tap shakes and costs nothing; valid tap costs 1', (tester) async {
    await pumpGame(tester, [fixtureB()]);
    expect(textOf(tester, 'hops_used'), 'used 0');
    await tapCell(tester, 4, 2, 0); // A, blocked by B
    await tester.pumpAndSettle(); // shake ends and the ticker stops
    expect(textOf(tester, 'hops_used'), 'used 0');
    await tapCell(tester, 4, 2, 2); // B, free
    await tester.pumpAndSettle();
    expect(textOf(tester, 'hops_used'), 'used 1');
  });

  testWidgets('HUD shows the hop target, there is no undo, restart resets', (tester) async {
    await pumpGame(tester, [fixtureB()]);
    expect(textOf(tester, 'hops_target'), 'Hops: 3');
    expect(find.byKey(const Key('undo')), findsNothing);
    await tapCell(tester, 4, 2, 2);
    await tester.pumpAndSettle();
    expect(textOf(tester, 'hops_used'), 'used 1');
    await tester.tap(find.byKey(const Key('restart')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'hops_used'), 'used 0');
  });

  testWidgets('long-press previews a ray without tapping', (tester) async {
    await pumpGame(tester, [fixtureB()]);
    final g = await tester.startGesture(cellCenter(tester, 4, 0, 0));
    await tester.pump(const Duration(milliseconds: 700));
    await g.up();
    await tester.pumpAndSettle();
    expect(textOf(tester, 'hops_used'), 'used 0');
  });

  testWidgets('hints: 2 free, then they cost coins', (tester) async {
    final storage = await pumpGame(tester, [fixtureB()], prefs: {'coins': 30});
    expect(textOf(tester, 'hints_left'), '2');
    await tester.tap(find.byKey(const Key('hint')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(textOf(tester, 'hops_used'), 'used 0', reason: 'a hint costs no hops');
    expect(textOf(tester, 'hints_left'), '1');
    await tester.tap(find.byKey(const Key('hint')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(textOf(tester, 'hints_left'), '1', reason: 'tapping again while it shows spends nothing');
    await tapCell(tester, 4, 2, 2); // following the hint clears it
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hint')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('hint_price')), findsOneWidget);
    await tapCell(tester, 4, 2, 0); // A, now free
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hint')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('buy_hint')), findsOneWidget);
    await tester.tap(find.byKey(const Key('buy_hint_ok')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(storage.coins, 10);
    expect(find.byKey(const Key('buy_hint')), findsNothing);
  });
}
