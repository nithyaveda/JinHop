// Dev tool: renders the Lucky Day check-in (before / after tap) for review.
//   flutter test tool/render_lucky_day_test.dart -> docs/screens/lucky_day_*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/ui/lucky_day.dart';
import 'package:jinhop/ui/theme.dart';

import 'real_fonts.dart';

void main() {
  for (final revealed in const [false, true]) {
    testWidgets('lucky day revealed=$revealed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.runAsync(loadRealFonts);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: jinhopTheme(),
          debugShowCheckedModeBanner: false,
          home: LuckyDayScreen(
            streak: 4,
            cycleDay: 4,
            reward: 5,
            revealed: revealed,
            onClaim: () async {},
            onDone: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() async {
        final rb = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await rb.toImage(pixelRatio: 1.5);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('docs/screens/lucky_day_${revealed ? 'after' : 'before'}.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
