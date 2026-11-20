// Dev tool: Jin Chan (coin in mouth) on lily pads, for review.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/models.dart';
import 'package:jinhop/ui/art/pond.dart';
import 'package:jinhop/ui/art/sprites.dart';

void main() {
  test('render jin chan hero', () async {
    const w = 1600.0, h = 900.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(
        const Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, h),
              [const Color(0xFFCFEDE3), const Color(0xFF6FB8A3)]));
    void pad(double x, double y, double s) {
      c.save();
      c.translate(x, y);
      c.scale(s, s);
      PondArt.pad(c, alive: true);
      c.restore();
    }

    void lotus(double x, double y, double s) {
      c.save();
      c.translate(x, y);
      c.scale(s, s);
      PondArt.lotus(c);
      c.restore();
    }

    pad(500, 640, 4.2);
    pad(1150, 660, 3.4);
    lotus(160, 760, 1.6);
    lotus(1460, 770, 1.4);
    c.save();
    c.translate(500, 655);
    Sprites.frog(c, Facing.s, 440, golden: true, shadow: false);
    c.restore();
    c.save();
    c.translate(1150, 672);
    Sprites.frog(c, Facing.e, 380, golden: true, shadow: false);
    c.restore();
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/preview/jinchan_hero.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
