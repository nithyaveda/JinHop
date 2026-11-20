// 2.5D board rendering.
//
// Camera: tilted so rows stay level (north = up the screen, east = right).
// Each row is drawn back (north) to front (south) so nearer frogs overlap
// farther ones. The pond starts dull and grey; when the golden frog is freed
// Jin Chan leaps, and colour washes out from its pad while the empty pads
// bloom into lotuses.
//
// No Paints/Paths/Shaders are created per frame: sprite and pad art is
// static (lib/ui/art), size-dependent shaders live in BoardArtCache.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/core.dart';
import 'art/pond.dart';
import 'art/sprites.dart';

const int kJumpUs = 420000;
const int kShakeUs = 320000;
const int kTurnUs = 300000;
const int kFlashUs = 450000;
const int kRippleUs = 600000;
const int kPulseUs = 2400000; // rotator intro: 3 gentle pulses

// Finale timing.
const int kGoldenLeapUs = 650000;
const int kWashUs = 1100000;
const int kBloomUs = 520000;

/// Screen geometry of the tilted board.
class BoardLayout {
  static const double headroom = 0.78, rowFactor = 0.72, footer = 0.4;
  final int n;
  final double width;
  const BoardLayout(this.n, this.width);

  static double aspectRatio(int n) => n / (headroom + n * rowFactor + footer);

  double get cw => width / n;
  double get rowH => cw * rowFactor;
  double get top => cw * headroom;
  double get height => cw * (headroom + n * rowFactor + footer);

  /// Pad centre for (possibly fractional) grid coordinates.
  double px(double gx) => (gx + 0.5) * cw;
  double py(double gy) => top + (gy + 0.5) * rowH;
  Offset padCenter(int x, int y) => Offset(px(x.toDouble()), py(y.toDouble()));

  /// Centre of the frog's body standing on (x, y): where a finger taps it.
  Offset tapPoint(int x, int y) =>
      Offset(px(x.toDouble()), py(y.toDouble()) - cw * 0.24);

  /// Where a frog standing on (x, y) visually is (used for taps).
  Rect bodyRect(int x, int y) {
    final cx = px(x.toDouble()), cy = py(y.toDouble());
    return Rect.fromLTRB(
        cx - cw * 0.36, cy - cw * 0.64, cx + cw * 0.36, cy + cw * 0.16);
  }

  /// Frog under [p]: nearer rows win because they are drawn on top.
  int hitFrog(Offset p, Board b, int mask) {
    for (var y = n - 1; y >= 0; y--) {
      for (var x = 0; x < n; x++) {
        final f = b.frogAtCell[y * n + x];
        if (f >= 0 && b.isPresent(mask, f) && bodyRect(x, y).contains(p)) {
          return f;
        }
      }
    }
    return -1;
  }
}

class JumpFx {
  final int frog;
  final Facing facing;
  final int startUs;
  final double distanceCells;
  JumpFx(this.frog, this.facing, this.startUs, this.distanceCells);
}

/// Mutable animation state shared by BoardView, BoardController and the
/// painter. Mutated only on events, never per frame (except nowUs).
class BoardFx {
  int nowUs = 0;
  final List<JumpFx> jumps = [];
  final List<int> shakeStartUs;
  int flashFrog = -1;
  int flashSnakeCell = -1;
  int flashStartUs = -1000000000;
  int turnStartUs = -1000000000;
  int turnDir = 1;
  int previewFrog = -1;
  int hintFrog = -1;
  int hintStartUs = 0;
  int pulseStartUs = -1000000000;

  // Finale
  int finaleStartUs = -1;
  bool finaleNotified = false;

  /// Pond fully alive (after a win).
  bool alive = false;

  BoardFx(int frogCount)
      : shakeStartUs = List<int>.filled(frogCount, -1000000000);

  bool finaleScheduled = false;

  /// Jin Chan's golden leap starts right away (it is the winning hop).
  int get phaseBUs => 0;
  int get washStartUs => 300000;
  int get finaleDurationUs => washStartUs + kWashUs + 700000 + kBloomUs;
  int get finaleEndUs => finaleStartUs + finaleDurationUs;
  bool get finaleRunning => finaleScheduled && nowUs < finaleEndUs;

  bool get busy {
    if (jumps.isNotEmpty) return true;
    if (finaleScheduled && !finaleNotified) return true;
    if (nowUs - turnStartUs < kTurnUs) return true;
    if (nowUs - flashStartUs < kFlashUs) return true;
    if (nowUs - pulseStartUs < kPulseUs) return true;
    for (final s in shakeStartUs) {
      if (nowUs - s < kShakeUs) return true;
    }
    return hintFrog >= 0;
  }

  void prune() {
    jumps.removeWhere((j) => nowUs - j.startUs >= kJumpUs + kRippleUs);
  }
}

/// Size-dependent shaders and scratch paths, owned by BoardView.
class BoardArtCache {
  double _w = -1, _h = -1;
  final Paint dullWater = Paint();
  final Paint aliveWater = Paint();
  final Paint rim = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0x33FFFFFF);
  final Path pond = Path();
  final Path washClip = Path();
  final Paint ripple = Paint()..style = PaintingStyle.stroke;
  final Paint rayDot = Paint()..color = const Color(0xFFD9A422);
  final Paint rayBlocked = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFFE0A030);
  final Paint hint = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFFF2CF63);
  final Paint glow = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xCCF2CF63);
  // Hint: soft gold disc, dimming veil, white-edged path dots, arrow head.
  final Paint hintFill = Paint()..color = const Color(0x99FFE07A);
  final Paint hintVeil = Paint()..color = const Color(0x7A1B2B27);
  final Paint hintDot = Paint()..color = const Color(0xFFFFD54A);
  final Paint hintDotEdge = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFFFFFFFF);
  final Path hintArrow = Path();
  final Paint flightShadow = Paint()
    ..color = const Color(0x331E1E24)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final Paint sparkle = Paint()..color = const Color(0xFFFFF4C2);
  final List<Offset> sparkles = [];

  void ensure(Size s, double cw) {
    if (s.width == _w && s.height == _h) return;
    _w = s.width;
    _h = s.height;
    final r =
        RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(cw * 0.4));
    pond
      ..reset()
      ..addRRect(r);
    dullWater.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFB9C6C1), Color(0xFF9AABA5), Color(0xFF85968F)],
    ).createShader(Offset.zero & s);
    aliveWater.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFCBE5DA), Color(0xFF8CC3B6), Color(0xFF4E9C91)],
    ).createShader(Offset.zero & s);
    rim.strokeWidth = math.max(1, cw * 0.03);
    ripple.strokeWidth = math.max(1, cw * 0.035);
    rayBlocked.strokeWidth = cw * 0.06;
    hint.strokeWidth = cw * 0.07;
    glow.strokeWidth = cw * 0.05;
    hintDotEdge.strokeWidth = math.max(1, cw * 0.025);
    hintArrow
      ..reset()
      ..moveTo(cw * 0.22, 0)
      ..lineTo(-cw * 0.12, -cw * 0.17)
      ..lineTo(-cw * 0.04, 0)
      ..lineTo(-cw * 0.12, cw * 0.17)
      ..close();
    final rng = math.Random(7);
    sparkles
      ..clear()
      ..addAll(List.generate(
          14,
          (_) =>
              Offset(rng.nextDouble() * s.width, rng.nextDouble() * s.height)));
  }
}

class BoardPainter extends CustomPainter {
  final GameSession session;
  final BoardFx fx;
  final BoardArtCache cache;
  final bool highContrast;

  BoardPainter({
    required this.session,
    required this.fx,
    required this.cache,
    required Listenable repaint,
    this.highContrast = false,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final board = session.board;
    final n = board.size;
    final L = BoardLayout(n, size.width);
    final cw = L.cw;
    final k = cw / 100; // pond-art unit scale
    cache.ensure(size, cw);
    final mask = session.mask;
    final now = fx.nowUs;
    final frogs = board.level.frogs;
    final golden = board.goldenIndex;
    final gFrog = frogs[golden];
    final gCenter = L.padCenter(gFrog.x, gFrog.y);

    // --- finale clock
    final finale = fx.finaleScheduled;
    final ft = finale ? now - fx.finaleStartUs : -1;
    final maxDist =
        math.sqrt(size.width * size.width + size.height * size.height);
    double washR;
    if (fx.alive) {
      washR = double.infinity;
    } else if (finale && ft >= fx.washStartUs) {
      final w = ((ft - fx.washStartUs) / kWashUs).clamp(0.0, 1.0);
      washR = Curves.easeOutCubic.transform(w) * maxDist;
    } else {
      washR = -1;
    }

    // --- water
    canvas.drawPath(cache.pond, cache.dullWater);
    if (washR > 0) {
      canvas.save();
      if (washR.isFinite) {
        cache.washClip
          ..reset()
          ..addOval(Rect.fromCircle(center: gCenter, radius: washR));
        canvas.clipPath(cache.washClip);
      }
      canvas.drawPath(cache.pond, cache.aliveWater);
      for (final s in cache.sparkles) {
        canvas.drawCircle(s, cw * 0.025, cache.sparkle);
      }
      canvas.restore();
    }
    canvas.drawPath(cache.pond, cache.rim);

    bool aliveAt(Offset c) =>
        washR.isInfinite || (washR > 0 && (c - gCenter).distance <= washR);

    // --- pads (and blooms on empty pads once alive)
    final bloomBase = fx.washStartUs + 150000;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final cx = L.px(x.toDouble()), cy = L.py(y.toDouble());
        final c = y * n + x;
        final alive = aliveAt(Offset(cx, cy));
        canvas.save();
        canvas.translate(cx, cy);
        canvas.scale(k, k);
        PondArt.pad(canvas, alive: alive);
        if (board.level.padAt(x, y) == PadType.rotator) {
          PondArt.rotatorRing(canvas, alive: true);
          final pt = now - fx.pulseStartUs;
          if (pt < kPulseUs) {
            final ph = (pt % 800000) / 800000;
            canvas.scale(1 + ph * 0.25, 1 + ph * 0.25);
            PondArt.rotatorRing(canvas, alive: true);
          }
        }
        canvas.restore();
        // Bloom on empty pads after the wash passes.
        final f = board.frogAtCell[c];
        final occupied =
            board.snakeAtCell[c] || (f >= 0 && _onPad(f, mask, finale, ft));
        if (!occupied && (fx.alive || (finale && ft > bloomBase))) {
          final d = (Offset(cx, cy) - gCenter).distance / maxDist;
          final open = fx.alive
              ? 1.0
              : ((ft - bloomBase - d * 700000) / kBloomUs).clamp(0.0, 1.0);
          if (open > 0) {
            canvas.save();
            canvas.translate(cx, cy + cw * 0.02);
            canvas.scale(k * 0.42, k * 0.42);
            PondArt.lotus(canvas,
                open: Curves.easeOutBack.transform(open),
                deep: (x + y) % 3 == 0);
            canvas.restore();
          }
        }
      }
    }

    // --- ripples where frogs pushed off
    for (final j in fx.jumps) {
      final rt = (now - j.startUs) / (kJumpUs + kRippleUs);
      if (rt >= 1) continue;
      final fr = frogs[j.frog];
      cache.ripple.color =
          Color.fromARGB(((1 - rt) * 200).round(), 255, 255, 255);
      canvas.save();
      canvas.translate(L.px(fr.x.toDouble()), L.py(fr.y.toDouble()));
      canvas.scale(1, 0.55);
      canvas.drawCircle(Offset.zero, cw * (0.35 + 0.45 * rt), cache.ripple);
      canvas.restore();
    }

    // --- long-press ray preview and hint ring (on the water, under sprites)
    final pf = fx.previewFrog;
    if (pf >= 0 && board.isPresent(mask, pf)) {
      var blocked = false;
      for (final c in board.rayCells(pf, board.facingOf(mask, pf))) {
        final o = board.frogAtCell[c];
        final occupied =
            board.snakeAtCell[c] || (o >= 0 && board.isPresent(mask, o));
        canvas.save();
        canvas.translate(L.px((c % n).toDouble()), L.py((c ~/ n).toDouble()));
        canvas.scale(1, 0.55);
        if (occupied) {
          blocked = true;
          canvas.drawCircle(Offset.zero, cw * 0.5, cache.rayBlocked);
        } else {
          canvas.drawCircle(Offset.zero, cw * (blocked ? 0.07 : 0.1),
              blocked ? cache.rayBlocked : cache.rayDot);
        }
        canvas.restore();
      }
    }

    // --- sprites, back row to front row
    final turnT = ((now - fx.turnStartUs) / kTurnUs).clamp(0.0, 1.0);
    final spriteW = cw * 0.64;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final c = y * n + x;
        final cx = L.px(x.toDouble()), cy = L.py(y.toDouble());
        if (board.snakeAtCell[c]) {
          var dx = 0.0;
          if (c == fx.flashSnakeCell && now - fx.flashStartUs < kFlashUs) {
            final t = (now - fx.flashStartUs) / kFlashUs;
            dx = math.sin(t * math.pi * 4) * (1 - t) * cw * 0.04;
          }
          canvas.save();
          canvas.translate(cx + dx, cy + cw * 0.04);
          Sprites.snake(canvas, spriteW * 1.05);
          canvas.restore();
          continue;
        }
        final f = board.frogAtCell[c];
        if (f < 0 || f == golden && finale) continue;
        if (!_onPad(f, mask, finale, ft)) continue;
        var facing =
            finale ? board.facingAtCount(f, 0) : board.facingOf(mask, f);
        var squash = 1.0;
        if (!finale && board.onRotator[f] && turnT < 1) {
          if (turnT < 0.5) {
            facing = facing.rotated(-fx.turnDir);
            squash = math.max(0.06, 1 - turnT * 2);
          } else {
            squash = math.max(0.06, turnT * 2 - 1);
          }
        }
        var ox = 0.0;
        final st = now - fx.shakeStartUs[f];
        if (st < kShakeUs) {
          final t = st / kShakeUs;
          ox = math.sin(t * math.pi * 6) * (1 - t) * cw * 0.08;
        }
        var scale = 1.0;
        if (f == fx.flashFrog && now - fx.flashStartUs < kFlashUs) {
          scale =
              1 + math.sin((now - fx.flashStartUs) / kFlashUs * math.pi) * 0.12;
        }
        canvas.save();
        canvas.translate(cx + ox, cy + cw * 0.06);
        Sprites.frog(
            canvas, facing, spriteW * scale * (frogs[f].golden ? 1.08 : 1),
            golden: frogs[f].golden, squashX: squash);
        canvas.restore();
      }
    }

    // --- frogs in flight: hopping home, and Jin Chan's leap
    for (final j in fx.jumps) {
      final t = (now - j.startUs) / kJumpUs;
      if (t >= 1) continue;
      final fr = frogs[j.frog];
      _flight(
          canvas,
          L,
          fr.x.toDouble(),
          fr.y.toDouble(),
          j.facing,
          j.distanceCells,
          Curves.easeIn.transform(t.clamp(0.0, 1.0)),
          t,
          spriteW,
          fr.golden);
    }
    if (finale && ft >= 0) {
      final gt = (ft - fx.phaseBUs) / kGoldenLeapUs;
      if (gt > 0) {
        final facing = board.facingAtCount(golden, 0);
        if (gt < 1) {
          // Jin Chan appears, crouches, then leaps high toward its home.
          final lift = gt < 0.25 ? 0.0 : (gt - 0.25) / 0.75;
          _flight(
              canvas,
              L,
              gFrog.x.toDouble(),
              gFrog.y.toDouble(),
              facing,
              board.rayCells(golden, facing).length + 1.0,
              Curves.easeIn.transform(lift),
              lift,
              spriteW * 1.08,
              true,
              arc: 0.9);
          if (gt < 0.6) {
            cache.glow.color =
                Color.fromARGB(((0.6 - gt) / 0.6 * 220).round(), 242, 207, 99);
            canvas.save();
            canvas.translate(gCenter.dx, gCenter.dy);
            canvas.scale(1, 0.55);
            canvas.drawCircle(Offset.zero, cw * (0.4 + gt * 1.4), cache.glow);
            canvas.restore();
          }
        }
      }
    }

    // --- direction badges (always on top so they are never hidden)
    if (!finale) {
      for (var f = 0; f < board.frogCount; f++) {
        if (!board.isPresent(mask, f)) continue;
        final fr = frogs[f];
        canvas.save();
        canvas.translate(
            L.px(fr.x.toDouble()) + cw * 0.3, L.py(fr.y.toDouble()) + cw * 0.1);
        canvas.scale(k, k);
        PondArt.badge(canvas, board.facingOf(mask, f),
            golden: fr.golden, highContrast: highContrast);
        canvas.restore();
      }
    }

    // --- hint: dim the pond, then show the frog to tap, glowing, with a
    // dotted path along the way it will hop home.
    final hf = fx.hintFrog;
    if (!finale && hf >= 0 && board.isPresent(mask, hf)) {
      final fr = frogs[hf];
      final facing = board.facingOf(mask, hf);
      final t = ((now - fx.hintStartUs) % 1200000) / 1200000;
      final pulse = math.sin(t * 2 * math.pi);
      final fadeIn = ((now - fx.hintStartUs) / 250000).clamp(0.0, 1.0);
      cache.hintVeil.color =
          Color.fromARGB((122 * fadeIn).round(), 0x1B, 0x2B, 0x27);
      canvas.drawPath(cache.pond, cache.hintVeil);
      final center = L.padCenter(fr.x, fr.y);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, 0.55);
      canvas.drawCircle(
          Offset.zero, cw * (0.62 + 0.06 * pulse), cache.hintFill);
      canvas.drawCircle(Offset.zero, cw * (0.62 + 0.06 * pulse), cache.hint);
      canvas.restore();
      // Path: from just in front of the frog to one cell past the edge.
      final dist = board.rayCells(hf, facing).length + 1.0;
      final march = t * 0.5; // dots drift forward
      for (var d = 0.7 + march; d < dist + 0.2; d += 0.5) {
        final p =
            Offset(L.px(fr.x + facing.dx * d), L.py(fr.y + facing.dy * d));
        canvas.drawCircle(p, cw * 0.08, cache.hintDot);
        canvas.drawCircle(p, cw * 0.08, cache.hintDotEdge);
      }
      final tip = Offset(L.px(fr.x + facing.dx * (dist + 0.5)),
          L.py(fr.y + facing.dy * (dist + 0.5)));
      canvas.save();
      canvas.translate(tip.dx, tip.dy);
      canvas.rotate(math.atan2(facing.dy.toDouble(), facing.dx.toDouble()));
      canvas.drawPath(cache.hintArrow, cache.hintDot);
      canvas.drawPath(cache.hintArrow, cache.hintDotEdge);
      canvas.restore();
      // The frog itself, on top of the veil, with a gentle bounce.
      canvas.save();
      canvas.translate(
          center.dx, center.dy + cw * 0.06 - (pulse.abs()) * cw * 0.06);
      Sprites.frog(canvas, facing,
          spriteW * (fr.golden ? 1.08 : 1) * (1.06 + 0.04 * pulse),
          golden: fr.golden);
      canvas.restore();
      canvas.save();
      canvas.translate(
          L.px(fr.x.toDouble()) + cw * 0.3, L.py(fr.y.toDouble()) + cw * 0.1);
      canvas.scale(k, k);
      PondArt.badge(canvas, facing,
          golden: fr.golden, highContrast: highContrast);
      canvas.restore();
    }
  }

  /// Whether frog [f] stands on its pad right now.
  bool _onPad(int f, int mask, bool finale, int ft) =>
      session.board.isPresent(mask, f);

  void _flight(
      Canvas canvas,
      BoardLayout L,
      double gx,
      double gy,
      Facing facing,
      double dist,
      double e,
      double t,
      double spriteW,
      bool golden,
      {double arc = 0.45}) {
    final cw = L.cw;
    final x = L.px(gx + facing.dx * dist * e);
    final groundY = L.py(gy + facing.dy * dist * e);
    final hop = math.sin(t.clamp(0.0, 1.0) * math.pi);
    final shrink = 1 - 0.35 * e;
    canvas.save();
    canvas.translate(x, groundY + cw * 0.06);
    canvas.scale(1, 0.4);
    canvas.drawCircle(Offset.zero, spriteW * 0.42 * shrink, cache.flightShadow);
    canvas.restore();
    canvas.save();
    canvas.translate(x, groundY + cw * 0.06 - hop * cw * arc);
    Sprites.frog(canvas, facing, spriteW * shrink * (1 + hop * 0.15),
        golden: golden, shadow: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.session != session ||
      old.fx != fx ||
      old.highContrast != highContrast;
}
