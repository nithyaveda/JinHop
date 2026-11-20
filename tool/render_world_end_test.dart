// Dev tool: world-ending story card mock frames.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/ui/art/landmark_scene.dart';
import 'package:jinhop/ui/palette.dart';
import 'package:jinhop/ui/theme.dart';

import 'real_fonts.dart';

class _P extends CustomPainter {
  final String l;
  final double a;
  _P(this.l, this.a);
  @override
  void paint(Canvas c, Size s) => LandmarkScene.draw(c, s, l, a, 0.3);
  @override
  bool shouldRepaint(_P o) => true;
}

Widget card(String landmark, double a, String title, String line) => Scaffold(
      backgroundColor: const Color(0xFF14302A),
      body: Column(children: [
        Expanded(
          flex: 7,
          child: Stack(fit: StackFit.expand, children: [
            CustomPaint(painter: _P(landmark, a)),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x0014302A), Color(0xFF14302A)]),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          flex: 3,
          child: Opacity(
            opacity: ((a - 0.7) / 0.3).clamp(0.0, 1.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Jin.goldLight, fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(line,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Jin.cream.withAlpha(225), fontSize: 18, height: 1.35)),
                const Spacer(),
                Text('Tap to continue', style: TextStyle(color: Jin.cream.withAlpha(150), fontSize: 15)),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ),
      ]),
    );

void main() {
  final frames = [
    ('moon_bridge', 0.0, 'bridge_0'),
    ('moon_bridge', 0.45, 'bridge_1'),
    ('moon_bridge', 1.0, 'bridge_2'),
    ('lantern_shrine', 0.0, 'shrine_0'),
    ('lantern_shrine', 1.0, 'shrine_2'),
  ];
  for (final f in frames) {
    testWidgets('world end ${f.$3}', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.runAsync(loadRealFonts);
      final key = GlobalKey();
      final bridge = f.$1 == 'moon_bridge';
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: jinhopTheme(),
          debugShowCheckedModeBanner: false,
          home: card(f.$1, f.$2, bridge ? 'Misty Pond is alive!' : 'Lantern Marsh is alive!',
              bridge ? 'The mist lifts. The Moon Bridge glows again.' : 'A thousand lanterns light the shrine.'),
        ),
      ));
      await tester.pump();
      await tester.runAsync(() async {
        final rb = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await rb.toImage(pixelRatio: 1.2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('build/preview/world_end_${f.$3}.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
