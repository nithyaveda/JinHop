// Dev tool, not part of the test suite. Renders Jin Chan in all views.
//   flutter test tool/render_jinchan_test.dart   ->  build/preview/jinchan.png

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/models.dart';
import 'package:jinhop/ui/art/sprites.dart';

void main() {
  test('render jin chan views', () async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, 2000, 560), Paint()..color = const Color(0xFFFFF8E7));
    final views = [Facing.s, Facing.e, Facing.w, Facing.n];
    for (var i = 0; i < views.length; i++) {
      c.save();
      c.translate(250 + i * 500.0, 500);
      Sprites.frog(c, views[i], 400, golden: true);
      c.restore();
    }
    final img = await rec.endRecording().toImage(2000, 560);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/preview/jinchan.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
