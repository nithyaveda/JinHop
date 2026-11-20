// Full-height illustrated world-ending scenes: the world's landmark, first
// dull and misty, then coming alive (colour, lit lanterns, moonlight, blooms)
// as [alive] goes 0 -> 1. Drawn in a 400 x 560 design box. Paths and paints
// are built once; only colours change per frame.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/models.dart';
import 'pond.dart';
import 'sprites.dart';

class LandmarkScene {
  static const double w = 400, h = 560;

  /// [landmark]: 'moon_bridge' or 'lantern_shrine'. [alive] 0..1, [t] loops 0..1.
  static void draw(Canvas c, Size size, String landmark, double alive, double t) {
    final s = math.max(size.width / w, size.height / h);
    c.save();
    c.translate((size.width - w * s) / 2, (size.height - h * s) / 2);
    c.scale(s, s);
    c.clipRect(const Rect.fromLTWH(0, 0, w, h));
    if (landmark == 'lantern_shrine') {
      _shrineScene(c, alive, t);
    } else {
      _bridgeScene(c, alive, t);
    }
    c.restore();
  }

  // ------------------------------------------------------------ shared bits

  static final Paint _p = Paint();
  static final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  static final Paint _blur = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
  static final Paint _soft = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

  static Color _lerp(int dull, int live, double a) => Color.lerp(Color(dull), Color(live), a)!;

  static void _fill(Canvas c, Path p, Color col) {
    _p
      ..color = col
      ..shader = null;
    c.drawPath(p, _p);
  }

  static void _sky(Canvas c, double a, List<int> dull, List<int> live) {
    _p.shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, 330), [
      _lerp(dull[0], live[0], a),
      _lerp(dull[1], live[1], a),
    ]);
    c.drawRect(const Rect.fromLTWH(0, 0, w, 340), _p);
    _p.shader = ui.Gradient.linear(const Offset(0, 330), const Offset(0, h), [
      _lerp(dull[2], live[2], a),
      _lerp(dull[3], live[3], a),
    ]);
    c.drawRect(const Rect.fromLTWH(0, 330, w, h - 330), _p);
    _p.shader = null;
  }

  static final Path _hillsFar = Path()
    ..moveTo(0, 300)
    ..quadraticBezierTo(60, 240, 130, 280)
    ..quadraticBezierTo(200, 220, 280, 270)
    ..quadraticBezierTo(350, 235, 400, 268)
    ..lineTo(400, 336)
    ..lineTo(0, 336)
    ..close();
  static final Path _hillsNear = Path()
    ..moveTo(0, 318)
    ..quadraticBezierTo(90, 286, 170, 312)
    ..quadraticBezierTo(260, 292, 330, 316)
    ..quadraticBezierTo(370, 304, 400, 312)
    ..lineTo(400, 336)
    ..lineTo(0, 336)
    ..close();

  static void _hills(Canvas c, double a) {
    _fill(c, _hillsFar, _lerp(0xFFAEB5B1, 0xFF3F7F74, a));
    _fill(c, _hillsNear, _lerp(0xFF9DA6A1, 0xFF2E6B5E, a));
  }

  static void _moon(Canvas c, Offset o, double a) {
    _blur.color = Color.fromARGB((40 + 160 * a).round(), 255, 236, 170);
    c.drawCircle(o, 70, _blur);
    _p.color = _lerp(0xFFD9DCD8, 0xFFFFF3C4, a);
    c.drawCircle(o, 36, _p);
  }

  static final List<Offset> _starPts = () {
    final rng = math.Random(5);
    return [for (var i = 0; i < 26; i++) Offset(rng.nextDouble() * w, rng.nextDouble() * 230)];
  }();
  static final List<List<double>> _flies = () {
    final rng = math.Random(9);
    return [
      for (var i = 0; i < 18; i++) [rng.nextDouble() * w, 300 + rng.nextDouble() * 220, rng.nextDouble()]
    ];
  }();
  static final List<List<double>> _skyLanterns = () {
    final rng = math.Random(4);
    return [
      for (var i = 0; i < 10; i++)
        [20 + rng.nextDouble() * 360, 60 + rng.nextDouble() * 200, rng.nextDouble(), 0.55 + rng.nextDouble() * 0.3]
    ];
  }();

  static void _stars(Canvas c, double a, double t) {
    if (a <= 0.05) return;
    for (var i = 0; i < _starPts.length; i++) {
      final p = _starPts[i];
      final tw = (math.sin((t + i / 26) * 2 * math.pi) + 1) / 2;
      _p.color = Color.fromARGB((a * (120 + 120 * tw)).round(), 255, 248, 220);
      c.drawCircle(p, 1 + tw * 1.2, _p);
    }
  }

  static void _ripples(Canvas c, double a) {
    _stroke
      ..strokeWidth = 1.6
      ..color = Color.fromARGB((60 + 60 * a).round(), 255, 255, 255);
    for (final r in const [
      Rect.fromLTWH(30, 470, 90, 10),
      Rect.fromLTWH(270, 500, 100, 12),
      Rect.fromLTWH(150, 538, 80, 9),
    ]) {
      c.drawOval(r, _stroke);
    }
  }

  static void _mist(Canvas c, double a, double t) {
    final m = 1 - a;
    if (m <= 0.02) return;
    _soft.color = Color.fromARGB((150 * m).round(), 225, 229, 226);
    for (var i = 0; i < 4; i++) {
      final y = 250.0 + i * 70;
      final x = -60 + ((t * 40 + i * 90) % 140);
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 420, 34), const Radius.circular(17)), _soft);
    }
  }

  static void _fireflies(Canvas c, double a, double t) {
    if (a <= 0.3) return;
    final k = (a - 0.3) / 0.7;
    for (final f in _flies) {
      final bx = f[0], by = f[1], ph = f[2];
      final p = Offset(bx + 8 * math.sin((t + ph) * 2 * math.pi), by + 6 * math.cos((t + ph) * 2 * math.pi));
      final glow = (math.sin((t * 2 + ph) * 2 * math.pi) + 1) / 2;
      _soft.color = Color.fromARGB((k * (90 + 120 * glow)).round(), 255, 230, 120);
      c.drawCircle(p, 5, _soft);
      _p.color = Color.fromARGB((k * 255).round(), 255, 248, 200);
      c.drawCircle(p, 1.6, _p);
    }
  }

  /// A foreground pad: grey and closed when dull, green with a lotus when alive.
  static void _padBloom(Canvas c, double x, double y, double sc, double a, {bool deep = false}) {
    c.save();
    c.translate(x, y);
    c.scale(sc, sc);
    PondArt.pad(c, alive: a > 0.5);
    c.restore();
    if (a > 0.45) {
      final k = Curves.easeOutBack.transform(((a - 0.45) / 0.55).clamp(0.0, 1.0));
      c.save();
      c.translate(x, y - 2);
      c.scale(sc * 0.46 * k, sc * 0.46 * k);
      PondArt.lotus(c, deep: deep);
      c.restore();
    } else {
      c.save();
      c.translate(x, y);
      c.scale(sc * 0.45, sc * 0.45);
      PondArt.bud(c);
      c.restore();
    }
  }

  static void _lantern(Canvas c, Offset o, double lit, {double size = 1}) {
    if (lit > 0) {
      _blur.color = Color.fromARGB((170 * lit).round(), 255, 180, 80);
      c.drawCircle(o, 26 * size, _blur);
    }
    _p.color = _lerp(0xFF7F8580, 0xFFE0453A, lit);
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 20 * size, height: 25 * size),
            Radius.circular(8 * size)),
        _p);
    _p.color = _lerp(0xFF5F6460, 0xFFD9A422, lit);
    c.drawRect(Rect.fromCenter(center: o + Offset(0, -13 * size), width: 11 * size, height: 3.5 * size), _p);
    c.drawRect(Rect.fromCenter(center: o + Offset(0, 13 * size), width: 11 * size, height: 3.5 * size), _p);
    if (lit > 0.2) {
      _p.color = Color.fromARGB((255 * lit).round(), 255, 233, 160);
      c.drawCircle(o, 4 * size, _p);
    }
  }

  static void _jin(Canvas c, Offset o, double width, double a, double t) {
    final hop = a >= 1 ? math.sin(t * 2 * math.pi).abs() * 6 : 0.0;
    if (a > 0.5) {
      _blur.color = Color.fromARGB((120 * a).round(), 255, 220, 120);
      c.drawCircle(o + Offset(0, -width * 0.35), width * 0.55, _blur);
    }
    c.save();
    c.translate(o.dx, o.dy - hop);
    Sprites.frog(c, Facing.s, width, golden: true, shadow: false);
    c.restore();
  }

  // ------------------------------------------------------------ Moon Bridge

  static final Path _bridgeBody = Path()
    ..moveTo(40, 352)
    ..quadraticBezierTo(200, 150, 360, 352)
    ..lineTo(306, 352)
    ..quadraticBezierTo(200, 216, 94, 352)
    ..close();
  static final Path _bridgeBand = Path()
    ..moveTo(82, 352)
    ..quadraticBezierTo(200, 196, 318, 352)
    ..lineTo(306, 352)
    ..quadraticBezierTo(200, 216, 94, 352)
    ..close();
  static final Path _bridgeReflect = Path()
    ..moveTo(40, 352)
    ..quadraticBezierTo(200, 554, 360, 352)
    ..lineTo(306, 352)
    ..quadraticBezierTo(200, 488, 94, 352)
    ..close();
  static final Path _rail = () {
    final p = Path();
    for (var i = 0; i <= 24; i++) {
      final tt = i / 24;
      final x = 40 + 320 * tt;
      final y = 352 - 404 * tt * (1 - tt) - 20;
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p;
  }();
  static final Path _willow = () {
    final p = Path()
      ..moveTo(-10, 330)
      ..cubicTo(10, 260, 0, 160, 30, 60);
    for (var i = 0; i < 9; i++) {
      p
        ..moveTo(10.0 + i * 6, 70.0 + i * 8)
        ..quadraticBezierTo(30.0 + i * 7, 160.0 + i * 6, 14.0 + i * 6, 240.0 + i * 9);
    }
    return p;
  }();

  static double _deckY(double tt) => 352 - 404 * tt * (1 - tt);

  static void _bridgeScene(Canvas c, double a, double t) {
    _sky(c, a, const [0xFFC9CECB, 0xFFB9C0BC, 0xFFA9B3AF, 0xFF97A29E],
        const [0xFF1D3B5C, 0xFF6A6FA0, 0xFF2E6D78, 0xFF1F4F58]);
    _stars(c, a, t);
    _moon(c, const Offset(300, 110), a);
    _hills(c, a);
    // Moon path on the water.
    if (a > 0) {
      _soft.color = Color.fromARGB((110 * a).round(), 255, 236, 170);
      c.drawRect(const Rect.fromLTWH(285, 340, 30, 220), _soft);
    }
    // Willow on the left.
    _stroke
      ..strokeWidth = 3
      ..color = _lerp(0xFF8D958F, 0xFF3E8A5E, a);
    c.drawPath(_willow, _stroke);
    // Bridge, reflection completes the "moon" circle.
    _fill(c, _bridgeReflect, _lerp(0x22000000, 0x44F3E3BE, a));
    _fill(c, _bridgeBody, _lerp(0xFFB4B8B2, 0xFFF1E5C9, a));
    _fill(c, _bridgeBand, _lerp(0xFF9EA39C, 0xFFD2BC90, a));
    _stroke
      ..strokeWidth = 2.5
      ..color = _lerp(0xFF6E736D, 0xFF8A5A3A, a);
    c.drawPath(_bridgeBody, _stroke);
    // Jin Chan at the top of the bridge, standing behind the railing.
    _jin(c, const Offset(200, 254), 84, a, t);
    // Red railing.
    final railCol = _lerp(0xFF80857F, 0xFFC0392B, a);
    _stroke
      ..strokeWidth = 4
      ..color = railCol;
    for (var i = 1; i < 12; i++) {
      final tt = i / 12;
      final x = 40 + 320 * tt;
      c.drawLine(Offset(x, _deckY(tt)), Offset(x, _deckY(tt) - 20), _stroke);
    }
    _stroke.strokeWidth = 5;
    c.drawPath(_rail, _stroke);
    // Lanterns light up one by one from the ends to the middle.
    const posts = [0.08, 0.92, 0.27, 0.73];
    for (var i = 0; i < posts.length; i++) {
      final tt = posts[i];
      final x = 40 + 320 * tt;
      final y = _deckY(tt) - 44;
      _stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF4A3A2E);
      c.drawLine(Offset(x, _deckY(tt) - 20), Offset(x, y - 12), _stroke);
      _lantern(c, Offset(x, y), ((a - 0.25 - i * 0.12) / 0.2).clamp(0.0, 1.0));
    }
    _mist(c, a, t);
    // Foreground pond.
    _ripples(c, a);
    _padBloom(c, 70, 470, 1.25, ((a - 0.1) / 0.9).clamp(0.0, 1.0));
    _padBloom(c, 330, 452, 1.0, ((a - 0.25) / 0.75).clamp(0.0, 1.0), deep: true);
    _padBloom(c, 210, 528, 0.9, ((a - 0.4) / 0.6).clamp(0.0, 1.0));
    _fireflies(c, a, t);
  }

  // ------------------------------------------------------------ Lantern Shrine

  static final Path _island = Path()
    ..moveTo(60, 380)
    ..quadraticBezierTo(200, 340, 340, 380)
    ..quadraticBezierTo(200, 410, 60, 380)
    ..close();

  static Path _tier(double y, double half, double hgt) => Path()
    ..moveTo(200 - half - 20, y - 8)
    ..quadraticBezierTo(200 - half + 6, y + 4, 200 - half + 22, y)
    ..lineTo(200 + half - 22, y)
    ..quadraticBezierTo(200 + half - 6, y + 4, 200 + half + 20, y - 8)
    ..quadraticBezierTo(200 + half - 22, y - hgt * 0.4, 200 + half * 0.55, y - hgt)
    ..lineTo(200 - half * 0.55, y - hgt)
    ..quadraticBezierTo(200 - half + 22, y - hgt * 0.4, 200 - half - 20, y - 8)
    ..close();
  static final Path _roof1 = _tier(290, 112, 32);
  static final Path _roof2 = _tier(240, 76, 34);
  static final Path _string = Path()
    ..moveTo(0, 200)
    ..quadraticBezierTo(100, 250, 175, 228)
    ..moveTo(225, 228)
    ..quadraticBezierTo(300, 250, 400, 200);

  static void _shrineScene(Canvas c, double a, double t) {
    _sky(c, a, const [0xFFC4C9C6, 0xFFB5BCB8, 0xFFA3AEAA, 0xFF919D99],
        const [0xFF2A1F4A, 0xFFB45A4A, 0xFF5A3A4A, 0xFF2A2A3A]);
    _stars(c, a, t);
    _moon(c, const Offset(80, 90), a * 0.7);
    _hills(c, a * 0.6);
    // Floating sky lanterns rising (alive only).
    if (a > 0.6) {
      final k = (a - 0.6) / 0.4;
      for (final l in _skyLanterns) {
        final y = l[1] - ((t + l[2]) % 1) * 40;
        _lantern(c, Offset(l[0], y), k, size: l[3]);
      }
    }
    // Island and shrine.
    _fill(c, _island, _lerp(0xFF8E968F, 0xFF3E6B4E, a));
    final stone = _lerp(0xFFAFB2AB, 0xFFE6DCC6, a);
    _p.color = stone;
    c.drawRect(const Rect.fromLTWH(78, 352, 244, 16), _p);
    c.drawRect(const Rect.fromLTWH(96, 340, 208, 14), _p);
    _p.color = _lerp(0xFF7A7C78, 0xFF8E2A20, a);
    c.drawRect(const Rect.fromLTWH(112, 282, 176, 60), _p);
    _p.color = _lerp(0xFF8E908B, 0xFFC0392B, a);
    for (final px in const [116.0, 158.0, 232.0, 274.0]) {
      c.drawRect(Rect.fromLTWH(px, 282, 10, 60), _p);
    }
    _p.color = _lerp(0xFF4A4A46, 0xFFFFD877, a);
    c.drawRRect(
        RRect.fromRectAndCorners(const Rect.fromLTWH(182, 302, 36, 40),
            topLeft: const Radius.circular(18), topRight: const Radius.circular(18)),
        _p);
    if (a > 0.3) {
      _blur.color = Color.fromARGB((140 * a).round(), 255, 210, 120);
      c.drawCircle(const Offset(200, 320), 30, _blur);
    }
    _p.color = _lerp(0xFF7A7C78, 0xFF8E2A20, a);
    c.drawRect(const Rect.fromLTWH(142, 238, 116, 20), _p);
    final roof = _lerp(0xFF5B625E, 0xFF2F5D50, a);
    final edge = _lerp(0xFF7A7F7A, 0xFFE7B53C, a);
    for (final r in [_roof1, _roof2]) {
      _fill(c, r, roof);
      _stroke
        ..strokeWidth = 3
        ..color = edge;
      c.drawPath(r, _stroke);
    }
    _p.color = edge;
    c.drawCircle(const Offset(200, 200), 6, _p);
    // Lantern strings, lanterns light up in turn.
    _stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF4A3A2E);
    c.drawPath(_string, _stroke);
    const spots = [Offset(40, 225), Offset(360, 225), Offset(95, 240), Offset(305, 240), Offset(148, 236), Offset(252, 236)];
    for (var i = 0; i < spots.length; i++) {
      _lantern(c, spots[i] + const Offset(0, 14), ((a - 0.2 - i * 0.08) / 0.2).clamp(0.0, 1.0));
    }
    // Reflection.
    _soft.color = _lerp(0x10000000, 0x30E0453A, a);
    c.drawRect(const Rect.fromLTWH(120, 394, 160, 26), _soft);
    // Jin Chan on the steps.
    _jin(c, const Offset(200, 372), 70, a, t);
    _mist(c, a, t);
    _ripples(c, a);
    _padBloom(c, 66, 486, 1.15, ((a - 0.1) / 0.9).clamp(0.0, 1.0));
    _padBloom(c, 336, 470, 1.0, ((a - 0.3) / 0.7).clamp(0.0, 1.0), deep: true);
    _fireflies(c, a, t);
  }
}
