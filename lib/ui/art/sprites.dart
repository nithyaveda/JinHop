// Cute 2.5D character sprites: frog, Jin Chan (golden three-legged toad) and
// the sleeping snake. Drawn entirely with vector paths in a fixed 400x400
// design box (ground contact at 200,330). Paths, paints and shaders are built
// once (static); callers translate + scale the canvas, so nothing is allocated
// per frame.
//
// Views: north = seen from behind, east = side, south = facing the viewer,
// west = mirrored east.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../core/models.dart';

/// Paint roles used by sprite drawing ops.
enum _R {
  shadow,
  outline,
  body,
  leg,
  belly,
  legOutline,
  legOutlineThick,
  legStroke,
  legStrokeThick,
  white,
  iris,
  gloss,
  spot,
  mouth,
  ink,
  toe,
  toeOutline,
  toeLine,
  blush,
  coinRim,
  coin,
  coinRing,
  coinHole,
  jewelSet,
  jewelRed,
  jewelGreen,
  jewelOrange,
  jewelPink,
  glint,
  bump,
  bumpOutline,
  lid,
  snakeDark,
  snakeTop,
  snakeScale,
  snakeEye,
  zzz,
}

class _Op {
  final Path path;
  final _R role;
  const _Op(this.path, this.role);
}

class _Sprite {
  final List<_Op> ops = [];
  void add(Path p, _R r) => ops.add(_Op(p, r));
}

Path _circle(double x, double y, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
Path _oval(double x, double y, double rx, double ry) => Path()
  ..addOval(
      Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2));
Path _rotatedOval(double x, double y, double rx, double ry, double deg) {
  final m = Float64List(16);
  final a = deg * math.pi / 180, c = math.cos(a), s = math.sin(a);
  // rotate about (x,y)
  m[0] = c;
  m[1] = s;
  m[4] = -s;
  m[5] = c;
  m[10] = 1;
  m[15] = 1;
  m[12] = x - c * x + s * y;
  m[13] = y - s * x - c * y;
  return _oval(x, y, rx, ry).transform(m);
}

Path _scaleX(Path p, double k, double cx) {
  final m = Float64List(16);
  m[0] = k;
  m[5] = 1;
  m[10] = 1;
  m[15] = 1;
  m[12] = cx - k * cx;
  return p.transform(m);
}

/// Adds a webbed three-toe foot to the sprite.
void _toes(_Sprite s, double x, double y, double spread, double deg) {
  final a = deg * math.pi / 180, c = math.cos(a), sn = math.sin(a);
  Offset t(double dx, double dy) =>
      Offset(x + dx * c - dy * sn, y + dx * sn + dy * c);
  final lines = Path();
  final tips = Path();
  for (var i = 0; i < 3; i++) {
    final dx = (i - 1) * spread;
    final p0 = t(0, -6), p1 = t(dx, 4);
    lines
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy);
    final c1 = t(dx, 5);
    tips.addOval(Rect.fromCircle(center: c1, radius: 6));
  }
  final pad = _rotatedOval(x, y - 4, spread * 0.9, 7, deg);
  s
    ..add(lines, _R.toeLine)
    ..add(tips, _R.toe)
    ..add(tips, _R.toeOutline)
    ..add(pad, _R.toe);
}

void _eye(_Sprite s, double cx, double cy, double r, double lx, double ly) {
  final white = _circle(cx, cy, r);
  s
    ..add(white, _R.white)
    ..add(white, _R.outline)
    ..add(_circle(cx + lx, cy + ly, r * 0.68), _R.iris)
    ..add(_circle(cx + lx - r * 0.25, cy + ly - r * 0.28, r * 0.24), _R.glint)
    ..add(_circle(cx + lx + r * 0.22, cy + ly + r * 0.25, r * 0.1), _R.glint);
}

void _jewel(_Sprite s, double x, double y, double r, _R color) {
  final set = _circle(x, y, r + 4);
  s
    ..add(set, _R.jewelSet)
    ..add(set, _R.bumpOutline)
    ..add(_circle(x, y, r), color)
    ..add(_circle(x - r * 0.35, y - r * 0.35, r * 0.32), _R.glint);
}

void _bumps(_Sprite s, List<List<double>> pts) {
  final p = Path();
  for (final b in pts) {
    p.addOval(Rect.fromCircle(center: Offset(b[0], b[1]), radius: b[2]));
  }
  s
    ..add(p, _R.bump)
    ..add(p, _R.bumpOutline);
}

void _coin(_Sprite s, double x, double y, double rx, double ry) {
  final rim = _oval(x, y, rx, ry);
  s
    ..add(rim, _R.coinRim)
    ..add(rim, _R.outline)
    ..add(_oval(x - 2, y - 2, rx * 0.9, ry * 0.88), _R.coin)
    ..add(_oval(x - 2, y - 2, rx * 0.63, ry * 0.6), _R.coinRing)
    ..add(
        Path()
          ..addRect(Rect.fromCenter(
              center: Offset(x - 2, y - 1),
              width: rx * 0.46,
              height: rx * 0.46)),
        _R.coinHole);
}

// ---------------------------------------------------------------- frog views

const _sideBody =
    'M88,308 C58,250 72,165 160,138 C215,120 268,124 298,158 C330,194 326,258 288,300 C258,328 140,336 88,308 Z';
const _frontBody =
    'M110,300 C92,230 120,150 200,148 C280,150 308,230 290,300 C262,330 138,330 110,300 Z';

/// Tiny SVG-path parser for the M/C/L/Q/Z commands used above.
Path _svg(String d) {
  final p = Path();
  final tokens = RegExp(r'[MCLQZ]|-?\d+(?:\.\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        p.moveTo(n(), n());
      case 'L':
        p.lineTo(n(), n());
      case 'C':
        p.cubicTo(n(), n(), n(), n(), n(), n());
      case 'Q':
        p.quadraticBezierTo(n(), n(), n(), n());
      case 'Z':
        p.close();
    }
  }
  return p;
}

Path _stroke(String d) => _svg(d);

_Sprite _side({required bool jin}) {
  final s = _Sprite();
  s.add(_oval(200, 332, 150, 26), _R.shadow);
  final farEye = _circle(318, 150, 20);
  s
    ..add(farEye, _R.body)
    ..add(farEye, _R.outline);
  final farLeg = _stroke('M300,262 C312,285 314,305 310,318');
  s
    ..add(farLeg, _R.legOutline)
    ..add(farLeg, _R.legStroke);
  _toes(s, 312, 322, 11, 0);
  var body = _svg(_sideBody);
  if (jin) body = _scaleX(body, 1.08, 200);
  s
    ..add(body, _R.body)
    ..add(body, _R.outline)
    ..add(
        _svg(
            'M196,318 C198,262 232,222 300,206 C318,238 312,286 272,312 C250,326 220,326 196,318 Z'),
        _R.belly)
    ..add(_stroke('M120,190 C135,160 165,145 200,140'), _R.gloss);
  final haunch = _rotatedOval(135, 268, 58, 44, -18);
  s
    ..add(haunch, _R.leg)
    ..add(haunch, _R.outline);
  _toes(s, 118, 318, 14, -8);
  final nearLeg = _stroke('M248,262 C250,285 246,305 240,318');
  s
    ..add(nearLeg, _R.legOutlineThick)
    ..add(nearLeg, _R.legStrokeThick);
  _toes(s, 240, 324, 13, 0);
  final head = _circle(262, 150, 40);
  s
    ..add(head, _R.body)
    ..add(head, _R.outline)
    ..add(_svg('M226,170 C240,184 280,186 300,170 Z'), _R.body);
  _eye(s, 264, 148, jin ? 30 : 27, 4, 2);
  s
    ..add(_oval(318, 182, 3.5, 2.5), _R.ink)
    ..add(_stroke('M262,204 C282,214 304,208 322,194'), _R.mouth);
  if (!jin) {
    final spots = Path();
    for (final b in const [
      [150.0, 172.0, 11.0],
      [176.0, 158.0, 7.0],
      [128.0, 198.0, 7.0],
      [110.0, 262.0, 8.0],
      [132.0, 246.0, 6.0],
      [158.0, 280.0, 5.0],
    ]) {
      spots.addOval(Rect.fromCenter(
          center: Offset(b[0], b[1]), width: b[2] * 2, height: b[2] * 1.6));
    }
    s.add(spots, _R.spot);
  } else {
    _bumps(s, const [
      [122, 210, 5],
      [180, 140, 5],
      [215, 132, 4],
      [100, 255, 4],
      [160, 300, 4],
      [230, 160, 4],
    ]);
    _jewel(s, 150, 168, 9, _R.jewelRed);
    _jewel(s, 110, 205, 7, _R.jewelGreen);
    _jewel(s, 190, 150, 6, _R.jewelOrange);
    _jewel(s, 130, 245, 7, _R.jewelPink);
    _jewel(s, 175, 200, 6, _R.jewelGreen);
    _jewel(s, 95, 280, 6, _R.jewelRed);
    // Coin held in the mouth, seen at an angle; the upper lip clamps it.
    // Coin held at the mouth, at the edge of the face.
    _coin(s, 326, 222, 13, 26);
    s
      ..add(_stroke('M262,204 C282,214 304,208 322,194'), _R.mouth)
      ..add(_oval(282, 188, 16, 9), _R.blush);
  }
  return s;
}

_Sprite _front({required bool jin}) {
  final s = _Sprite();
  s.add(_oval(200, 332, 140, 24), _R.shadow);
  if (!jin) {
    for (final sx in const [-1.0, 1.0]) {
      final h = _oval(200 + sx * 95, 272, 46, 42);
      s
        ..add(h, _R.leg)
        ..add(h, _R.outline);
      _toes(s, 200 + sx * 112, 320, 13, sx * 10);
    }
  }
  var body = _svg(_frontBody);
  if (jin) body = _scaleX(body, 1.08, 200);
  s
    ..add(body, _R.body)
    ..add(body, _R.outline)
    ..add(
        _svg(
            'M140,305 C140,250 165,222 200,222 C235,222 260,250 260,305 C235,322 165,322 140,305 Z'),
        _R.belly)
    ..add(_stroke('M138,200 C150,175 170,165 190,162'), _R.gloss);
  for (final sx in const [-1.0, 1.0]) {
    final b = _circle(200 + sx * 52, 150, 38);
    s
      ..add(b, _R.body)
      ..add(b, _R.outline);
  }
  s.add(Path()..addRect(const Rect.fromLTRB(160, 170, 240, 192)), _R.body);
  for (final sx in const [-1.0, 1.0]) {
    _eye(s, 200 + sx * 52, 148, jin ? 29 : 26, 0, 4);
  }
  for (final sx in jin ? const <double>[] : const [-1.0, 1.0]) {
    final leg = _stroke(
        'M${200 + sx * 42},262 C${200 + sx * 44},285 ${200 + sx * 42},305 ${200 + sx * 40},318');
    s
      ..add(leg, _R.legOutline)
      ..add(leg, _R.legStroke);
    _toes(s, 200 + sx * 40, 324, 12, 0);
  }
  s
    ..add(
        _stroke(jin
            ? 'M160,200 C180,220 220,220 240,200'
            : 'M165,205 C185,220 215,220 235,205'),
        _R.mouth)
    ..add(_oval(190, 190, 3, 2.2), _R.ink)
    ..add(_oval(210, 190, 3, 2.2), _R.ink);
  if (!jin) {
    final spots = Path();
    for (final b in const [
      [92.0, 258.0, 7.0],
      [308.0, 258.0, 7.0],
      [128.0, 205.0, 6.0],
      [272.0, 205.0, 6.0],
    ]) {
      spots.addOval(Rect.fromCenter(
          center: Offset(b[0], b[1]), width: b[2] * 2, height: b[2] * 1.6));
    }
    s.add(spots, _R.spot);
  } else {
    _bumps(s, const [
      [120, 240, 4],
      [282, 250, 4],
      [175, 176, 4],
      [228, 172, 4],
    ]);
    _jewel(s, 128, 218, 7, _R.jewelRed);
    _jewel(s, 274, 228, 7, _R.jewelGreen);
    _jewel(s, 146, 270, 6, _R.jewelOrange);
    _jewel(s, 258, 276, 6, _R.jewelPink);
    s
      ..add(_oval(156, 198, 15, 8), _R.blush)
      ..add(_oval(244, 198, 15, 8), _R.blush);
    // Three legs: the single hind foot peeks out in the middle.
    _toes(s, 200, 328, 11, 0);
    // The coin, held in the mouth: it hangs from the lips, the upper lip
    // covering its top edge.
    _coin(s, 200, 228, 30, 28);
    s
      ..add(_svg('M166,200 C182,218 218,218 234,200 L234,194 L166,194 Z'),
          _R.body)
      ..add(_stroke('M160,200 C180,220 220,220 240,200'), _R.mouth);
    // Two front legs resting on the ground at the belly.
    for (final sx in const [-1.0, 1.0]) {
      final arm = _rotatedOval(200 + sx * 50, 298, 14, 18, sx * 12);
      s
        ..add(arm, _R.toe)
        ..add(arm, _R.outline);
      _toes(s, 200 + sx * 52, 324, 11, sx * 6);
    }
  }
  return s;
}

_Sprite _back({required bool jin}) {
  final s = _Sprite();
  s.add(_oval(200, 332, 140, 24), _R.shadow);
  if (!jin) {
    for (final sx in const [-1.0, 1.0]) {
      final h = _oval(200 + sx * 95, 274, 48, 42);
      s
        ..add(h, _R.leg)
        ..add(h, _R.outline);
      _toes(s, 200 + sx * 115, 322, 13, sx * 10);
    }
  }
  var body = _svg(_frontBody);
  if (jin) body = _scaleX(body, 1.08, 200);
  s
    ..add(body, _R.body)
    ..add(body, _R.outline);
  if (jin) {
    final hind = _oval(200, 300, 44, 30);
    s
      ..add(hind, _R.leg)
      ..add(hind, _R.outline);
    _toes(s, 200, 328, 14, 0);
  }
  for (final sx in const [-1.0, 1.0]) {
    final b = _circle(200 + sx * 50, 156, 34);
    s
      ..add(b, _R.body)
      ..add(b, _R.outline);
  }
  s
    ..add(Path()..addRect(const Rect.fromLTRB(164, 172, 236, 194)), _R.body)
    ..add(_stroke('M126,150 C134,134 150,126 166,128'), _R.lid)
    ..add(_stroke('M234,128 C250,126 266,134 274,150'), _R.lid)
    ..add(_stroke('M140,210 C155,185 180,176 200,174'), _R.gloss);
  if (!jin) {
    final spots = Path();
    for (final b in const [
      [168.0, 232.0, 10.0],
      [232.0, 250.0, 8.0],
      [200.0, 204.0, 7.0],
      [150.0, 280.0, 6.0],
      [252.0, 292.0, 6.0],
    ]) {
      spots.addOval(Rect.fromCenter(
          center: Offset(b[0], b[1]), width: b[2] * 2, height: b[2] * 1.6));
    }
    s.add(spots, _R.spot);
  } else {
    _bumps(s, const [
      [150, 210, 5],
      [250, 214, 5],
      [200, 190, 4],
      [130, 262, 4],
      [270, 262, 4],
    ]);
    _jewel(s, 170, 236, 9, _R.jewelRed);
    _jewel(s, 232, 246, 8, _R.jewelGreen);
    _jewel(s, 200, 278, 7, _R.jewelOrange);
    _jewel(s, 146, 286, 6, _R.jewelPink);
    _jewel(s, 256, 290, 6, _R.jewelRed);
  }
  return s;
}

_Sprite _snake() {
  final s = _Sprite();
  s.add(_oval(200, 334, 120, 30), _R.shadow);
  const rings = [
    [104.0, 36.0, 312.0],
    [84.0, 31.0, 282.0],
    [63.0, 26.0, 254.0],
  ];
  for (final r in rings) {
    final lower = _oval(200, r[2] + 12, r[0], r[1]);
    final upper = _oval(200, r[2], r[0], r[1]);
    s
      ..add(lower, _R.snakeDark)
      ..add(lower, _R.outline)
      ..add(upper, _R.snakeTop)
      ..add(upper, _R.outline);
    final scales = Path();
    for (var k = 0; k < 9; k++) {
      final a = math.pi * (0.1 + 0.8 * k / 8);
      scales.addOval(Rect.fromCircle(
          center: Offset(200 - math.cos(a) * r[0] * 0.75,
              r[2] + math.sin(a) * r[1] * 0.55),
          radius: 3.2));
    }
    s.add(scales, _R.snakeScale);
  }
  final head = _oval(216, 226, 44, 28);
  s
    ..add(head, _R.snakeTop)
    ..add(head, _R.outline)
    ..add(_stroke('M206,222 Q220,234 234,222'), _R.snakeEye)
    ..add(_stroke('M262,186 L280,186 L262,204 L280,204'), _R.zzz)
    ..add(_stroke('M288,158 L300,158 L288,170 L300,170'), _R.zzz);
  return s;
}

// ------------------------------------------------------------------ palettes

Paint _fill(Color c) => Paint()..color = c;
Paint _strokeP(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Map<_R, Paint> _palette({
  required Color outline,
  required List<Color> body,
  required List<Color> leg,
  required List<Color> belly,
  required Color legSolid,
  required Color spot,
}) {
  return {
    _R.shadow: Paint()
      ..color = const Color(0x401E1E24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    _R.outline: _strokeP(outline, 6),
    _R.body: Paint()
      ..shader = Gradient.radial(
          const Offset(150, 150), 230, body, const [0, 0.45, 1]),
    _R.leg: Paint()
      ..shader =
          Gradient.radial(const Offset(110, 230), 120, leg, const [0, 0.6, 1]),
    _R.belly: Paint()
      ..shader =
          Gradient.linear(const Offset(0, 210), const Offset(0, 325), belly),
    _R.legOutline: _strokeP(outline, 22),
    _R.legOutlineThick: _strokeP(outline, 26),
    _R.legStroke: _strokeP(legSolid, 13),
    _R.legStrokeThick: _strokeP(legSolid, 16),
    _R.white: _fill(const Color(0xFFFFFFFF)),
    _R.iris: _fill(const Color(0xFF231915)),
    _R.gloss: _strokeP(const Color(0x8CFFFFFF), 10),
    _R.spot: _fill(spot),
    _R.mouth: _strokeP(outline, 5),
    _R.ink: _fill(outline),
    _R.toe: _fill(legSolid),
    _R.toeOutline: _strokeP(outline, 3.5),
    _R.toeLine: _strokeP(legSolid, 9),
    _R.blush: _fill(const Color(0x8CF28B8B)),
    _R.coinRim: _fill(const Color(0xFFB5841C)),
    _R.coin: Paint()
      ..shader = Gradient.linear(
          const Offset(0, 226),
          const Offset(0, 304),
          const [Color(0xFFFFF1B0), Color(0xFFF2C64E), Color(0xFFC9921E)],
          const [0, 0.5, 1]),
    _R.coinRing: _strokeP(const Color(0xFFB5841C), 2.5),
    _R.coinHole: _fill(const Color(0xFF8A5A0A)),
    _R.jewelSet: _fill(const Color(0xFFE7A92A)),
    _R.jewelRed: _fill(const Color(0xFFD9333F)),
    _R.jewelGreen: _fill(const Color(0xFF2FAE6B)),
    _R.jewelOrange: _fill(const Color(0xFFF07F22)),
    _R.jewelPink: _fill(const Color(0xFFE35F96)),
    _R.glint: _fill(const Color(0xE6FFFFFF)),
    _R.bump: _fill(const Color(0xFFFFDF7E)),
    _R.bumpOutline: _strokeP(outline, 2.5),
    _R.lid: _strokeP(const Color(0x66FFFFFF), 5),
    _R.snakeDark: _fill(const Color(0xFF1F2B26)),
    _R.snakeTop: _fill(const Color(0xFF2E4038)),
    _R.snakeScale: _fill(const Color(0x99D9A422)),
    _R.snakeEye: _strokeP(const Color(0xFFF2CF63), 5),
    _R.zzz: _strokeP(const Color(0xFF5FB394), 4),
  };
}

/// Which way a sprite is drawn from.
enum SpriteView { back, side, front }

class Sprites {
  Sprites._();

  static final _frogPaints = _palette(
    outline: const Color(0xFF1C5C49),
    body: const [Color(0xFF9BE3AE), Color(0xFF4DBB7E), Color(0xFF23855C)],
    leg: const [Color(0xFF86D9A0), Color(0xFF3FA872), Color(0xFF1F7A52)],
    belly: const [Color(0xFFE4FBEA), Color(0xFFA9E8C0)],
    legSolid: const Color(0xFF3FA872),
    spot: const Color(0xE6B6EDC6),
  );
  static final _jinPaints = _palette(
    outline: const Color(0xFF8A5A0A),
    body: const [Color(0xFFFFF0A6), Color(0xFFF6C443), Color(0xFFC98A12)],
    leg: const [Color(0xFFFFE27A), Color(0xFFEBB12F), Color(0xFFB97C0E)],
    belly: const [Color(0xFFFFF6CF), Color(0xFFF7D97A)],
    legSolid: const Color(0xFFEBB12F),
    spot: const Color(0xFFFFDF7E),
  );
  static final _snakePaints = _palette(
    outline: const Color(0xFF141C19),
    body: const [Color(0xFF2E4038), Color(0xFF2E4038), Color(0xFF2E4038)],
    leg: const [Color(0xFF2E4038), Color(0xFF2E4038), Color(0xFF2E4038)],
    belly: const [Color(0xFF2E4038), Color(0xFF2E4038)],
    legSolid: const Color(0xFF2E4038),
    spot: const Color(0xFF2E4038),
  );

  static final _frog = {
    SpriteView.back: _back(jin: false),
    SpriteView.side: _side(jin: false),
    SpriteView.front: _front(jin: false),
  };
  static final _jin = {
    SpriteView.back: _back(jin: true),
    SpriteView.side: _side(jin: true),
    SpriteView.front: _front(jin: true),
  };
  static final _snakeSprite = _snake();

  /// Design-box width of a frog body; use to pick a scale.
  static const double bodyWidth = 240;

  static SpriteView viewFor(Facing f) => switch (f) {
        Facing.n => SpriteView.back,
        Facing.s => SpriteView.front,
        Facing.e || Facing.w => SpriteView.side,
      };

  static void _run(Canvas c, _Sprite s, Map<_R, Paint> paints) {
    for (final op in s.ops) {
      c.drawPath(op.path, paints[op.role]!);
    }
  }

  /// Draws a frog with its feet at the canvas origin. [width] is the on-screen
  /// body width; [squashX] (0..1) is used for the rotator turn animation.
  static void frog(Canvas c, Facing facing, double width,
      {bool golden = false, double squashX = 1, bool shadow = true}) {
    final k = width / bodyWidth;
    c.save();
    c.scale(k * squashX * (facing == Facing.w ? -1 : 1), k);
    c.translate(-200, -330);
    final s = (golden ? _jin : _frog)[viewFor(facing)]!;
    final paints = golden ? _jinPaints : _frogPaints;
    if (shadow) {
      _run(c, s, paints);
    } else {
      for (final op in s.ops) {
        if (op.role != _R.shadow) c.drawPath(op.path, paints[op.role]!);
      }
    }
    c.restore();
  }

  /// Draws the sleeping snake with its base at the canvas origin.
  static void snake(Canvas c, double width) {
    final k = width / bodyWidth;
    c.save();
    c.scale(k, k);
    c.translate(-200, -330);
    _run(c, _snakeSprite, _snakePaints);
    c.restore();
  }
}
