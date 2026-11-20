import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palette.dart';

/// The lotus's patience: one petal per tap in the budget. Petals fade as
/// they are spent. Gold markers sit after petal [par] (3 stars) and
/// [par] + 2 (2 stars); the row ends at the cap. Colour moves softly from
/// jade to amber as the spare buffer shrinks, never red.
class BudgetMeter extends StatelessWidget {
  final int par;
  final int used;

  /// Null = no cap (tutorial levels).
  final int? cap;

  /// Solver's minimum taps still needed (null = unwinnable).
  final int? minRemaining;

  const BudgetMeter(
      {super.key,
      required this.par,
      required this.used,
      required this.cap,
      this.minRemaining});

  int get petals => cap ?? par + 2;

  /// 1 = plenty of spare taps, 0 = none to spare.
  double get calm {
    final c = cap;
    if (c == null) return 1;
    final need = minRemaining ?? (c - used + 1);
    final spare = (c - used) - need;
    final slack = math.max(1, c - par);
    return (spare / slack).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: cap == null
          ? 'Hops used $used. Three stars within $par hops.'
          : 'Petals left ${math.max(0, cap! - used)} of $cap. Three stars within $par hops.',
      child: SizedBox(
        height: 34,
        width: double.infinity,
        child: CustomPaint(painter: _MeterPainter(this)),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  final BudgetMeter m;
  _MeterPainter(this.m);

  static final Paint _fill = Paint();
  static final Paint _spent = Paint()
    ..color = Jin.ink.withAlpha(40)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  static final Paint _marker = Paint()
    ..color = Jin.gold
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round;
  static final Paint _star = Paint()..color = Jin.gold;

  @override
  void paint(Canvas canvas, Size size) {
    final n = m.petals;
    final step = math.min(24.0, size.width / n);
    final w = step * n;
    final left = (size.width - w) / 2;
    final cy = size.height * 0.62;
    final petal = _petal(step * 0.42, size.height * 0.36);
    _fill.color = Color.lerp(Jin.amber, Jin.jade, m.calm)!;

    for (var i = 0; i < n; i++) {
      canvas.save();
      canvas.translate(left + step * (i + 0.5), cy);
      if (i < m.used) {
        canvas.drawPath(petal, _spent);
      } else {
        canvas.drawPath(petal, _fill);
      }
      canvas.restore();
    }
    void marker(int afterPetal, int stars) {
      if (afterPetal <= 0 || afterPetal > n) return;
      final x = left + step * afterPetal;
      canvas.drawLine(Offset(x, cy - size.height * 0.3),
          Offset(x, cy + size.height * 0.3), _marker);
      final star = _starPath(3.6);
      for (var s = 0; s < stars; s++) {
        canvas.save();
        canvas.translate(x + (s - (stars - 1) / 2) * 8, 5);
        canvas.drawPath(star, _star);
        canvas.restore();
      }
    }

    marker(m.par, 3);
    marker(m.par + 2, 2);
    if (m.cap != null) marker(n, 1);
  }

  static Path _petal(double halfW, double h) => Path()
    ..moveTo(0, -h)
    ..quadraticBezierTo(halfW * 1.25, -h * 0.2, 0, h * 0.9)
    ..quadraticBezierTo(-halfW * 1.25, -h * 0.2, 0, -h)
    ..close();

  static Path _starPath(double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      if (i == 0) {
        p.moveTo(math.cos(a) * rr, math.sin(a) * rr);
      } else {
        p.lineTo(math.cos(a) * rr, math.sin(a) * rr);
      }
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.m.used != m.used ||
      old.m.cap != m.cap ||
      old.m.par != m.par ||
      old.m.minRemaining != m.minRemaining;
}
