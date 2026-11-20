// Story illustrations, composed from the game's own sprites and pond art.
// Each scene is drawn in a 400 x 260 design box; [t] (0..1, looping) adds
// gentle motion: bobbing frogs, twinkling sparkles, falling rain.

import 'dart:math' as math;
import 'dart:ui';

import '../../core/models.dart';
import 'pond.dart';
import 'sprites.dart';

Paint _f(Color c) => Paint()..color = c;
Paint _s(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round;

class SceneArt {
  SceneArt._();
  static const double w = 400, h = 260;

  static final _skyAlive = Paint()
    ..shader = Gradient.linear(Offset.zero, const Offset(0, 150),
        const [Color(0xFFFFF4DC), Color(0xFFD9EFE2)]);
  static final _skyDull = Paint()
    ..shader = Gradient.linear(Offset.zero, const Offset(0, 150),
        const [Color(0xFFC9CFCB), Color(0xFFAAB5B0)]);
  static final _skyStorm = Paint()
    ..shader = Gradient.linear(Offset.zero, const Offset(0, 150),
        const [Color(0xFF7D8A86), Color(0xFFA2ADA9)]);
  static final _skyNight = Paint()
    ..shader = Gradient.linear(Offset.zero, const Offset(0, 150),
        const [Color(0xFF1F4A4A), Color(0xFF4E7F78)]);
  static final _skyDusk = Paint()
    ..shader = Gradient.linear(Offset.zero, const Offset(0, 150),
        const [Color(0xFFF2C38A), Color(0xFFE7D7B5)]);
  static final _waterAlive = Paint()
    ..shader = Gradient.linear(const Offset(0, 140), const Offset(0, 260),
        const [Color(0xFF9FD0C2), Color(0xFF4E9C91)]);
  static final _waterDull = Paint()
    ..shader = Gradient.linear(const Offset(0, 140), const Offset(0, 260),
        const [Color(0xFFA9B6B1), Color(0xFF7E908A)]);
  static final _waterNight = Paint()
    ..shader = Gradient.linear(const Offset(0, 140), const Offset(0, 260),
        const [Color(0xFF3F7A73), Color(0xFF214E4A)]);
  static final _hillAlive = _f(const Color(0xFFB5D2C3));
  static final _hillDull = _f(const Color(0xFFB4BCB8));
  static final _hillNight = _f(const Color(0xFF2F5E59));
  static final _ripple = _s(const Color(0x59FFFFFF), 1.6);
  static final _sparkle = _f(const Color(0xFFFFF4C2));
  static final _cloud = _f(const Color(0xFF6B7773));
  static final _rain = _s(const Color(0x99D7E0DC), 1.4);
  static final _trunk = _s(const Color(0xFF5A4A3A), 9);
  static final _frond = _s(const Color(0xFF86AE62), 2.6);
  static final _frondDull = _s(const Color(0xFF9AA59A), 2.6);
  static final _leaf = _f(const Color(0xFF9CC474));
  static final _leafDull = _f(const Color(0xFFAEB7AE));
  static final _moon = _f(const Color(0xFFFFF3C4));
  static final _moonGlow = Paint()
    ..color = const Color(0x66FFF3C4)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
  static final _stone = _f(const Color(0xFFB7BBB2));
  static final _stoneDark = _f(const Color(0xFF8E938A));
  static final _stoneLit = _f(const Color(0xFFE9DCC0));
  static final _glow = Paint()
    ..color = const Color(0x80FFD978)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  static final _lanternLit = _f(const Color(0xFFD9443A));
  static final _lanternDull = _f(const Color(0xFF8A8F8B));
  static final _lanternCap = _f(const Color(0xFF8A5A0A));
  static final _lanternRib = _s(const Color(0x66FFE0A0), 1);
  static final _pole = _s(const Color(0xFF5A4A3A), 2.2);
  static final _roof = _f(const Color(0xFF46524D));
  static final _wall = _f(const Color(0xFFB0665A));
  static final _wallDull = _f(const Color(0xFF9C9A95));
  static final _door = _f(const Color(0xFF3A2A24));
  static final _window = _f(const Color(0xFFF6D77A));
  static final _reed = _s(const Color(0xFF5E8848), 2.2);
  static final _reedDull = _s(const Color(0xFF8D978C), 2.2);
  static final _cattail = _f(const Color(0xFF8A5A2A));
  static final _mist = _f(const Color(0x33FFFFFF));
  static final _path = _f(const Color(0xCCF6EDD9));

  static void draw(Canvas c, Size size, String scene, double t) {
    c.save();
    final k = math.min(size.width / w, size.height / h);
    c.translate((size.width - w * k) / 2, (size.height - h * k) / 2);
    c.scale(k, k);
    c.clipRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, w, h), const Radius.circular(18)));
    switch (scene) {
      case 'luck':
        _backdrop(c, _skyAlive, _hillAlive, _waterAlive);
        _sun(c);
        _padLotus(c, 70, 205, 1.0, true);
        _padLotus(c, 330, 200, 0.9, true, deep: true);
        _pad(c, 200, 215, 1.25, true);
        _frog(c, 200, 214 + _bob(t), Facing.s, 78, golden: true);
        _pad(c, 120, 180, 0.8, true);
        _frog(c, 120, 179, Facing.e, 44);
        _pad(c, 280, 178, 0.8, true);
        _frog(c, 280, 177, Facing.w, 44);
        _sparkles(c, t);
      case 'storm':
        _backdrop(c, _skyStorm, _hillDull, _waterDull);
        _clouds(c);
        _rainFall(c, t);
        _pad(c, 80, 210, 0.9, false);
        _pad(c, 300, 222, 1.0, false);
        _pad(c, 190, 178, 0.7, false);
        _frog(c, 80, 209, Facing.w, 42);
        _frog(c, 300, 221, Facing.e, 46);
      case 'willow':
        _backdrop(c, _skyDull, _hillDull, _waterDull);
        _willow(c, 40, false, false);
        _willow(c, 372, true, false);
        _pad(c, 250, 212, 1.2, false);
        _frog(c, 250, 211 + _bob(t), Facing.w, 70, golden: true);
      case 'forward':
        _backdrop(c, _skyDull, _hillDull, _waterDull);
        for (var i = 0; i < 4; i++) {
          _pad(c, 90.0 + i * 80, 214 - i * 10, 0.95 - i * 0.12, false);
        }
        for (var i = 0; i < 9; i++) {
          c.drawCircle(Offset(120.0 + i * 24, 200 - i * 3.5), 2.4, _path);
        }
        _frog(c, 90, 213 + _bob(t), Facing.e, 62);
        c.save();
        c.translate(122, 222);
        c.scale(0.7, 0.7);
        PondArt.badge(c, Facing.e, golden: false);
        c.restore();
        _frog(c, 330, 183, Facing.s, 40, golden: true);
      case 'doudou':
        _backdrop(c, _skyDull, _hillDull, _waterDull);
        _pad(c, 120, 212, 1.0, false);
        _frog(c, 120, 211 + _bob(t) * 1.6, Facing.s, 46);
        _pad(c, 275, 210, 1.2, false);
        _frog(c, 275, 209, Facing.w, 72, golden: true);
        c.save();
        c.translate(200, 236);
        c.scale(0.9, 0.9);
        PondArt.pad(c, alive: false);
        PondArt.rotatorRing(c, alive: true);
        c.restore();
      case 'moon_bridge':
        _backdrop(c, _skyNight, _hillNight, _waterNight);
        _moonAt(c, 300, 52);
        _bridge(c, true);
        _padLotus(c, 70, 222, 1.0, true, deep: true);
        _padLotus(c, 340, 226, 0.9, true);
        _pad(c, 200, 228, 1.15, true);
        _frog(c, 200, 227 + _bob(t), Facing.s, 70, golden: true);
        _sparkles(c, t);
      case 'marsh':
        _backdrop(c, _skyDull, _hillDull, _waterDull);
        _reeds(c, 24, 200, false);
        _reeds(c, 360, 205, false);
        for (final x in const [90.0, 170.0, 250.0, 330.0]) {
          _lantern(c, x, 92 + (x % 3) * 6, false);
        }
        c.drawRect(const Rect.fromLTWH(0, 150, 400, 30), _mist);
        _pad(c, 150, 220, 1.1, false);
        _snake(c, 150, 219, 68);
        _pad(c, 285, 214, 1.0, false);
        _frog(c, 285, 213, Facing.w, 58, golden: true);
      case 'together':
        _backdrop(c, _skyDull, _hillDull, _waterDull);
        _reeds(c, 18, 205, false);
        for (final (x, lit) in const [
          (80.0, true),
          (160.0, true),
          (240.0, false),
          (320.0, false)
        ]) {
          _lantern(c, x, 96, lit);
        }
        _pad(c, 150, 216, 1.0, false);
        _frog(c, 150, 215 + _bob(t) * 1.4, Facing.e, 46);
        _pad(c, 250, 214, 1.2, false);
        _frog(c, 250, 213 + _bob(t + 0.3), Facing.e, 70, golden: true);
      case 'lantern_shrine':
        _backdrop(c, _skyDusk, _hillAlive, _waterAlive);
        _shrine(c, 200, 128, true);
        for (final x in const [60.0, 110.0, 290.0, 340.0]) {
          _lantern(c, x, 86 + (x % 4) * 4, true);
        }
        _padLotus(c, 70, 224, 0.95, true, deep: true);
        _padLotus(c, 330, 222, 0.95, true);
        _pad(c, 200, 230, 1.15, true);
        _frog(c, 200, 229 + _bob(t), Facing.s, 70, golden: true);
        _sparkles(c, t);
      default:
        _backdrop(c, _skyAlive, _hillAlive, _waterAlive);
        _pad(c, 200, 215, 1.2, true);
        _frog(c, 200, 214, Facing.s, 70, golden: true);
    }
    c.restore();
  }

  static double _bob(double t) => -math.sin(t * 2 * math.pi).abs() * 3;

  static final Path _hills = Path()
    ..moveTo(0, 140)
    ..quadraticBezierTo(70, 100, 150, 130)
    ..quadraticBezierTo(220, 92, 300, 125)
    ..quadraticBezierTo(360, 105, 400, 128)
    ..lineTo(400, 150)
    ..lineTo(0, 150)
    ..close();
  static final Paint _sunCore = _f(const Color(0xFFFFE7A6));
  static final Path _trunkPath = Path()
    ..moveTo(-30, 0)
    ..cubicTo(-10, 60, 6, 110, -14, 175);
  static final List<Path> _fronds = [
    for (var i = 0; i < 12; i++)
      Path()
        ..moveTo(-20.0 + i * 7, 10.0 + i * 3)
        ..quadraticBezierTo(
            -6.0 + i * 8, (120.0 + i * 9) * 0.5, -16.0 + i * 6, 120.0 + i * 9),
  ];
  static final Path _archPath = Path()
    ..moveTo(60, 160)
    ..quadraticBezierTo(200, 70, 340, 160)
    ..lineTo(320, 160)
    ..quadraticBezierTo(200, 98, 80, 160)
    ..close();
  static final Paint _postLit = _s(const Color(0xFFB0665A), 3);
  static final Paint _postDull = _s(const Color(0xFF8E938A), 3);
  static final Path _roofPath = Path()
    ..moveTo(-72, -22)
    ..quadraticBezierTo(0, -52, 72, -22)
    ..lineTo(52, -46)
    ..quadraticBezierTo(0, -66, -52, -46)
    ..close();
  static final List<Path> _reedPaths = [
    for (var i = 0; i < 5; i++)
      Path()
        ..moveTo(i * 5.0, 0)
        ..quadraticBezierTo(i * 5.0 + 6, -50, i * 4.0 - 4, -95),
  ];

  static void _backdrop(Canvas c, Paint sky, Paint hill, Paint water) {
    c.drawRect(const Rect.fromLTWH(0, 0, w, h), sky);
    c.drawPath(_hills, hill);
    c.drawRect(const Rect.fromLTWH(0, 145, w, 115), water);
    for (final r in const [
      Rect.fromLTWH(30, 168, 70, 10),
      Rect.fromLTWH(250, 186, 90, 12),
      Rect.fromLTWH(140, 244, 80, 10)
    ]) {
      c.drawOval(r, _ripple);
    }
  }

  static void _sun(Canvas c) {
    c.drawCircle(const Offset(320, 58), 34, _moonGlow);
    c.drawCircle(const Offset(320, 58), 20, _sunCore);
  }

  static void _moonAt(Canvas c, double x, double y) {
    c.drawCircle(Offset(x, y), 38, _moonGlow);
    c.drawCircle(Offset(x, y), 22, _moon);
  }

  static void _pad(Canvas c, double x, double y, double s, bool alive) {
    c.save();
    c.translate(x, y);
    c.scale(s, s);
    PondArt.pad(c, alive: alive);
    c.restore();
  }

  static void _padLotus(Canvas c, double x, double y, double s, bool alive,
      {bool deep = false}) {
    _pad(c, x, y, s, alive);
    c.save();
    c.translate(x, y);
    c.scale(s * 0.42, s * 0.42);
    PondArt.lotus(c, deep: deep);
    c.restore();
  }

  static void _frog(Canvas c, double x, double y, Facing f, double width,
      {bool golden = false}) {
    c.save();
    c.translate(x, y);
    Sprites.frog(c, f, width, golden: golden);
    c.restore();
  }

  static void _snake(Canvas c, double x, double y, double width) {
    c.save();
    c.translate(x, y);
    Sprites.snake(c, width);
    c.restore();
  }

  static void _sparkles(Canvas c, double t) {
    const pts = [
      Offset(40, 60),
      Offset(120, 40),
      Offset(260, 90),
      Offset(360, 120),
      Offset(180, 110),
      Offset(80, 130)
    ];
    for (var i = 0; i < pts.length; i++) {
      final a = (math.sin((t + i / pts.length) * 2 * math.pi) + 1) / 2;
      c.drawCircle(pts[i], 1.5 + a * 2.2, _sparkle);
    }
  }

  static void _clouds(Canvas c) {
    for (final o in const [
      Offset(80, 50),
      Offset(150, 38),
      Offset(250, 55),
      Offset(330, 40)
    ]) {
      c.drawOval(Rect.fromCenter(center: o, width: 120, height: 46), _cloud);
    }
  }

  static void _rainFall(Canvas c, double t) {
    for (var i = 0; i < 40; i++) {
      final x = (i * 37) % 400.0;
      final y = ((i * 53) % 220 + t * 220) % 220 + 20;
      c.drawLine(Offset(x, y), Offset(x - 4, y + 12), _rain);
    }
  }

  static void _willow(Canvas c, double x, bool flip, bool alive) {
    c.save();
    c.translate(x, 0);
    if (flip) c.scale(-1, 1);
    c.drawPath(_trunkPath, _trunk);
    for (var i = 0; i < 12; i++) {
      final len = 120.0 + i * 9;
      c.drawPath(_fronds[i], alive ? _frond : _frondDull);
      for (var j = 1; j < 6; j++) {
        final tt = j / 6;
        c.drawOval(
            Rect.fromCenter(
                center: Offset(
                    (-20.0 + i * 7) * (1 - tt) +
                        (-16.0 + i * 6) * tt +
                        3 * math.sin(j + i),
                    10.0 + i * 3 + (len - 10 - i * 3) * tt),
                width: 5,
                height: 10),
            alive ? _leaf : _leafDull);
      }
    }
    c.restore();
  }

  static void _bridge(Canvas c, bool lit) {
    if (lit) c.drawPath(_archPath, _glow);
    c.drawPath(_archPath, lit ? _stoneLit : _stone);
    // Railing posts standing on the deck (deck y = 160 - 180 t (1 - t)).
    for (var i = 0; i < 9; i++) {
      final tt = 0.1 + i * 0.1;
      final x = 60 + 280 * tt;
      final y = 160 - 180 * tt * (1 - tt);
      c.drawLine(Offset(x, y), Offset(x, y - 12), lit ? _postLit : _postDull);
    }
    c.drawOval(
        const Rect.fromLTWH(150, 150, 100, 26), lit ? _glow : _stoneDark);
  }

  static void _lantern(Canvas c, double x, double y, bool lit) {
    c.drawLine(Offset(x, y - 40), Offset(x, y - 12), _pole);
    if (lit) c.drawCircle(Offset(x, y), 22, _glow);
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 22, height: 28),
        lit ? _lanternLit : _lanternDull);
    c.drawLine(Offset(x - 6, y - 12), Offset(x - 6, y + 12), _lanternRib);
    c.drawLine(Offset(x + 6, y - 12), Offset(x + 6, y + 12), _lanternRib);
    c.drawRect(Rect.fromCenter(center: Offset(x, y - 14), width: 12, height: 4),
        _lanternCap);
    c.drawRect(Rect.fromCenter(center: Offset(x, y + 14), width: 12, height: 4),
        _lanternCap);
  }

  static void _shrine(Canvas c, double x, double y, bool lit) {
    if (lit) c.drawCircle(Offset(x, y), 70, _glow);
    c.drawRect(Rect.fromCenter(center: Offset(x, y), width: 90, height: 46),
        lit ? _wall : _wallDull);
    c.save();
    c.translate(x, y);
    c.drawPath(_roofPath, _roof);
    c.restore();
    c.drawRect(Rect.fromCenter(center: Offset(x, y + 6), width: 22, height: 34),
        _door);
    if (lit) {
      c.drawRect(
          Rect.fromCenter(center: Offset(x - 30, y - 4), width: 14, height: 12),
          _window);
      c.drawRect(
          Rect.fromCenter(center: Offset(x + 30, y - 4), width: 14, height: 12),
          _window);
    }
  }

  static void _reeds(Canvas c, double x, double y, bool alive) {
    c.save();
    c.translate(x, y);
    for (final p in _reedPaths) {
      c.drawPath(p, alive ? _reed : _reedDull);
    }
    c.restore();
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 2, y - 102, 6, 22), const Radius.circular(3)),
        _cattail);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 14, y - 96, 6, 22), const Radius.circular(3)),
        _cattail);
  }
}
