import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/core.dart';
import 'package:jinhop/main.dart';
import 'package:jinhop/services/audio_service.dart';
import 'package:jinhop/ui/auth_screens.dart';
import 'package:jinhop/ui/game_screen.dart';
import 'package:jinhop/ui/home_shell.dart';
import 'package:jinhop/ui/palette.dart';
import 'package:jinhop/ui/story_screens.dart';
import 'package:jinhop/ui/world_map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/fixtures.dart';
import 'harness.dart';

/// Lets the finale (golden leap, colour wash, bloom; about 2.6 s) play out.
Future<void> playFinale(WidgetTester tester) async {
  for (var i = 0; i < 70; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Several frames so page/route transitions actually run.
Future<void> frames(WidgetTester tester, [int ms = 800]) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> winFixtureB(WidgetTester tester) async {
  await tapCell(tester, 4, 2, 2);
  await tapCell(tester, 4, 2, 0);
  await tapCell(tester, 4, 0, 0);
}

void main() {
  group('launch', () {
    testWidgets('fresh install: onboarding, Login, guest, dashboard, world map, level 1', (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(JinHopApp(audioBackend: SilentAudioBackend()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(IntroScreen), findsOneWidget);
      // Page through: Next x3 then Begin.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('intro_next')));
        await frames(tester);
      }
      expect(find.text('Begin'), findsOneWidget);
      await tester.tap(find.byKey(const Key('intro_next')));
      await frames(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('login_guest')));
      await frames(tester);
      expect(find.byType(HomeShell, skipOffstage: false), findsOneWidget);
      // First day: the sign-in reward card.
      await frames(tester);
      // First day: the Lucky Day check-in. Tap the coin, then hop on.
      expect(find.byKey(const Key('lucky_day')), findsOneWidget);
      expect(find.byKey(const Key('lucky_go')), findsNothing);
      await tester.tap(find.byKey(const Key('lucky_coin')));
      await frames(tester, 1800);
      expect(find.byKey(const Key('lucky_reward')), findsOneWidget);
      expect(find.text('+$kSignInCoins'), findsOneWidget);
      expect(find.text('Lantern 1 is lit!'), findsOneWidget);
      await tester.tap(find.byKey(const Key('lucky_go')));
      await frames(tester);
      expect(find.byKey(const Key('lucky_day')), findsNothing);
      expect(find.byKey(const Key('dash_coins')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dash_map')));
      await frames(tester);
      expect(find.byType(WorldMapScreen), findsOneWidget);
      expect(textOf(tester, 'coins'), '$kSignInCoins');
      await tester.tap(find.byKey(const Key('tile_1')));
      await frames(tester);
      expect(find.byType(GameScreen), findsOneWidget);
      expect(textOf(tester, 'level_title'), 'Level 1');
      expect(find.byKey(const Key('timer')), findsNothing, reason: 'L1-5 have no clock');
    });

    testWidgets('intro can be skipped and is shown only once', (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(JinHopApp(audioBackend: SilentAudioBackend()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('intro_skip')));
      await frames(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('seen_intro'), isTrue);
    });

    testWidgets('returning player lands on the dashboard; the map and Play open the next level', (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues(
          {'seen_intro': true, 'signed_in': true, for (var i = 1; i <= 5; i++) 'stars_$i': 2});
      await tester.pumpWidget(JinHopApp(audioBackend: SilentAudioBackend()));
      await frames(tester, 400);
      expect(find.byType(HomeShell, skipOffstage: false), findsOneWidget);
      if (find.byKey(const Key('lucky_coin')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('lucky_coin')));
        await frames(tester, 1800);
        await tester.tap(find.byKey(const Key('lucky_go')));
        await frames(tester);
      }
      await tester.tap(find.byKey(const Key('dash_map')));
      await frames(tester);
      expect(find.byType(WorldMapScreen), findsOneWidget);
      if (find.byKey(const Key('lucky_coin')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('lucky_coin')));
        await frames(tester, 1800);
        await tester.tap(find.byKey(const Key('lucky_go')));
        await frames(tester);
      }
      await tester.tap(find.byKey(const Key('map_play')));
      await frames(tester);
      expect(textOf(tester, 'level_title'), 'Level 6');
      expect(textOf(tester, 'timer'), '1:00');
    });

    testWidgets('opens the world map when everything is done', (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({
        'seen_intro': true,
        'signed_in': true,
        'signin_last': dayNumber(DateTime.now()),
        for (var i = 1; i <= 30; i++) 'stars_$i': 3
      });
      await tester.pumpWidget(JinHopApp(audioBackend: SilentAudioBackend()));
      await frames(tester, 400);
      await tester.tap(find.byKey(const Key('dash_map')));
      await frames(tester);
      expect(find.byType(WorldMapScreen), findsOneWidget);
      expect(textOf(tester, 'total_stars'), '90 / 90');
    });
  });

  group('budget screens', () {
    testWidgets('restless banner appears, then the fail screen at cap + 1', (tester) async {
      await pumpGame(tester, [fixtureB(budgetSlack: 2)]); // cap 5, par 3
      await tapCell(tester, 4, 0, 3); // D1
      await tapCell(tester, 4, 3, 3); // D3: 2 used, 3 left, need 3
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('restless')), findsNothing);
      await tapCell(tester, 4, 1, 3); // D2: 3 used, 2 left, need 3
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('restless')), findsOneWidget);
      expect(find.text('The pond is restless. Begin again?'), findsOneWidget);

      // Banner is non-blocking: the board still plays.
      await tapCell(tester, 4, 2, 2); // B: 4 used
      await tapCell(tester, 4, 2, 0); // A: 5 used = cap
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fail')), findsNothing);
      await tapCell(tester, 4, 0, 0); // golden would be the 6th petal
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('fail')), findsOneWidget);
      expect(textOf(tester, 'fail_reason'), 'Out of hops!');
      expect(find.text('The pond rests. Try again?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fail_retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fail')), findsNothing);
      expect(textOf(tester, 'hops_used'), 'used 0');
    });

    testWidgets('restless banner Restart works', (tester) async {
      await pumpGame(tester, [fixtureB(budgetSlack: 2)]);
      await tapCell(tester, 4, 0, 3);
      await tapCell(tester, 4, 3, 3);
      await tapCell(tester, 4, 1, 3);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('restless_undo')), findsNothing);
      await tester.tap(find.byKey(const Key('restless_restart')));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'hops_used'), 'used 0');
      expect(find.byKey(const Key('restless')), findsNothing);
    });

    testWidgets('countdown: turns red at 15 s, fails at 0, pauses with the menu, retry resets', (tester) async {
      await pumpGame(tester, [fixtureB().copyWith(world: 1)]);
      expect(textOf(tester, 'timer'), '1:00');
      await tester.pump(const Duration(seconds: 44));
      await tester.pump();
      expect(textOf(tester, 'timer'), '0:16');
      expect(tester.widget<Text>(find.byKey(const Key('timer'))).style!.color, isNot(Jin.red));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(textOf(tester, 'timer'), '0:15');
      expect(tester.widget<Text>(find.byKey(const Key('timer'))).style!.color, Jin.red);
      // Paused: the clock waits.
      await tester.tap(find.byKey(const Key('pause')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      await tester.tap(find.byKey(const Key('pause_resume')));
      await tester.pump();
      expect(textOf(tester, 'timer'), '0:15');
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(find.byKey(const Key('fail')), findsOneWidget);
      expect(textOf(tester, 'fail_reason'), "Time's up!");
      await tester.tap(find.byKey(const Key('fail_retry')));
      await tester.pump();
      expect(textOf(tester, 'timer'), '1:00');
    });
  });

  group('win', () {
    testWidgets('finale first, then the story beat, then the celebration; progress saved', (tester) async {
      final l1 = fixtureB().copyWith(id: 1);
      final l2 = fixtureB().copyWith(id: 2);
      final storage = await pumpGame(tester, [l1, l2]);
      await winFixtureB(tester);
      // During the finale nothing else is shown yet.
      await frames(tester);
      expect(find.byKey(const Key('finale_skip')), findsOneWidget);
      expect(find.byKey(const Key('win')), findsNothing);
      await playFinale(tester);

      expect(find.text('Story one.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('story')));
      await frames(tester);
      expect(find.byKey(const Key('win')), findsOneWidget);
      expect(textOf(tester, 'win_used'), '3 hops');
      expect(textOf(tester, 'win_title'), 'Level 1 complete!');
      expect(storage.record(1)!.stars, 3);
      expect(textOf(tester, 'win_coins'), '+${kFirstClearCoins + 3 * kCoinsPerNewStar}');
      expect(storage.coins, kFirstClearCoins + 3 * kCoinsPerNewStar);
      expect(storage.seen('story_w1_after1'), isTrue);

      await tester.tap(find.byKey(const Key('win_next')));
      await frames(tester);
      expect(textOf(tester, 'level_title'), 'Level 2');
    });

    testWidgets('the finale can be skipped after 1 second', (tester) async {
      final l1 = fixtureB().copyWith(id: 3);
      await pumpGame(tester, [l1]);
      await winFixtureB(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('finale_skip'))); // too early: ignored
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('finale_skip')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.tap(find.byKey(const Key('finale_skip')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('finale_skip')), findsNothing);
      expect(find.byKey(const Key('win')), findsOneWidget);
    });

    testWidgets('world end: landmark card then the next world opens', (tester) async {
      final l2 = fixtureB().copyWith(id: 2);
      final l3 = fixtureB().copyWith(id: 3, world: 2);
      await pumpGame(tester, [l2, l3]);
      await winFixtureB(tester);
      await playFinale(tester);
      // The world's ending plays as the animated revival, text last.
      expect(find.byKey(const Key('revival')), findsOneWidget);
      expect(find.text('Story two.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('revival'))); // too early to continue: skips to the end
      await frames(tester, 2000);
      expect(find.byKey(const Key('revival')), findsOneWidget);
      await tester.tap(find.byKey(const Key('revival')));
      await frames(tester);
      expect(find.text('Story three.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('story')));
      await frames(tester);
      expect(textOf(tester, 'win_title'), 'Test Pond is alive!');
    });

    testWidgets('the world-end revival plays every time the world is finished', (tester) async {
      final l2 = fixtureB().copyWith(id: 2);
      await pumpGame(tester, [l2], prefs: {'seen_story_w1_end': true, 'stars_2': 3});
      await winFixtureB(tester);
      await playFinale(tester);
      expect(find.byKey(const Key('revival')), findsOneWidget);
    });

    testWidgets('a story card is shown only once', (tester) async {
      final l1 = fixtureB().copyWith(id: 1);
      await pumpGame(tester, [l1], prefs: {'seen_story_w1_after1': true});
      await winFixtureB(tester);
      await playFinale(tester);
      expect(find.text('Story one.'), findsNothing);
      expect(find.byKey(const Key('win')), findsOneWidget);
    });
  });

  testWidgets('pause -> world map -> level tile', (tester) async {
    final l1 = fixtureB().copyWith(id: 1);
    final l2 = fixtureB().copyWith(id: 2);
    await pumpGame(tester, [l1, l2], prefs: {'stars_1': 2});
    await tester.tap(find.byKey(const Key('pause')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pause_map')));
    await frames(tester);
    expect(find.byType(WorldMapScreen), findsOneWidget);
    expect(textOf(tester, 'total_stars'), '2 / 6');
    await tester.tap(find.byKey(const Key('tile_2')));
    await frames(tester);
    expect(textOf(tester, 'level_title'), 'Level 2');
  });
}
