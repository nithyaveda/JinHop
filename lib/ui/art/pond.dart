// 2.5D pond pieces: lily pads (alive / dull), rotator ring, lotus blooms,
// buds, direction badges. Everything is built once in a design unit where one
// board cell is 100 wide, centred on the pad; callers translate + scale.

import 'dart:math' as math;
import 'dart:ui';

import '../../core/models.dart';

Paint _fill(Color c) => Paint()..color = c;
Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class PondArt {
  PondArt._();

  // ---- pad geometry (unit: cell = 100)
  static const double padRx = 44, padRy = 23, padDepth = 6;

  static final Path _padTop = () {
    const a1 = -112 * math.pi / 180, a2 = -88 * math.pi / 180;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(math.cos(a1) * padRx, math.sin(a1) * padRy)
      ..arcToPoint(Offset(math.cos(a2) * padRx, math.sin(a2) * padRy),
          radius: const Radius.elliptical(padRx, padRy),
          largeArc: true,
          clockwise: false)
      ..close();
  }();
  static final Path _padSide = _padTop.shift(const Offset(0, padDepth));
  static final Path _padShadow = Path()
    ..addOval(Rect.fromCenter(
        center: const Offset(3, 9), width: padRx * 2.2, height: padRy * 2.3));
  static final Path _veins = () {
    final p = Path();
    for (var a = -60; a < 250; a += 26) {
      final r = a * math.pi / 180;
      p
        ..moveTo(0, 0)
        ..lineTo(math.cos(r) * padRx * 0.86, math.sin(r) * padRy * 0.86);
    }
    return p;
  }();
  static final Path _padHighlight = Path()
    ..addArc(
        Rect.fromCenter(
            center: Offset.zero, width: padRx * 1.5, height: padRy * 1.4),
        math.pi * 1.02,
        math.pi * 0.42);

  static final _shadowPaint = Paint()
    ..color = const Color(0x4D0E3B36)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  static final _aliveTop = Paint()
    ..shader = Gradient.radial(
        const Offset(-10, -8),
        52,
        const [Color(0xFF9BDB86), Color(0xFF4FAE5E), Color(0xFF2D7E45)],
        const [0, 0.55, 1]);
  static final _aliveSide = _fill(const Color(0xFF245F36));
  static final _aliveEdge = _stroke(const Color(0xFF245F36), 1.2);
  static final _dullTop = Paint()
    ..shader = Gradient.radial(
        const Offset(-10, -8),
        52,
        const [Color(0xFFC9D1CB), Color(0xFFA5B0A9), Color(0xFF86928B)],
        const [0, 0.55, 1]);
  static final _dullSide = _fill(const Color(0xFF6D7771));
  static final _dullEdge = _stroke(const Color(0xFF6D7771), 1.2);
  static final _veinAlive = _stroke(const Color(0x38FFFFFF), 1);
  static final _veinDull = _stroke(const Color(0x26FFFFFF), 1);
  static final _hiAlive = _stroke(const Color(0x59FFFFFF), 2.4);
  static final _hiDull = _stroke(const Color(0x40FFFFFF), 2.4);

  /// Lily pad at the origin. [alive] picks green vs. faded grey-green.
  static void pad(Canvas c, {required bool alive, bool shadow = true}) {
    if (shadow) c.drawPath(_padShadow, _shadowPaint);
    c.drawPath(_padSide, alive ? _aliveSide : _dullSide);
    c.drawPath(_padTop, alive ? _aliveTop : _dullTop);
    c.drawPath(_padTop, alive ? _aliveEdge : _dullEdge);
    c.drawPath(_veins, alive ? _veinAlive : _veinDull);
    c.drawPath(_padHighlight, alive ? _hiAlive : _hiDull);
  }

  // ---- rotator: two gold clockwise arrows around the pad
  static final Path _rotArcs = () {
    const rx = 50.0, ry = 28.0;
    final p = Path();
    final rect = Rect.fromCenter(
        center: const Offset(0, 1), width: rx * 2, height: ry * 2);
    p
      ..addArc(rect, math.pi * 0.95, math.pi * 0.62)
      ..addArc(rect, -math.pi * 0.05, math.pi * 0.62);
    return p;
  }();
  static final Path _rotHeads = () {
    const rx = 50.0, ry = 28.0;
    final p = Path();
    for (final end in [math.pi * 1.57, math.pi * 0.57]) {
      final x = math.cos(end) * rx, y = math.sin(end) * ry + 1;
      // tangent direction (clockwise on screen)
      final tx = -math.sin(end) * rx, ty = math.cos(end) * ry;
      final l = math.sqrt(tx * tx + ty * ty);
      final ux = tx / l, uy = ty / l, nx = -uy, ny = ux;
      p
        ..moveTo(x + ux * 9, y + uy * 9)
        ..lineTo(x + nx * 6, y + ny * 6)
        ..lineTo(x - nx * 6, y - ny * 6)
        ..close();
    }
    return p;
  }();
  static final _rotStroke = _stroke(const Color(0xFFD9A422), 4.5);
  static final _rotHead = _fill(const Color(0xFFD9A422));
  static final _rotStrokeDim = _stroke(const Color(0xFFB99B55), 4.5);
  static final _rotHeadDim = _fill(const Color(0xFFB99B55));

  static void rotatorRing(Canvas c, {required bool alive}) {
    c.drawPath(_rotArcs, alive ? _rotStroke : _rotStrokeDim);
    c.drawPath(_rotHeads, alive ? _rotHead : _rotHeadDim);
  }

  // ---- lotus (unit: overall height ~80 at scale 1)
  static Path _petalPath(double l, double w) => Path()
    ..moveTo(0, 0)
    ..cubicTo(w * 0.95, -l * 0.22, w * 0.8, -l * 0.78, 0, -l)
    ..cubicTo(-w * 0.8, -l * 0.78, -w * 0.95, -l * 0.22, 0, 0)
    ..close();
  static final _petalBig = _petalPath(78, 28);
  static final _petalMid = _petalPath(72, 27);
  static final _petalSmall = _petalPath(62, 25);
  static final _petalVein = Path()
    ..moveTo(0, -9)
    ..quadraticBezierTo(2, -36, 0, -64);
  static Paint _petalPaint(List<Color> c, double l) => Paint()
    ..shader =
        Gradient.linear(Offset.zero, Offset(0, -l), c, const [0, 0.45, 1]);
  static final _pinkFront = _petalPaint(
      const [Color(0xFFFFF6EE), Color(0xFFFFD3DD), Color(0xFFEE6F92)], 72);
  static final _pinkFrontS = _petalPaint(
      const [Color(0xFFFFF6EE), Color(0xFFFFD3DD), Color(0xFFEE6F92)], 62);
  static final _pinkBack = _petalPaint(
      const [Color(0xFFF7DCE2), Color(0xFFF2A9BC), Color(0xFFD9507A)], 78);
  static final _deepFront = _petalPaint(
      const [Color(0xFFFFE9EC), Color(0xFFF48CA6), Color(0xFFC8325E)], 72);
  static final _deepFrontS = _petalPaint(
      const [Color(0xFFFFE9EC), Color(0xFFF48CA6), Color(0xFFC8325E)], 62);
  static final _deepBack = _petalPaint(
      const [Color(0xFFF5C3CF), Color(0xFFE06688), Color(0xFFA9244C)], 78);
  static final _petalEdge = _stroke(const Color(0x59B23A5E), 1.6);
  static final _veinPaint = _stroke(const Color(0x47C04A6E), 1.4);
  static final _podPaint = Paint()
    ..shader = Gradient.radial(const Offset(-3, -30), 16,
        const [Color(0xFFFFF3A8), Color(0xFFD9A422)]);
  static final _podEdge = _stroke(const Color(0xFFB88A1C), 1.5);
  static final _stamen = _stroke(const Color(0xFFE9B730), 2.5);
  static final Path _stamens = () {
    final p = Path();
    for (var a = 0; a < 360; a += 20) {
      final r = a * math.pi / 180;
      p
        ..moveTo(0, -30)
        ..lineTo(math.cos(r) * 22, math.sin(r) * 9 - 34);
    }
    return p;
  }();
  static final Path _pod = Path()
    ..addOval(
        Rect.fromCenter(center: const Offset(0, -29), width: 30, height: 16));
  static final _seed = _fill(const Color(0xFFB88A1C));
  static final Path _seeds = () {
    final p = Path();
    for (final o in const [
      Offset(-6, -30),
      Offset(0, -32),
      Offset(6, -30),
      Offset(-3, -27),
      Offset(3, -27)
    ]) {
      p.addOval(Rect.fromCircle(center: o, radius: 1.6));
    }
    return p;
  }();

  static void _petal(Canvas c, Path p, Paint fill, double angleDeg, double dy) {
    c.save();
    c.translate(0, dy);
    c.rotate(angleDeg * math.pi / 180);
    c.drawPath(p, fill);
    c.drawPath(p, _petalEdge);
    c.drawPath(_petalVein, _veinPaint);
    c.restore();
  }

  /// Lotus sitting on the origin. [open] 0..1 animates the bloom; [deep]
  /// picks the rich pink used for three-star blooms.
  static void lotus(Canvas c,
      {double open = 1, bool deep = false, double scale = 1}) {
    if (open <= 0) return;
    final o = open.clamp(0.0, 1.0);
    final front = deep ? _deepFront : _pinkFront;
    final frontS = deep ? _deepFrontS : _pinkFrontS;
    final back = deep ? _deepBack : _pinkBack;
    c.save();
    c.scale(scale * (0.4 + 0.6 * o), scale * (0.4 + 0.6 * o));
    // outer petals lying flat on the pad
    c.save();
    c.scale(1, 0.42);
    for (final a in const [-115.0, -80.0, 80.0, 115.0, 180.0, 150.0, -150.0]) {
      _petal(c, _petalBig, back, a * o, 0);
    }
    c.restore();
    for (final a in const [-58.0, -30.0, 0.0, 30.0, 58.0]) {
      _petal(c, _petalBig, back, a * o, 0);
    }
    c.drawPath(_stamens, _stamen);
    c.drawPath(_pod, _podPaint);
    c.drawPath(_pod, _podEdge);
    c.drawPath(_seeds, _seed);
    for (final a in const [-42.0, -14.0, 14.0, 42.0]) {
      _petal(c, _petalMid, front, a * o, 4);
    }
    _petal(c, _petalSmall, frontS, 0, 10);
    c.restore();
  }

  static final Path _bud = Path()
    ..moveTo(0, 0)
    ..cubicTo(-20, -10, -22, -46, 0, -74)
    ..cubicTo(22, -46, 20, -10, 0, 0)
    ..close();
  static final _budFill = Paint()
    ..shader = Gradient.linear(
        Offset.zero,
        const Offset(0, -74),
        const [Color(0xFFFFF1F3), Color(0xFFF6A3B8), Color(0xFFE05A80)],
        const [0, 0.6, 1]);
  static final Path _sepals = Path()
    ..moveTo(0, 0)
    ..cubicTo(-26, -4, -30, -22, -24, -30)
    ..cubicTo(-14, -18, -6, -10, 0, 0)
    ..moveTo(0, 0)
    ..cubicTo(26, -4, 30, -22, 24, -30)
    ..cubicTo(14, -18, 6, -10, 0, 0);
  static final _sepalFill = Paint()
    ..shader = Gradient.linear(Offset.zero, const Offset(0, -30),
        const [Color(0xFF3E8E4E), Color(0xFF8CCB74)]);
  static final Path _budShine = Path()
    ..moveTo(-2, -6)
    ..cubicTo(-10, -24, -9, -50, -1, -66);
  static final _shine = _stroke(const Color(0x80FFFFFF), 2.4);

  static void bud(Canvas c, {double scale = 1}) {
    c.save();
    c.scale(scale, scale);
    c.drawPath(_bud, _budFill);
    c.drawPath(_bud, _petalEdge);
    c.drawPath(_budShine, _shine);
    c.drawPath(_sepals, _sepalFill);
    c.restore();
  }

  // ---- direction badge (unit: cell = 100)
  static final Path _badge = Path()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: 14));
  static final Path _arrow = Path()
    ..moveTo(0, -9.5)
    ..lineTo(8.5, -0.5)
    ..lineTo(3.2, -0.5)
    ..lineTo(3.2, 9)
    ..lineTo(-3.2, 9)
    ..lineTo(-3.2, -0.5)
    ..lineTo(-8.5, -0.5)
    ..close();
  static final _badgeFill = _fill(const Color(0xFFF6EDD9));
  static final _badgeGold = _fill(const Color(0xFFF2CF63));
  static final _badgeEdge = _stroke(const Color(0xFF1C5C49), 2.2);
  static final _badgeEdgeGold = _stroke(const Color(0xFF8A5A0A), 2.2);
  static final _arrowInk = _fill(const Color(0xFF1C5C49));
  static final _arrowRed = _fill(const Color(0xFFB8262B));
  static final _hcBadge = _fill(const Color(0xFFFFFFFF));
  static final _hcEdge = _stroke(const Color(0xFF1E1E24), 3.4);
  static final _hcArrow = _fill(const Color(0xFF1E1E24));

  /// Round arrow badge showing which way a frog will hop.
  static void badge(Canvas c, Facing f,
      {required bool golden, bool highContrast = false}) {
    c.drawPath(
        _badge, highContrast ? _hcBadge : (golden ? _badgeGold : _badgeFill));
    c.drawPath(_badge,
        highContrast ? _hcEdge : (golden ? _badgeEdgeGold : _badgeEdge));
    c.save();
    c.rotate(f.index * math.pi / 2);
    c.drawPath(
        _arrow, highContrast ? _hcArrow : (golden ? _arrowRed : _arrowInk));
    c.restore();
  }
}
