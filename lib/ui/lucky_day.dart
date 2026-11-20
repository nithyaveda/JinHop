// Daily check-in: "Lucky day". The player taps the lucky coin to light
// today's lantern; the streak of lit lanterns is their luck. Coins are the
// sign-in reward for the day.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models.dart';
import 'art/pond.dart';
import 'art/sprites.dart';
import 'coins.dart' show CoinIcon;
import 'palette.dart';

class LuckyDayScreen extends StatefulWidget {
  /// Streak length after today's check-in (1 = first day).
  final int streak;

  /// Day of the 7-day lantern cycle lit today (1..7).
  final int cycleDay;

  /// Coins for today's check-in (the same every day).
  final int reward;

  /// Lanterns in one cycle.
  final int lanterns;

  /// Called when the coin is tapped (claim the reward here).
  final Future<void> Function() onClaim;

  /// Called when the player leaves the screen.
  final VoidCallback onDone;

  /// For previews: start already revealed.
  final bool revealed;

  const LuckyDayScreen({
    super.key,
    required this.streak,
    required this.cycleDay,
    required this.reward,
    this.lanterns = 7,
    required this.onClaim,
    required this.onDone,
    this.revealed = false,
  });

  @override
  State<LuckyDayScreen> createState() => _LuckyDayScreenState();
}

class _LuckyDayScreenState extends State<LuckyDayScreen> with TickerProviderStateMixin {
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  late final AnimationController _reveal =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600), value: widget.revealed ? 1 : 0);
  late bool _tapped = widget.revealed;

  @override
  void dispose() {
    _loop.dispose();
    _reveal.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_tapped) return;
    setState(() => _tapped = true);
    _reveal.forward();
    await widget.onClaim();
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.reward;
    return Material(
      key: const Key('lucky_day'),
      color: const Color(0xFF123F33),
      child: AnimatedBuilder(
        animation: Listenable.merge([_loop, _reveal]),
        builder: (context, _) {
          final r = _reveal.value;
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _SkyPainter(_loop.value, r))),
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _LanternRow(
                      cycleDay: widget.cycleDay,
                      lanterns: widget.lanterns,
                      todayLit: r > 0.25,
                      pulse: _loop.value,
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _tapped
                            ? Column(key: const ValueKey('after'), children: [
                                const Text('It’s your lucky day!',
                                    key: Key('lucky_title'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Jin.goldLight,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        shadows: [Shadow(color: Color(0x99000000), blurRadius: 8)])),
                                const SizedBox(height: 6),
                                Text('Lantern ${widget.cycleDay} is lit!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Jin.cream.withAlpha(220), fontSize: 16, height: 1.3)),
                              ])
                            : Column(key: const ValueKey('before'), children: [
                                const Text('A new day at the pond',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Jin.cream, fontSize: 28, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                Text('Tap the lucky coin to light today’s lantern.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Jin.cream.withAlpha(210), fontSize: 16)),
                              ]),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) => SizedBox(
                          width: box.maxWidth,
                          height: box.maxHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(child: CustomPaint(painter: _HeroPainter(_loop.value, r))),
                              if (_tapped)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 18,
                                  child: _RewardBurst(reward: reward, t: r, pulse: _loop.value),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!_tapped) ...[
                      GestureDetector(
                        key: const Key('lucky_coin'),
                        onTap: _tap,
                        child: SizedBox(
                          width: 150,
                          height: 150,
                          child: CustomPaint(painter: _BigCoinPainter(_loop.value)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('TAP FOR LUCK',
                          style: TextStyle(
                              color: Jin.goldLight, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      const SizedBox(height: 40),
                    ] else
                      Opacity(
                        opacity: ((r - 0.35) / 0.4).clamp(0.0, 1.0),
                        child: Column(children: [
                          _StreakBadge(streak: widget.streak),
                          const SizedBox(height: 12),
                          Text('Log in every day to keep\nyour lanterns lit and your luck growing!',
                              key: const Key('lucky_hint'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Jin.cream.withAlpha(215), fontSize: 15, height: 1.3)),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: 240,
                            height: 56,
                            child: FilledButton(
                              key: const Key('lucky_go'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Jin.gold,
                                foregroundColor: Jin.ink,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                              ),
                              onPressed: r >= 0.75 ? widget.onDone : null,
                              child: const Text('Let’s hop!',
                                  style: TextStyle(fontFamily: 'Nunito', fontSize: 20, fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Seven lanterns on a string: lit ones are the current streak in this cycle.
class _LanternRow extends StatelessWidget {
  final int cycleDay;
  final int lanterns;
  final bool todayLit;
  final double pulse;
  const _LanternRow({required this.cycleDay, required this.lanterns, required this.todayLit, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: CustomPaint(
        painter: _LanternPainter(cycleDay, todayLit, pulse),
        child: Row(
          children: [
            for (var d = 1; d <= lanterns; d++)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Day $d',
                        style: TextStyle(
                            color: d < cycleDay || (d == cycleDay && todayLit)
                                ? Jin.goldLight
                                : Jin.cream.withAlpha(120),
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanternPainter extends CustomPainter {
  final int cycleDay;
  final bool todayLit;
  final double pulse;
  _LanternPainter(this.cycleDay, this.todayLit, this.pulse);

  static final Paint _string = Paint()
    ..color = const Color(0xFF6B5134)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint _glow = Paint()
    ..color = const Color(0x88FFB347)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
  static final Paint _lit = Paint()..color = const Color(0xFFE0453A);
  static final Paint _litCore = Paint()..color = const Color(0xFFFFE08A);
  static final Paint _dark = Paint()..color = const Color(0xFF3C4F48);
  static final Paint _cap = Paint()..color = const Color(0xFFD9A422);
  static final Paint _rib = Paint()
    ..color = const Color(0x55000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  static final Path _stringPath = Path();
  static final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 7;
    final cw = size.width / n;
    _stringPath
      ..reset()
      ..moveTo(0, 8)
      ..quadraticBezierTo(size.width / 2, 34, size.width, 8);
    canvas.drawPath(_stringPath, _string);
    for (var i = 0; i < n; i++) {
      final day = i + 1;
      final x = cw * (i + 0.5);
      final t = (x / size.width);
      final sy = 8 + 4 * 26 * t * (1 - t) * 0.5 * 2; // on the string
      final cy = sy + 30;
      final lit = day < cycleDay || (day == cycleDay && todayLit);
      final today = day == cycleDay;
      canvas.drawLine(Offset(x, sy), Offset(x, cy - 16), _string);
      if (lit) {
        final s = today ? 1 + 0.12 * math.sin(pulse * 2 * math.pi) : 1.0;
        canvas.save();
        canvas.translate(x, cy);
        canvas.scale(s, s);
        canvas.drawCircle(Offset.zero, 24, _glow);
        canvas.restore();
      }
      final body = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, cy), width: 26, height: 30),
          const Radius.circular(11));
      canvas.drawRRect(body, lit ? _lit : _dark);
      canvas.drawLine(Offset(x - 6, cy - 13), Offset(x - 6, cy + 13), _rib);
      canvas.drawLine(Offset(x + 6, cy - 13), Offset(x + 6, cy + 13), _rib);
      if (lit) canvas.drawCircle(Offset(x, cy), 5, _litCore);
      canvas.drawRect(Rect.fromCenter(center: Offset(x, cy - 16), width: 14, height: 4), _cap);
      canvas.drawRect(Rect.fromCenter(center: Offset(x, cy + 16), width: 14, height: 4), _cap);
      if (today && !todayLit) {
        // Waiting to be lit: a soft gold ring.
        _ring.color =
            Color.fromARGB((120 + 100 * math.sin(pulse * 2 * math.pi)).round().clamp(0, 255), 242, 207, 99);
        canvas.drawRRect(body.inflate(4), _ring);
      }
    }
  }

  @override
  bool shouldRepaint(_LanternPainter old) =>
      old.pulse != pulse || old.todayLit != todayLit || old.cycleDay != cycleDay;
}

/// Background: night pond turning to a warm golden glow on reveal.
class _SkyPainter extends CustomPainter {
  final double t;
  final double reveal;
  _SkyPainter(this.t, this.reveal);

  static final Paint _bg = Paint();
  static final Paint _glow = Paint();
  static final Paint _star = Paint()..color = const Color(0xFFFFF4C2);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _bg.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(const Color(0xFF123F33), const Color(0xFF7A2E1E), reveal * 0.6)!,
        Color.lerp(const Color(0xFF0B2A22), const Color(0xFF2B1A0E), reveal * 0.5)!,
      ],
    ).createShader(rect);
    canvas.drawRect(rect, _bg);
    final c = Offset(size.width / 2, size.height * 0.5);
    _glow.shader = RadialGradient(colors: [
      Color.lerp(const Color(0x553FA083), const Color(0xCCFFD36B), reveal)!,
      const Color(0x00000000),
    ]).createShader(Rect.fromCircle(center: c, radius: size.width * 0.9));
    canvas.drawCircle(c, size.width * 0.9, _glow);
    final rng = math.Random(3);
    for (var i = 0; i < 40; i++) {
      final p = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      final a = (math.sin((t + i / 40) * 2 * math.pi) + 1) / 2;
      canvas.drawCircle(p, 0.8 + a * 1.6, _star);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t || old.reveal != reveal;
}

/// Jin Chan on his pad; on reveal a sunburst and a shower of coins.
class _HeroPainter extends CustomPainter {
  final double t;
  final double reveal;
  _HeroPainter(this.t, this.reveal);

  static final Paint _ray = Paint()..color = const Color(0x55FFE08A);
  static final Path _rayPath = Path()
    ..moveTo(0, 0)
    ..lineTo(-14, -230)
    ..lineTo(14, -230)
    ..close();
  static final Paint _coin = Paint()..color = const Color(0xFFF2C64E);
  static final Paint _coinEdge = Paint()
    ..color = const Color(0xFF8A5A0A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  static final Paint _hole = Paint()..color = const Color(0xFF8A5A0A);
  static final Paint _petal = Paint()..color = const Color(0xFFF7B6C6);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final ground = size.height * 0.86;
    final scale = math.min(size.width, size.height * 1.3) / 400;
    if (reveal > 0) {
      canvas.save();
      canvas.translate(cx, ground - 90 * scale);
      canvas.rotate(t * math.pi / 8);
      final a = Curves.easeOut.transform(reveal.clamp(0.0, 1.0));
      canvas.scale(a, a);
      for (var i = 0; i < 16; i++) {
        canvas.rotate(math.pi / 8);
        canvas.drawPath(_rayPath, _ray);
      }
      canvas.restore();
    }
    // Coins and petals bursting up then drifting down.
    if (reveal > 0.15) {
      final rng = math.Random(7);
      final p = ((reveal - 0.15) / 0.85).clamp(0.0, 1.0);
      for (var i = 0; i < 26; i++) {
        final dir = -math.pi / 2 + (rng.nextDouble() - 0.5) * 2.4;
        final speed = 0.5 + rng.nextDouble() * 0.5;
        final dist = size.width * 0.55 * speed * Curves.easeOutCubic.transform(p);
        final x = cx + math.cos(dir) * dist;
        final y = ground - 120 * scale + math.sin(dir) * dist + p * p * 120 + (t * 8 % 1) * 0;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(i + t * 6 * speed);
        if (i % 3 == 0) {
          canvas.drawOval(const Rect.fromLTWH(-4, -7, 8, 14), _petal);
        } else {
          canvas.scale(math.cos(i + t * 9).abs() * 0.8 + 0.2, 1);
          canvas.drawCircle(Offset.zero, 9, _coin);
          canvas.drawCircle(Offset.zero, 9, _coinEdge);
          canvas.drawRect(const Rect.fromLTWH(-2.5, -2.5, 5, 5), _hole);
        }
        canvas.restore();
      }
    }
    // Pad and Jin Chan.
    canvas.save();
    canvas.translate(cx, ground);
    canvas.scale(2.3 * scale, 2.3 * scale);
    PondArt.pad(canvas, alive: true);
    canvas.restore();
    final hop = reveal > 0 && reveal < 1 ? math.sin(reveal * math.pi * 3).abs() * (1 - reveal) * 40 : 0.0;
    canvas.save();
    canvas.translate(cx, ground + 6 * scale - hop * scale);
    Sprites.frog(canvas, Facing.s, 220 * scale, golden: true, shadow: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.t != t || old.reveal != reveal;
}

/// The big tappable lucky coin with a pulsing glow.
class _BigCoinPainter extends CustomPainter {
  final double t;
  _BigCoinPainter(this.t);

  static final Paint _glow = Paint()
    ..color = const Color(0xAAFFD36B)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
  static final Paint _rim = Paint()..color = const Color(0xFFB5841C);
  static final Paint _face = Paint()..color = const Color(0xFFF2C64E);
  static final Paint _ring = Paint()
    ..color = const Color(0xFFB5841C)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final Paint _edge = Paint()
    ..color = const Color(0xFF8A5A0A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;
  static final Paint _hole = Paint()..color = const Color(0xFF6E4708);
  static final Paint _shine = Paint()..color = const Color(0xCCFFF6CF);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = 1 + 0.06 * math.sin(t * 2 * math.pi);
    canvas.drawCircle(c, 62 * s, _glow);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(s, s);
    canvas.drawCircle(const Offset(0, 4), 52, _rim);
    canvas.drawCircle(Offset.zero, 52, _face);
    canvas.drawCircle(Offset.zero, 52, _edge);
    canvas.drawCircle(Offset.zero, 38, _ring);
    canvas.drawRect(const Rect.fromLTWH(-13, -13, 26, 26), _hole);
    canvas.drawCircle(const Offset(-24, -24), 7, _shine);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BigCoinPainter old) => old.t != t;
}

/// "4-day lucky streak" medallion.
class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});
  @override
  Widget build(BuildContext context) => Container(
        key: const Key('lucky_streak'),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFC0392B), Color(0xFF8E2A20)]),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Jin.goldLight, width: 2.5),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$streak',
              style: const TextStyle(color: Jin.goldLight, fontSize: 34, fontWeight: FontWeight.w800, height: 1)),
          const SizedBox(width: 10),
          Text(streak == 1 ? 'day lucky\nstreak begins' : 'day lucky\nstreak',
              style: const TextStyle(color: Jin.cream, fontSize: 15, fontWeight: FontWeight.w800, height: 1.1)),
        ]),
      );
}

/// Big "+5" coin reward that pops in above Jin Chan with a glow and sparkles.
class _RewardBurst extends StatelessWidget {
  final int reward;
  final double t; // reveal 0..1
  final double pulse;
  const _RewardBurst({required this.reward, required this.t, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final p = ((t - 0.3) / 0.45).clamp(0.0, 1.0);
    final scale = Curves.elasticOut.transform(p) * (1 + 0.04 * math.sin(pulse * 2 * math.pi));
    return Opacity(
      opacity: p == 0 ? 0 : 1,
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: Container(
            key: const Key('lucky_reward'),
            padding: const EdgeInsets.fromLTRB(14, 8, 24, 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF4C8), Color(0xFFF2C64E)],
              ),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0xFF8A5A0A), width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0xAAFFD36B), blurRadius: 30, spreadRadius: 6),
                BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 4)),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const CoinIcon(size: 46),
              const SizedBox(width: 10),
              Text('+$reward',
                  style: const TextStyle(
                      color: Color(0xFF8A5A0A), fontSize: 44, fontWeight: FontWeight.w800, height: 1)),
              const SizedBox(width: 8),
              const Text('coins',
                  style: TextStyle(color: Color(0xFF8A5A0A), fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }
}
