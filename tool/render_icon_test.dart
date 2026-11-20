// Renders the launcher icons from the game's own vector art.
//   flutter test tool/render_icon_test.dart
// Writes android/app/src/main/res/mipmap-*/ic_launcher(.png|_foreground.png)
// and docs/store/icon_512.png.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/models.dart';
import 'package:jinhop/ui/art/pond.dart';
import 'package:jinhop/ui/art/sprites.dart';
import 'package:jinhop/ui/palette.dart';

/// Draws the emblem (lily pad, cute Jin Chan, two lotuses) centred in a
/// [size] square; [content] is the fraction of the square it fills.
void paintEmblem(ui.Canvas c, double size, double content) {
  final w = size * content;
  c.save();
  c.translate(size / 2, size / 2 + w * 0.2);
  final ring = ui.Paint()
    ..color = Jin.jade.withAlpha(60)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = size * 0.012;
  c.save();
  c.scale(1, 0.55);
  c.drawCircle(ui.Offset.zero, w * 0.55, ring);
  c.restore();
  c.save();
  c.scale(w / 100 * 1.05, w / 100 * 1.05);
  PondArt.pad(c, alive: true);
  c.restore();
  for (final (dx, s) in const [(-0.36, 0.2), (0.38, 0.16)]) {
    c.save();
    c.translate(w * dx, w * 0.05);
    c.scale(w / 100 * s, w / 100 * s);
    PondArt.lotus(c, deep: dx < 0);
    c.restore();
  }
  c.translate(0, w * 0.06);
  Sprites.frog(c, Facing.s, w * 0.62, golden: true);
  c.restore();
}

Future<void> writePng(String path, int px, void Function(ui.Canvas c, double s) draw) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  draw(c, px.toDouble());
  final img = await rec.endRecording().toImage(px, px);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('render icons', (tester) async {
    await tester.runAsync(() async {
      const res = 'android/app/src/main/res';
      const dens = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
      for (final e in dens.entries) {
        // Legacy icon: 48dp, cream rounded square with the emblem.
        final legacy = (48 * e.value).round();
        await writePng('$res/mipmap-${e.key}/ic_launcher.png', legacy, (c, s) {
          final bg = ui.Paint()..color = Jin.cream;
          c.drawRRect(ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(0, 0, s, s), ui.Radius.circular(s * 0.22)), bg);
          paintEmblem(c, s, 0.9);
        });
        // Adaptive foreground: 108dp canvas, art inside the 66dp safe zone.
        final fg = (108 * e.value).round();
        await writePng('$res/mipmap-${e.key}/ic_launcher_foreground.png', fg, (c, s) => paintEmblem(c, s, 0.6));
      }
      await writePng('docs/store/icon_512.png', 512, (c, s) {
        c.drawRect(ui.Rect.fromLTWH(0, 0, s, s), ui.Paint()..color = Jin.cream);
        paintEmblem(c, s, 0.86);
      });
    });
    expect(math.max(1, 0), 1);
  });
}
