// Dev tool, not part of the test suite. Renders screens to PNG for visual
// review:  flutter test tool/render_board_preview_test.dart
// Output: build/preview/*.png

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
import 'package:jinhop/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'real_fonts.dart';

import '../test/core/fixtures.dart';

void main() {
  for (final id in const [1, 16]) {
    testWidgets('render level $id', (tester) async {
      tester.view.physicalSize = const Size(1080, 2160);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.runAsync(loadRealFonts);
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({"seen_rotator_intro": true});
      final storage = await StorageService.open();
      final levels = loadLevels();
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: AppScope(
          levels: LevelRepository(levels),
          storage: storage,
          child: MaterialApp(theme: jinhopTheme(), debugShowCheckedModeBanner: false, home: GameScreen(levelId: id)),
        ),
      ));
      await tester.pumpAndSettle();

      Future<void> shot(String name) async {
        await tester.runAsync(() async {
          final rb = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await rb.toImage(pixelRatio: 1.5);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('build/preview/$name.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }

      await shot('L${id}_start');
      final level = levels[id - 1];
      final rect = tester.getRect(find.byType(BoardView));
      final lay = BoardLayout(level.size, rect.width);
      Offset at(Frog f) => rect.topLeft + lay.tapPoint(f.x, f.y);

      // Play the solver's line except the last move, catching one mid-hop.
      final b = Board(level);
      final path = Solver(b).solutionPath(b.fullMask)!;
      for (var i = 0; i < path.length - 1; i++) {
        await tester.tapAt(at(level.frogs[path[i]]));
        await tester.pump(Duration(milliseconds: i == 0 ? 160 : 20));
        if (i == 0) await shot('L${id}_mid_hop');
        await tester.pumpAndSettle();
      }
      await shot('L${id}_before_win');
      // Winning tap, then catch the finale: frogs hopping back, Jin Chan's
      // leap with the colour wash, and the fully bloomed pond.
      await tester.tapAt(at(level.frogs[path.last]));
      for (final ms in const [900, 1600, 2700, 5200]) {
        var t = 0;
        while (t < ms) {
          await tester.pump(const Duration(milliseconds: 50));
          t += 50;
        }
        await shot('L${id}_finale_$ms');
      }
    });
  }
}
