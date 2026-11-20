// Exports the in-app How to Play cards as PNGs for the written user guide,
// straight from the real widgets:  flutter test tool/render_how_to_play_test.dart
// Output: docs/how_to_play/card_<n>.png

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/app_scope.dart';
import 'package:jinhop/services/level_repository.dart';
import 'package:jinhop/services/storage_service.dart';
import 'package:jinhop/ui/how_to_play_screen.dart';
import 'package:jinhop/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'real_fonts.dart';

/// Moment in each card's loop that best shows the rule (ms after open).
const moments = [1800, 2300, 3000, 3200, 4400];

void main() {
  for (var i = 0; i < howToCards.length; i++) {
    testWidgets('card ${i + 1}', (tester) async {
      tester.view.physicalSize = const Size(1080, 2160);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.runAsync(loadRealFonts);
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.open();
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: AppScope(
          levels: LevelRepository(const []),
          storage: storage,
          child: MaterialApp(theme: jinhopTheme(), debugShowCheckedModeBanner: false, home: HowToPlayScreen(initialPage: i)),
        ),
      ));
      var t = 0;
      while (t < moments[i]) {
        await tester.pump(const Duration(milliseconds: 50));
        t += 50;
      }
      await tester.runAsync(() async {
        final rb = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await rb.toImage(pixelRatio: 1.5);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('docs/how_to_play/card_${i + 1}.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
    });
  }
}
