// Renders key screens with real fonts for review and the user guide.
//   flutter test tool/render_screens_test.dart   -> docs/screens/*.png

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/app_scope.dart';
import 'package:jinhop/core/core.dart';
import 'package:jinhop/services/level_repository.dart';
import 'package:jinhop/services/storage_service.dart';
import 'package:jinhop/ui/board_painter.dart';
import 'package:jinhop/ui/board_view.dart';
import 'package:jinhop/ui/game_screen.dart';
import 'package:jinhop/ui/settings_screen.dart';
import 'package:jinhop/ui/story_screens.dart';
import 'package:jinhop/ui/theme.dart';
import 'package:jinhop/ui/world_map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/core/fixtures.dart';
import 'real_fonts.dart';

Future<void> shot(WidgetTester tester, GlobalKey key, String name) => tester.runAsync(() async {
      final rb = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await rb.toImage(pixelRatio: 1.5);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('docs/screens/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });

Future<(GlobalKey, List<Level>, StoryBook)> pump(WidgetTester tester, Widget home, Map<String, Object> prefs,
    {List<Level>? levels}) async {
  tester.view.physicalSize = const Size(1080, 2160);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.runAsync(loadRealFonts);
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({'signin_last': dayNumber(DateTime.now()), ...prefs});
  final storage = await StorageService.open();
  final ls = levels ?? loadLevels();
  final story = StoryBook.fromJson(
      jsonDecode(File('assets/worlds.json').readAsStringSync()) as Map<String, Object?>);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: AppScope(
      levels: LevelRepository(ls, story),
      storage: storage,
      child: MaterialApp(theme: jinhopTheme(), debugShowCheckedModeBanner: false, home: home),
    ),
  ));
  await frames(tester, 600);
  return (key, ls, story);
}

Future<void> frames(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tapFrog(WidgetTester tester, Level l, int f) async {
  final r = tester.getRect(find.byType(BoardView));
  final fr = l.frogs[f];
  await tester.tapAt(r.topLeft + BoardLayout(l.size, r.width).tapPoint(fr.x, fr.y));
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('world map (world 1 in progress)', (tester) async {
    final prefs = <String, Object>{
      for (var i = 1; i <= 9; i++) 'stars_$i': i % 3 + 1,
    };
    final (key, _, _) = await pump(tester, const WorldMapScreen(), prefs);
    await shot(tester, key, 'world_map');
  });

  testWidgets('world map (world 1 complete, landmark lit)', (tester) async {
    final prefs = <String, Object>{
      for (var i = 1; i <= 15; i++) 'stars_$i': 3,
    };
    final (key, _, _) = await pump(tester, const WorldMapScreen(), prefs);
    await tester.drag(find.byKey(const Key('map_scroll')), const Offset(0, -500));
    await frames(tester, 300);
    await shot(tester, key, 'world_map_landmark');
    await tester.drag(find.byKey(const Key('map_scroll')), const Offset(0, 1400));
    await frames(tester, 300);
    await shot(tester, key, 'world_map_w2');
  });

  testWidgets('world map (all done, shrine lit)', (tester) async {
    final prefs = <String, Object>{
      for (var i = 1; i <= 30; i++) 'stars_$i': 3,
    };
    final (key, _, _) = await pump(tester, const WorldMapScreen(), prefs);
    await tester.drag(find.byKey(const Key('map_scroll')), const Offset(0, 800));
    await frames(tester, 300);
    await shot(tester, key, 'world_map_shrine');
  });

  testWidgets('intro + every story scene', (tester) async {
    final (key, _, story) = await pump(tester, const SizedBox(), {});
    final cards = [
      ...story.intro,
      for (final w in story.worlds) ...[if (w.start != null) w.start!, ...w.beats.values, if (w.end != null) w.end!],
    ];
    for (final c in cards) {
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: jinhopTheme(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: StoryOverlay(card: c, onDismiss: () {})),
        ),
      ));
      await frames(tester, 900);
      await shot(tester, key, 'story_${c.key}');
    }
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
          theme: jinhopTheme(),
          debugShowCheckedModeBanner: false,
          home: IntroScreen(cards: story.intro, onDone: () {})),
    ));
    await frames(tester, 400);
    await shot(tester, key, 'intro');
  });

  testWidgets('settings', (tester) async {
    final (key, _, _) = await pump(tester, const SettingsScreen(), {});
    await shot(tester, key, 'settings');
  });

  testWidgets('hint, timer, restless, out of hops, time up (level 6)', (tester) async {
    final levels = loadLevels();
    final l6 = levels[5];
    final (key, _, _) = await pump(tester, const GameScreen(levelId: 6), {'seen_rotator_intro': true, 'coins': 45});
    await tester.tap(find.byKey(const Key('hint')));
    await frames(tester, 700);
    await shot(tester, key, 'hint');
    final b = Board(l6);
    var m = b.fullMask;
    final path = Solver(b).solutionPath(m)!;
    // Follow the hint, then let the clock run into the red.
    await tapFrog(tester, l6, path.first);
    m &= ~(1 << path.first);
    await tester.pump(const Duration(seconds: 46));
    await frames(tester, 300);
    await shot(tester, key, 'timer_red');
    await tester.tap(find.byKey(const Key('restart')));
    await frames(tester, 300);
    m = b.fullMask;
    // Waste petals on free decoys until the pond is restless.
    var tapped = 0;
    while (tapped < 8) {
      final decoys = b.tappableFrogs(m).where((f) => !path.contains(f) && f != b.goldenIndex).toList();
      if (decoys.isEmpty) break;
      await tapFrog(tester, l6, decoys.first);
      m &= ~(1 << decoys.first);
      tapped++;
      if (find.byKey(const Key('restless')).evaluate().isNotEmpty) break;
    }
    await shot(tester, key, 'restless');
    // Keep hopping until the pond rests.
    var guard = 0;
    while (find.byKey(const Key('fail')).evaluate().isEmpty && guard++ < 30) {
      final free = b.tappableFrogs(m).where((f) => f != b.goldenIndex).toList();
      if (free.isEmpty) break;
      await tapFrog(tester, l6, free.first);
      m &= ~(1 << free.first);
    }
    await tester.pump(const Duration(milliseconds: 1200));
    await shot(tester, key, 'fail');
    if (find.byKey(const Key('fail_retry')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('fail_retry')));
    } else {
      await tester.tap(find.byKey(const Key('restart')));
    }
    await frames(tester, 300);
    await tester.pump(const Duration(seconds: 61));
    await frames(tester, 1200);
    await shot(tester, key, 'fail_time');
  });

  testWidgets('buying a hint', (tester) async {
    final (key, _, _) = await pump(tester, const GameScreen(levelId: 6), {'seen_rotator_intro': true, 'coins': 45});
    await frames(tester, 600);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const Key('hint')));
      await frames(tester, 300);
      await tester.tap(find.byKey(const Key('restart')));
      await frames(tester, 300);
    }
    await shot(tester, key, 'hint_buy_button');
    await tester.tap(find.byKey(const Key('hint')));
    await frames(tester, 600);
    await shot(tester, key, 'buy_hint');
  });

  for (final id in const [1, 15]) {
    testWidgets('finale then win (level $id)', (tester) async {
      final levels = loadLevels();
      final l = levels[id - 1];
      final (key, _, _) = await pump(tester, GameScreen(levelId: id), {'seen_rotator_intro': true});
      await shot(tester, key, 'board_$id');
      final b = Board(l);
      final path = Solver(b).solutionPath(b.fullMask)!;
      for (final f in path) {
        await tester.tapAt(tester.getRect(find.byType(BoardView)).topLeft +
            BoardLayout(l.size, tester.getRect(find.byType(BoardView)).width).tapPoint(l.frogs[f].x, l.frogs[f].y));
        await frames(tester, 100);
      }
      // Finale frames (golden leap, wash, bloom).
      for (final at in const [300, 900, 1600, 2600]) {
        await frames(tester, at == 300 ? 300 : (at == 900 ? 600 : (at == 1600 ? 700 : 1000)));
        await shot(tester, key, 'finale_${id}_$at');
      }
      await frames(tester, 1000);
      if (find.byKey(const Key('revival')).evaluate().isNotEmpty) {
        for (final at in const [800, 2200, 3800, 5200, 7600]) {
          await frames(tester, at == 800 ? 800 : (at == 2200 ? 1400 : (at == 3800 ? 1600 : (at == 5200 ? 1400 : 2400))));
          await shot(tester, key, 'revival_${id}_$at');
        }
        await tester.tap(find.byKey(const Key('revival')));
        await frames(tester, 900);
      }
      var n = 0;
      while (find.byKey(const Key('story')).evaluate().isNotEmpty && n < 4) {
        await tester.tap(find.byKey(const Key('story')));
        await frames(tester, 900);
        n++;
      }
      await frames(tester, 2000);
      await shot(tester, key, 'win_$id');
    });
  }
}
