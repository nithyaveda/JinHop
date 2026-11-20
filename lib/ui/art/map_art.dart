// World map art: one tall pond section per world. The section starts grey
// and lifeless and comes alive as its levels are completed; the landmark at
// the top (Moon Bridge, Lantern Shrine, ...) lights up when the world is done.

import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;

import 'package:flutter/widgets.dart';

import 'pond.dart';

enum NodeState { done, current, locked }

class MapNode {
  final int levelId;
  final NodeState state;
  final int stars;
  const MapNode(this.levelId, this.state, this.stars);
}

/// Geometry shared by the painter and the tap targets.
class MapSectionLayout {
  static const double spacing = 150, bottomPad = 170, landmarkArea = 430;
  final double width;
  final int count;
  final int worldId;
  const MapSectionLayout(this.width, this.count, this.worldId);

  double get height => bottomPad + count * spacing + landmarkArea;

  /// Node centre (the pad centre) for the i-th level of the world.
  Offset node(int i) {
    final y = height - bottomPad - i * spacing - spacing / 2;
    final x = width / 2 + math.sin(i * 0.95 + worldId * 1.7) * width * 0.26;
    return Offset(x, y);
  }

  Offset get landmark => Offset(width / 2, landmarkArea * 0.52);
}

Paint _f(Color c) => Paint()..color = c;
Paint _s(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round;

class MapSectionPainter extends CustomPainter {
  final int worldId;
  final String worldName;
  final String landmarkName;
  final List<MapNode> nodes;

  MapSectionPainter(
      {required this.worldId,
      required this.worldName,
      required this.landmarkName,
      required this.nodes});

  double get _progress => nodes.isEmpty
      ? 0
      : nodes.where((n) => n.state == NodeState.done).length / nodes.length;
  bool get _complete =>
      nodes.isNotEmpty && nodes.every((n) => n.state == NodeState.done);

  static final _ripple = _s(const Color(0x40FFFFFF), 2.5);
  static final _dotLit = _f(const Color(0xFFFFF1B8));
  static final _dotGlow = Paint()
    ..color = const Color(0x55FFE9A0)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  static final _dotDim = _f(const Color(0x80E8EFEA));
  static final _plaque = _f(const Color(0xFFF3E2B8));
  static final _plaqueDim = _f(const Color(0xFFD8D4CA));
  static final _plaqueEdge = _s(const Color(0xFF9C7428), 2.5);
  static final _plaqueEdgeDim = _s(const Color(0xFF9C978B), 2.5);
  static final _star = _f(const Color(0xFFD9A422));
  static final _starOff = _f(const Color(0x80FFFFFF));
  static final _starEdge = _s(const Color(0xFF8A6A2A), 1.4);
  static final _reflection = Paint()
    ..color = const Color(0x33F48CA6)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  static final _glow = Paint()
    ..color = const Color(0x80FFD978)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);

  Color _lerp(Color dull, Color alive, double t) => Color.lerp(dull, alive, t)!;

  @override
  void paint(Canvas canvas, Size size) {
    final L = MapSectionLayout(size.width, nodes.length, worldId);
    final p = _progress;
    final marsh = worldId % 2 == 0;

    // Water: grey and still when untouched, clear jade as levels come alive.
    final top = marsh ? const Color(0xFF6FA59B) : const Color(0xFFBFDCD2);
    final bottom = marsh ? const Color(0xFF2F6F68) : const Color(0xFF4E9C91);
    final water = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
        _lerp(const Color(0xFFB8C3BF), top, p),
        _lerp(const Color(0xFF8C9B96), bottom, p),
      ]);
    canvas.drawRect(Offset.zero & size, water);

    // Ripples and shimmer.
    final rng = math.Random(worldId * 31);
    for (var i = 0; i < 26; i++) {
      final x = rng.nextDouble() * size.width,
          y = rng.nextDouble() * size.height;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y),
              width: 60 + rng.nextDouble() * 80,
              height: 12),
          _ripple);
    }

    // Banks with scenery, alternating sides, alive once the nearby level is done.
    for (var i = 0; i < nodes.length; i += 3) {
      final c = L.node(i);
      final left = c.dx > size.width / 2;
      final alive = nodes[i].state == NodeState.done;
      _bank(canvas, size, c.dy - 20, left, alive, marsh, i);
    }

    // Landmark at the top of the section.
    _landmark(canvas, L, _complete, marsh);

    // Path between nodes.
    for (var i = 0; i + 1 < nodes.length; i++) {
      final a = L.node(i), b = L.node(i + 1);
      final lit = nodes[i].state == NodeState.done;
      final mid =
          Offset((a.dx + b.dx) / 2 + (b.dy - a.dy) * 0.15, (a.dy + b.dy) / 2);
      for (var k = 1; k < 9; k++) {
        final t = k / 9;
        final x =
            (1 - t) * (1 - t) * a.dx + 2 * (1 - t) * t * mid.dx + t * t * b.dx;
        final y =
            (1 - t) * (1 - t) * a.dy + 2 * (1 - t) * t * mid.dy + t * t * b.dy;
        if (lit) canvas.drawCircle(Offset(x, y), 10, _dotGlow);
        canvas.drawCircle(Offset(x, y), 5, lit ? _dotLit : _dotDim);
      }
    }
    // Path from the last node up to the landmark.
    if (nodes.isNotEmpty) {
      final a = L.node(nodes.length - 1), b = L.landmark + const Offset(0, 120);
      for (var k = 1; k < 6; k++) {
        final t = k / 6;
        canvas.drawCircle(
            Offset.lerp(a, b, t)!, 5, _complete ? _dotLit : _dotDim);
      }
    }

    // Nodes, far (top) to near (bottom) so nearer pads overlap farther ones.
    for (var i = nodes.length - 1; i >= 0; i--) {
      final n = nodes[i];
      final c = L.node(i);
      const s = 1.45;
      if (n.state == NodeState.done) {
        canvas.drawOval(
            Rect.fromCenter(
                center: c + const Offset(0, 40), width: 90, height: 40),
            _reflection);
      }
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(s, s);
      PondArt.pad(canvas, alive: n.state != NodeState.locked);
      canvas.restore();
      if (n.state == NodeState.done) {
        if (n.stars == 3) {
          canvas.drawCircle(c + const Offset(0, -30), 44, _glow);
        }
        canvas.save();
        canvas.translate(c.dx, c.dy - 2);
        canvas.scale(s * 0.42 * (0.78 + 0.08 * n.stars),
            s * 0.42 * (0.78 + 0.08 * n.stars));
        PondArt.lotus(canvas, deep: n.stars == 3);
        canvas.restore();
        _stars(canvas, c + const Offset(0, 50), n.stars);
      }
      _plaqueAt(canvas, c + Offset(0, n.state == NodeState.done ? 82 : 58),
          '${n.levelId}', n.state == NodeState.locked);
    }

    // World title.
    _banner(canvas, Offset(size.width / 2, MapSectionLayout.landmarkArea - 46),
        'World $worldId · $worldName');
  }

  void _stars(Canvas c, Offset o, int k) {
    for (var i = 0; i < 3; i++) {
      final p = Path();
      final cx = o.dx + (i - 1) * 22, cy = o.dy;
      for (var j = 0; j < 10; j++) {
        final a = -math.pi / 2 + j * math.pi / 5;
        final r = j.isEven ? 9.0 : 4.0;
        if (j == 0) {
          p.moveTo(cx + math.cos(a) * r, cy + math.sin(a) * r);
        } else {
          p.lineTo(cx + math.cos(a) * r, cy + math.sin(a) * r);
        }
      }
      p.close();
      c.drawPath(p, i < k ? _star : _starOff);
      c.drawPath(p, _starEdge);
    }
  }

  void _plaqueAt(Canvas c, Offset o, String text, bool locked) {
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: o, width: 52, height: 32),
        const Radius.circular(9));
    c.drawRRect(r, locked ? _plaqueDim : _plaque);
    c.drawRRect(r, locked ? _plaqueEdgeDim : _plaqueEdge);
    _text(c, o, text, 19,
        locked ? const Color(0xFF7A766C) : const Color(0xFF6B4A12));
  }

  void _banner(Canvas c, Offset o, String text) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C5C49))),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 56;
    final path = Path()
      ..moveTo(o.dx - w / 2, o.dy - 24)
      ..lineTo(o.dx + w / 2, o.dy - 24)
      ..lineTo(o.dx + w / 2 + 16, o.dy)
      ..lineTo(o.dx + w / 2, o.dy + 24)
      ..lineTo(o.dx - w / 2, o.dy + 24)
      ..lineTo(o.dx - w / 2 - 16, o.dy)
      ..close();
    c.drawPath(path, _plaque);
    c.drawPath(path, _plaqueEdge);
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }

  void _text(Canvas c, Offset o, String t, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: t,
          style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: size,
              fontWeight: FontWeight.w800,
              color: color)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }

  void _bank(
      Canvas c, Size size, double y, bool left, bool alive, bool marsh, int i) {
    final grass = alive
        ? (marsh ? const Color(0xFF6E9F57) : const Color(0xFF8DBF6E))
        : const Color(0xFFA3ABA5);
    final x0 = left ? 0.0 : size.width;
    final dir = left ? 1.0 : -1.0;
    final bank = Path()
      ..moveTo(x0, y - 90)
      ..quadraticBezierTo(x0 + dir * 120, y - 80, x0 + dir * 120, y)
      ..quadraticBezierTo(x0 + dir * 110, y + 70, x0, y + 80)
      ..close();
    c.drawPath(bank, _f(grass));
    // A rock.
    c.drawOval(
        Rect.fromCenter(
            center: Offset(x0 + dir * 100, y + 40), width: 44, height: 24),
        _f(alive ? const Color(0xFFB9BDB5) : const Color(0xFF9EA39D)));
    final px = x0 + dir * 60;
    switch ((i ~/ 3) % 3) {
      case 0: // stone lantern (W1) / paper lantern (W2)
        if (marsh) {
          c.drawLine(Offset(px, y - 70), Offset(px, y + 10),
              _s(const Color(0xFF5A4A3A), 3));
          if (alive) c.drawCircle(Offset(px, y - 48), 26, _glow);
          c.drawOval(
              Rect.fromCenter(
                  center: Offset(px, y - 48), width: 26, height: 32),
              _f(alive ? const Color(0xFFD9443A) : const Color(0xFF8A8F8B)));
        } else {
          c.drawRect(
              Rect.fromCenter(
                  center: Offset(px, y - 10), width: 14, height: 40),
              _f(const Color(0xFFA3A69F)));
          c.drawRect(
              Rect.fromCenter(
                  center: Offset(px, y - 40), width: 36, height: 28),
              _f(const Color(0xFFB4B7B0)));
          if (alive) c.drawCircle(Offset(px, y - 40), 22, _glow);
          c.drawRect(
              Rect.fromCenter(
                  center: Offset(px, y - 40), width: 18, height: 14),
              _f(alive ? const Color(0xFFFFE9A0) : const Color(0xFF8E928C)));
          c.drawPath(
              Path()
                ..moveTo(px - 26, y - 54)
                ..lineTo(px, y - 72)
                ..lineTo(px + 26, y - 54)
                ..close(),
              _f(const Color(0xFF7D827B)));
        }
      case 1: // reeds
        for (var k = 0; k < 5; k++) {
          c.drawPath(
              Path()
                ..moveTo(px + k * 6, y + 20)
                ..quadraticBezierTo(
                    px + k * 6 + 8, y - 40, px + k * 5 - 6, y - 90),
              _s(alive ? const Color(0xFF5E8848) : const Color(0xFF8D978C), 3));
        }
        c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(px + 2, y - 100, 8, 26),
                const Radius.circular(4)),
            _f(const Color(0xFF8A5A2A)));
      default: // willow fronds hanging from the bank
        for (var k = 0; k < 8; k++) {
          final fx = px - 30 + k * 8.0;
          c.drawPath(
              Path()
                ..moveTo(fx, y - 110)
                ..quadraticBezierTo(fx + 10, y - 50, fx - 4, y + 10),
              _s(alive ? const Color(0xFF86AE62) : const Color(0xFF9AA59A), 3));
        }
    }
    // Koi swim back once the pond is alive.
    if (alive) {
      final kx = left ? size.width * 0.78 : size.width * 0.22;
      c.save();
      c.translate(kx, y + 30);
      c.rotate(left ? 0.3 : 2.8);
      c.drawOval(
          const Rect.fromLTWH(-22, -7, 44, 14), _f(const Color(0xFFF3EEE6)));
      c.drawOval(
          const Rect.fromLTWH(-12, -5, 16, 9), _f(const Color(0xFFE8643A)));
      c.drawPath(
          Path()
            ..moveTo(20, 0)
            ..lineTo(34, -9)
            ..lineTo(31, 0)
            ..lineTo(34, 9)
            ..close(),
          _f(const Color(0xFFE8643A)));
      c.restore();
    }
  }

  void _landmark(Canvas c, MapSectionLayout L, bool lit, bool marsh) {
    final o = L.landmark;
    if (lit) c.drawCircle(o, 150, _glow);
    if (!marsh) {
      // Moon Bridge: a high stone arch whose reflection completes the
      // "moon" circle, with a red railing and lanterns at both ends.
      final x0 = o.dx, y0 = o.dy + 60;
      final stone = lit ? const Color(0xFFEFE3C8) : const Color(0xFFAEB1AA);
      final stoneDark = lit ? const Color(0xFFC9B48C) : const Color(0xFF8F938C);
      final rail = lit ? const Color(0xFFC0392B) : const Color(0xFF7F8580);
      final edge = lit ? const Color(0xFF8A5A3A) : const Color(0xFF6E736D);
      // Moon.
      c.drawCircle(o + const Offset(120, -150), 30,
          _f(lit ? const Color(0xFFFFF3C4) : const Color(0xFFCBCFCB)));
      // Reflection: the opening mirrored under the water line, plus a soft
      // inverted bridge.
      final reflect = Path()
        ..moveTo(x0 - 170, y0)
        ..quadraticBezierTo(x0, y0 + 270, x0 + 170, y0)
        ..lineTo(x0 + 120, y0)
        ..quadraticBezierTo(x0, y0 + 150, x0 - 120, y0)
        ..close();
      c.drawPath(
          reflect, _f(lit ? const Color(0x55C9B48C) : const Color(0x33000000)));
      final hole = Path()
        ..moveTo(x0 - 120, y0)
        ..quadraticBezierTo(x0, y0 + 150, x0 + 120, y0)
        ..close();
      c.drawPath(
          hole, _f(lit ? const Color(0x33FFF3C4) : const Color(0x14000000)));
      // Bridge body with its arch opening.
      final body = Path()
        ..moveTo(x0 - 170, y0)
        ..quadraticBezierTo(x0, y0 - 210, x0 + 170, y0)
        ..lineTo(x0 + 120, y0)
        ..quadraticBezierTo(x0, y0 - 150, x0 - 120, y0)
        ..close();
      c.drawPath(body, _f(stone));
      // Voussoir band along the opening.
      c.drawPath(
          Path()
            ..moveTo(x0 - 132, y0)
            ..quadraticBezierTo(x0, y0 - 170, x0 + 132, y0)
            ..lineTo(x0 + 120, y0)
            ..quadraticBezierTo(x0, y0 - 150, x0 - 120, y0)
            ..close(),
          _f(stoneDark));
      c.drawPath(body, _s(edge, 2.5));
      // Railing: posts from the deck to a rail 22 px above it.
      double deckY(double t) => y0 - 210 * t * (1 - t);
      final railPath = Path();
      for (var i = 0; i <= 20; i++) {
        final t = i / 20;
        final x = x0 - 170 + 340 * t;
        final y = deckY(t) - 22;
        if (i == 0) {
          railPath.moveTo(x, y);
        } else {
          railPath.lineTo(x, y);
        }
      }
      final postPaint = _s(rail, 4);
      for (var i = 1; i < 10; i++) {
        final t = i / 10;
        final x = x0 - 170 + 340 * t;
        c.drawLine(Offset(x, deckY(t)), Offset(x, deckY(t) - 22), postPaint);
      }
      c.drawPath(railPath, _s(rail, 5));
      // Lanterns on tall posts at both ends.
      for (final dx in const [-182.0, 182.0]) {
        final lx = x0 + dx;
        c.drawLine(Offset(lx, y0 + 4), Offset(lx, y0 - 70),
            _s(const Color(0xFF4A3A2E), 4));
        if (lit) c.drawCircle(Offset(lx, y0 - 82), 26, _glow);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(lx, y0 - 82), width: 22, height: 28),
                const Radius.circular(9)),
            _f(lit ? const Color(0xFFE0453A) : const Color(0xFF8A8F8B)));
        c.drawLine(Offset(lx - 8, y0 - 96), Offset(lx + 8, y0 - 96),
            _s(const Color(0xFF4A3A2E), 3));
        if (lit) {
          c.drawCircle(Offset(lx, y0 - 82), 5, _f(const Color(0xFFFFE9A0)));
        }
      }
    } else {
      // Lantern Shrine: stone steps, red pillars, a two-tier roof with
      // upturned eaves, and lanterns strung on both sides.
      final x0 = o.dx, y0 = o.dy;
      final red = lit ? const Color(0xFFC0392B) : const Color(0xFF8E8F8A);
      final redDark = lit ? const Color(0xFF8E2A20) : const Color(0xFF6F716C);
      final roof = lit ? const Color(0xFF2F5D50) : const Color(0xFF5B625E);
      final roofEdge = lit ? const Color(0xFFE7B53C) : const Color(0xFF7A7F7A);
      final stoneC = lit ? const Color(0xFFE6DCC6) : const Color(0xFFA9ACA5);
      // Reflection.
      c.drawRect(Rect.fromLTWH(x0 - 110, y0 + 72, 220, 40),
          _f(lit ? const Color(0x33C0392B) : const Color(0x1A000000)));
      // Steps / platform.
      c.drawRect(Rect.fromLTWH(x0 - 130, y0 + 56, 260, 16), _f(stoneC));
      c.drawRect(Rect.fromLTWH(x0 - 112, y0 + 44, 224, 14), _f(stoneC));
      c.drawRect(Rect.fromLTWH(x0 - 130, y0 + 56, 260, 16),
          _s(const Color(0x33000000), 1.5));
      // Hall.
      c.drawRect(Rect.fromLTWH(x0 - 90, y0 - 18, 180, 62), _f(redDark));
      for (final px in const [-84.0, -40.0, 30.0, 74.0]) {
        c.drawRect(Rect.fromLTWH(x0 + px, y0 - 18, 10, 62), _f(red));
      }
      c.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(x0 - 18, y0 + 2, 36, 42),
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18)),
          _f(lit ? const Color(0xFFFFD877) : const Color(0xFF4A4A46)));
      // Roof helper: upturned eaves.
      void tier(double y, double half, double h) {
        final p = Path()
          ..moveTo(x0 - half - 18, y - 8)
          ..quadraticBezierTo(x0 - half + 6, y + 4, x0 - half + 20, y)
          ..lineTo(x0 + half - 20, y)
          ..quadraticBezierTo(x0 + half - 6, y + 4, x0 + half + 18, y - 8)
          ..quadraticBezierTo(
              x0 + half - 20, y - h * 0.4, x0 + half * 0.55, y - h)
          ..lineTo(x0 - half * 0.55, y - h)
          ..quadraticBezierTo(
              x0 - half + 20, y - h * 0.4, x0 - half - 18, y - 8)
          ..close();
        c.drawPath(p, _f(roof));
        c.drawPath(p, _s(roofEdge, 3));
      }

      c.drawRect(Rect.fromLTWH(x0 - 60, y0 - 62, 120, 20), _f(redDark));
      tier(y0 - 18, 112, 30);
      tier(y0 - 62, 76, 32);
      c.drawCircle(Offset(x0, y0 - 100), 7, _f(roofEdge));
      c.drawLine(Offset(x0, y0 - 94), Offset(x0, y0 - 116), _s(roofEdge, 3));
      // Lantern strings.
      for (final side in const [-1.0, 1.0]) {
        final string = Path()
          ..moveTo(x0 + side * 120, y0 - 26)
          ..quadraticBezierTo(
              x0 + side * 160, y0 - 4, x0 + side * 196, y0 - 40);
        c.drawPath(string, _s(const Color(0xFF4A3A2E), 2));
        for (final t in const [0.35, 0.75]) {
          final lx = x0 + side * (120 + 76 * t);
          final ly = y0 - 26 + (1 - t) * t * 2 * 22 - t * t * 14 + 14;
          if (lit) c.drawCircle(Offset(lx, ly), 22, _glow);
          c.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: Offset(lx, ly), width: 20, height: 24),
                  const Radius.circular(9)),
              _f(lit ? const Color(0xFFE0453A) : const Color(0xFF8A8F8B)));
          if (lit) c.drawCircle(Offset(lx, ly), 4, _f(const Color(0xFFFFE9A0)));
        }
      }
    }
    _text(
        c,
        o + const Offset(0, 112),
        lit ? landmarkName : '$landmarkName (dormant)',
        17,
        lit ? const Color(0xFF1C5C49) : const Color(0xFF5F6964));
  }

  @override
  bool shouldRepaint(MapSectionPainter old) => true;
}
