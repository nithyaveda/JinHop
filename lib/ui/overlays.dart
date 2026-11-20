import 'package:flutter/material.dart';

import '../core/game_session.dart' show FailReason;
import '../core/models.dart';
import 'art/pond.dart';
import 'art/sprites.dart';
import 'palette.dart';

const _calmText = TextStyle(color: Jin.ink, fontSize: 18, height: 1.35);

class JinButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  /// Optional leading icon (e.g. a home icon on the world-map buttons).
  final IconData? icon;
  const JinButton(this.label,
      {super.key, required this.onPressed, this.primary = true, this.icon});

  @override
  Widget build(BuildContext context) {
    final style = primary
        ? FilledButton.styleFrom(
            backgroundColor: Jin.jade,
            foregroundColor: Jin.cream,
            minimumSize: const Size(120, 52),
            textStyle: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w600))
        : OutlinedButton.styleFrom(
            foregroundColor: Jin.jadeDeep,
            side: const BorderSide(color: Jin.jade, width: 1.5),
            minimumSize: const Size(120, 52),
            textStyle: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w600));
    final i = icon;
    if (i != null) {
      return primary
          ? FilledButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(i, size: 22),
              label: Text(label))
          : OutlinedButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(i, size: 22),
              label: Text(label));
    }
    return primary
        ? FilledButton(style: style, onPressed: onPressed, child: Text(label))
        : OutlinedButton(
            style: style, onPressed: onPressed, child: Text(label));
  }
}

/// Soft, non-blocking nudge when the level can no longer be won in budget.
class RestlessBanner extends StatelessWidget {
  final VoidCallback onRestart;
  const RestlessBanner({super.key, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('restless'),
      color: Jin.cream,
      elevation: 3,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('The pond is restless. Begin again?', style: _calmText),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                JinButton('Restart',
                    key: const Key('restless_restart'), onPressed: onRestart),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the golden frog resting inside slow ripples (fail screen).
class _RestingPond extends StatefulWidget {
  const _RestingPond();
  @override
  State<_RestingPond> createState() => _RestingPondState();
}

class _RestingPondState extends State<_RestingPond>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 200, height: 170, child: CustomPaint(painter: _PondPainter(_a)));
}

/// The golden frog resting on a dull pad inside slow ripples (fail screen).
class _PondPainter extends CustomPainter {
  final Animation<double> t;
  _PondPainter(this.t) : super(repaint: t);

  static final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height * 0.72;
    for (var k = 0; k < 3; k++) {
      final p = (t.value + k / 3) % 1.0;
      _ring.color = Jin.jade.withAlpha(((1 - p) * 120).round());
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(1, 0.5);
      canvas.drawCircle(Offset.zero, size.width * (0.22 + 0.28 * p), _ring);
      canvas.restore();
    }
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(size.width / 100 * 0.9, size.width / 100 * 0.9);
    PondArt.pad(canvas, alive: false);
    canvas.restore();
    canvas.save();
    canvas.translate(cx, cy + 6);
    Sprites.frog(canvas, Facing.s, size.width * 0.62, golden: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PondPainter old) => false;
}

class FailOverlay extends StatelessWidget {
  final FailReason reason;
  final VoidCallback onTryAgain;
  final VoidCallback onHome;
  const FailOverlay(
      {super.key,
      this.reason = FailReason.hops,
      required this.onTryAgain,
      required this.onHome});

  @override
  Widget build(BuildContext context) {
    return _Veil(
      key: const Key('fail'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _RestingPond(),
          const SizedBox(height: 12),
          Text(reason == FailReason.time ? "Time's up!" : 'Out of hops!',
              key: const Key('fail_reason'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Jin.jadeDeep,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('The pond rests. Try again?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Jin.ink, fontSize: 22)),
          const SizedBox(height: 24),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                JinButton('World map',
                    key: const Key('fail_home'),
                    primary: false,
                    icon: Icons.home_rounded,
                    onPressed: onHome),
                JinButton('Try again',
                    key: const Key('fail_retry'), onPressed: onTryAgain),
              ]),
        ],
      ),
    );
  }
}

class StarsRow extends StatelessWidget {
  final int stars;
  final double size;
  const StarsRow(this.stars, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Semantics(
        label: '$stars of 3 stars',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: i < stars ? Jin.gold : Jin.ink.withAlpha(70)),
          ],
        ),
      );
}

class PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onMap;
  final VoidCallback onHowTo;
  final VoidCallback onSettings;
  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onMap,
    required this.onHowTo,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return _Veil(
      key: const Key('pause'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Paused',
              textAlign: TextAlign.center,
              style: TextStyle(color: Jin.ink, fontSize: 24)),
          const SizedBox(height: 20),
          JinButton('Resume',
              key: const Key('pause_resume'), onPressed: onResume),
          const SizedBox(height: 12),
          JinButton('Restart',
              key: const Key('pause_restart'),
              primary: false,
              onPressed: onRestart),
          const SizedBox(height: 12),
          JinButton('World map',
              key: const Key('pause_map'),
              primary: false,
              icon: Icons.home_rounded,
              onPressed: onMap),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: JinButton('How to play',
                    key: const Key('pause_howto'),
                    primary: false,
                    onPressed: onHowTo)),
            const SizedBox(width: 12),
            Expanded(
                child: JinButton('Settings',
                    key: const Key('pause_settings'),
                    primary: false,
                    onPressed: onSettings)),
          ]),
        ],
      ),
    );
  }
}

class _Veil extends StatelessWidget {
  final Widget child;
  const _Veil({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Jin.cream.withAlpha(232),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: child,
      ),
    );
  }
}
