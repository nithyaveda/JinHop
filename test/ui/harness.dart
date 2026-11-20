import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/app_scope.dart';
import 'package:jinhop/core/core.dart';
import 'package:jinhop/services/level_repository.dart';
import 'package:jinhop/services/storage_service.dart';
import 'package:jinhop/ui/board_painter.dart';
import 'package:jinhop/ui/board_view.dart';
import 'package:jinhop/ui/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small story book for widget tests: world 1 = levels 1-2 (beat after 1),
/// world 2 = levels 3-4.
final testStory = StoryBook.fromJson({
  'intro': [
    {'scene': 'luck', 'text': 'Intro one.'},
    {'scene': 'storm', 'text': 'Intro two.'},
  ],
  'worlds': [
    {
      'id': 1,
      'name': 'Test Pond',
      'first': 1,
      'last': 2,
      'landmark': 'Test Bridge',
      'beats': [
        {'after': 1, 'scene': 'doudou', 'text': 'Story one.'}
      ],
      'end': {'scene': 'moon_bridge', 'text': 'Story two.'},
    },
    {
      'id': 2,
      'name': 'Test Marsh',
      'first': 3,
      'last': 4,
      'landmark': 'Test Shrine',
      'start': {'scene': 'marsh', 'text': 'Story three.'},
    },
  ],
});

/// Phone-sized view (1080x2160 px at 2.75 dpr = ~393x785 dp).
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2160);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

/// In-memory storage. Today's sign-in reward counts as already collected so
/// its card does not cover the board (pass 'signin_last' to override).
Future<StorageService> freshStorage([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues({'signin_last': dayNumber(DateTime.now()), ...values});
  return StorageService.open();
}

/// Pumps a GameScreen for [levels][0] (or [startId]) with in-memory storage.
Future<StorageService> pumpGame(WidgetTester tester, List<Level> levels,
    {int? startId, Map<String, Object> prefs = const {}}) async {
  phone(tester);
  final storage = await freshStorage(prefs);
  await tester.pumpWidget(AppScope(
    levels: LevelRepository(levels, testStory),
    storage: storage,
    child: MaterialApp(home: GameScreen(levelId: startId ?? levels.first.id)),
  ));
  await tester.pump();
  return storage;
}

/// Screen point of the frog standing on cell (x, y) of the 2.5D board.
Offset cellCenter(WidgetTester tester, int size, int x, int y) {
  final r = tester.getRect(find.byType(BoardView));
  return r.topLeft + BoardLayout(size, r.width).tapPoint(x, y);
}

Future<void> tapCell(WidgetTester tester, int size, int x, int y) async {
  await tester.tapAt(cellCenter(tester, size, x, y));
  await tester.pump(const Duration(milliseconds: 30));
}

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
