// Win celebration: Jin Chan bounces, stars pop in one by one with a rising
// chime, gold coins and lotus petals burst out, and the card itself is the
// share card (RepaintBoundary -> PNG -> share sheet; no network involved).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../core/models.dart';
import 'art/sprites.dart';
import 'coins.dart' show CoinIcon;
import 'palette.dart';

class CelebrationOverlay extends StatefulWidget {
  final String title;
  final String subtitle;
  final String levelLabel;
  final int stars;
  final int used;
  final int par;

  /// Gold coins earned by this win (0 = none, line hidden).
  final int coins;
  final int luckyStreak;
  final VoidCallback? onNext;
  final VoidCallback onReplay;
  final VoidCallback onMap;

  /// Called as each star lands (index 0..2), for the chime.
  final void Function(int index)? onStar;

  /// Called when the player shares (analytics hook).
  final VoidCallback? onShare;

  const CelebrationOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    required this.levelLabel,
    required this.stars,
    required this.used,
    required this.par,
    this.coins = 0,
    required this.luckyStreak,
    required this.onNext,
    required this.onReplay,
    required this.onMap,
    this.onStar,
    this.onShare,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..forward();
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();
  final GlobalKey _cardKey = GlobalKey();
  final List<bool> _chimed = [false, false, false];
  bool _sharing = false;

  static const _starAt = [0.28, 0.42, 0.56];

  @override
  void initState() {
    super.initState();
    _intro.addListener(() {
      for (var i = 0; i < 3; i++) {
        if (!_chimed[i] && i < widget.stars && _intro.value >= _starAt[i]) {
          _chimed[i] = true;
          widget.onStar?.call(i);
        }
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    _sharing = true;
    widget.onShare?.call();
    try {
      final rb =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (rb == null) return;
      final img = await rb.toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(bytes.buffer.asUint8List(),
              mimeType: 'image/png', name: 'jinhop.png')
        ],
        text: 'I brought the pond back to life in JinHop! ${widget.levelLabel} '
            '${'★' * widget.stars}${'☆' * (3 - widget.stars)}',
      ));
    } catch (e) {
      debugPrint('Share failed: $e');
    } finally {
      _sharing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('win'),
      // Solid: the board steps back so only the celebration shows.
      color: Jin.cream,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(_intro))),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(key: _cardKey, child: _card()),
                  const SizedBox(height: 22),
                  if (widget.onNext != null)
                    SizedBox(
                      width: 240,
                      height: 58,
                      child: FilledButton(
                        key: const Key('win_next'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Jin.jade,
                          foregroundColor: Jin.cream,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
                        ),
                        onPressed: widget.onNext,
                        child: const Text('Next',
                            style: TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundIcon(
                          key: const Key('win_map'), icon: Icons.home_rounded, tooltip: 'World map', onTap: widget.onMap),
                      const SizedBox(width: 18),
                      _RoundIcon(
                          key: const Key('win_replay'),
                          icon: Icons.replay_rounded,
                          tooltip: 'Replay',
                          onTap: widget.onReplay),
                      const SizedBox(width: 18),
                      _RoundIcon(key: const Key('win_share'), icon: Icons.share_rounded, tooltip: 'Share', onTap: _share),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The celebration itself; also the image that gets shared.
  Widget _card() {
    return Container(
      color: Jin.cream,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 170,
            width: 240,
            child: AnimatedBuilder(
              animation: _loop,
              builder: (_, __) => CustomPaint(painter: _JinChanBounce(_loop.value)),
            ),
          ),
          const SizedBox(height: 6),
          Text(widget.title,
              key: const Key('win_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Jin.jadeDeep, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _intro,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == 1 ? 10 : 0),
                    child: Transform.scale(
                      scale: i < widget.stars
                          ? Curves.elasticOut.transform(((_intro.value - _starAt[i]) / 0.3).clamp(0.0, 1.0))
                          : 1,
                      child: Icon(i < widget.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: i == 1 ? 68 : 56, color: i < widget.stars ? Jin.gold : Jin.ink.withAlpha(50)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('${widget.used} hops',
              key: const Key('win_used'), style: TextStyle(color: Jin.ink.withAlpha(140), fontSize: 15)),
          if (widget.coins > 0) ...[
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _intro,
              builder: (_, child) => Transform.scale(
                  scale: Curves.elasticOut.transform(((_intro.value - 0.66) / 0.3).clamp(0.0, 1.0)), child: child),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 18, 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF4C8), Color(0xFFF2C64E)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF8A5A0A), width: 2.5),
                  boxShadow: const [BoxShadow(color: Color(0x88FFD36B), blurRadius: 18, spreadRadius: 2)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const CoinIcon(size: 32),
                  const SizedBox(width: 8),
                  Text('+${widget.coins}',
                      key: const Key('win_coins'),
                      style: const TextStyle(color: Color(0xFF8A5A0A), fontSize: 28, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A round icon button for the secondary win actions.
class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundIcon({super.key, required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(side: BorderSide(color: Jin.jade, width: 2)),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 56, height: 56, child: Icon(icon, color: Jin.jadeDeep, size: 28)),
          ),
        ),
      );
}

class _JinChanBounce extends CustomPainter {
  final double t;
  _JinChanBounce(this.t);

  static final Paint _shadow = Paint()
    ..color = const Color(0x331E1E24)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  static final Paint _ray = Paint()..color = const Color(0x40F2CF63);
  static final Path _rayPath = Path()
    ..moveTo(0, 0)
    ..lineTo(-11, -110)
    ..lineTo(11, -110)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final hop = math.sin(t * math.pi).abs();
    final cx = size.width / 2, ground = size.height - 8;
    // soft sunburst
    canvas.save();
    canvas.translate(cx, ground - 66);
    canvas.rotate(t * math.pi / 6);
    for (var i = 0; i < 12; i++) {
      canvas.rotate(math.pi / 6);
      canvas.drawPath(_rayPath, _ray);
    }
    canvas.restore();
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, ground), width: 104 - hop * 24, height: 16),
        _shadow);
    canvas.save();
    canvas.translate(cx, ground - hop * 26);
    canvas.scale(
        1 + (1 - hop) * 0.05, 1 - (1 - hop) * 0.05); // squash on landing
    Sprites.frog(canvas, Facing.s, 132, golden: true, shadow: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_JinChanBounce old) => old.t != t;
}

/// Gold coins and lotus petals bursting from the centre, then drifting down.
class _ConfettiPainter extends CustomPainter {
  final Animation<double> a;
  _ConfettiPainter(this.a) : super(repaint: a);

  static final _rng = math.Random(11);
  static final List<List<double>> _bits = List.generate(
      46,
      (i) => [
            _rng.nextDouble() * 2 * math.pi, // direction
            0.35 + _rng.nextDouble() * 0.65, // speed
            _rng.nextDouble() * 2 * math.pi, // spin phase
            i % 3 == 0 ? 1 : 0, // 1 = coin, 0 = petal
            _rng.nextDouble(), // colour pick
          ]);
  static final Paint _coin = Paint()..color = const Color(0xFFE7B53C);
  static final Paint _coinEdge = Paint()
    ..color = const Color(0xFF8A5A0A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  static final Paint _hole = Paint()..color = const Color(0xFF8A5A0A);
  static final Paint _petalA = Paint()..color = const Color(0xFFF7B6C6);
  static final Paint _petalB = Paint()..color = const Color(0xFFEE6F92);
  static final Path _petal = Path()
    ..moveTo(0, -7)
    ..quadraticBezierTo(6, 0, 0, 7)
    ..quadraticBezierTo(-6, 0, 0, -7)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final t = a.value;
    if (t <= 0.05) return;
    final cx = size.width / 2, cy = size.height * 0.36;
    final reach = math.min(size.width, size.height) * 0.62;
    for (final b in _bits) {
      final p =
          Curves.easeOutCubic.transform(((t - 0.05) / 0.6).clamp(0.0, 1.0));
      final fall = math.max(0.0, t - 0.4) * size.height * 0.5;
      final x = cx + math.cos(b[0]) * reach * b[1] * p;
      final y = cy + math.sin(b[0]) * reach * b[1] * p * 0.8 + fall * b[1];
      final fade = t > 0.85 ? (1 - (t - 0.85) / 0.15) : 1.0;
      if (fade <= 0) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b[2] + t * 8 * b[1]);
      if (b[3] == 1) {
        canvas.scale(math.cos(b[2] + t * 10).abs() * 0.8 + 0.2, 1);
        canvas.drawCircle(Offset.zero, 7, _coin);
        canvas.drawCircle(Offset.zero, 7, _coinEdge);
        canvas.drawRect(const Rect.fromLTWH(-2, -2, 4, 4), _hole);
      } else {
        canvas.drawPath(_petal, b[4] > 0.5 ? _petalA : _petalB);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
