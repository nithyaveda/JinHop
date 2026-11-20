// World ending: a full-screen illustrated story card of the world's landmark
// that comes alive while the player watches. The scene starts grey and misty;
// colour washes in, the mist lifts, lanterns light one by one, the moon
// brightens and lotuses bloom. Then the title and one short line fade in.
//
// ~6.5 s. Tap to skip to the end after 1 s; tap again (once the text is
// shown) to continue.

import 'package:flutter/material.dart';

import '../core/story.dart';
import 'art/landmark_scene.dart';
import 'art/map_art.dart';
import 'palette.dart';

/// Timeline (fractions of [WorldRevivalOverlay.duration]).
const double _kAliveFrom = 0.08, _kAliveTo = 0.72, _kTextAt = 0.76;

class WorldRevivalOverlay extends StatefulWidget {
  final WorldInfo world;

  /// Kept for callers; the card no longer draws the map.
  final List<MapNode> nodes;

  /// The ending card (its scene picks the landmark, its text is shown last).
  final StoryCard card;
  final VoidCallback onDismiss;

  static const duration = Duration(milliseconds: 6500);

  const WorldRevivalOverlay(
      {super.key, required this.world, required this.nodes, required this.card, required this.onDismiss});

  @override
  State<WorldRevivalOverlay> createState() => _WorldRevivalOverlayState();
}

class _WorldRevivalOverlayState extends State<WorldRevivalOverlay> with TickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: WorldRevivalOverlay.duration)
    ..forward();
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _a.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _tap() {
    if (_a.value >= _kTextAt + 0.04) {
      widget.onDismiss();
    } else if (_a.value * WorldRevivalOverlay.duration.inMilliseconds >= 1000) {
      _a.value = _kTextAt; // skip to the alive scene with its text
      _a.forward();
    }
  }

  String get _landmark {
    final s = widget.card.scene;
    if (s == 'moon_bridge' || s == 'lantern_shrine') return s;
    return widget.world.id.isOdd ? 'moon_bridge' : 'lantern_shrine';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('revival'),
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: ColoredBox(
        color: const Color(0xFF14302A),
        child: AnimatedBuilder(
          animation: Listenable.merge([_a, _loop]),
          builder: (context, _) {
            final v = _a.value;
            final alive = Curves.easeInOut.transform(((v - _kAliveFrom) / (_kAliveTo - _kAliveFrom)).clamp(0.0, 1.0));
            final text = ((v - _kTextAt) / 0.12).clamp(0.0, 1.0);
            return Column(
              children: [
                Expanded(
                  flex: 7,
                  child: Stack(fit: StackFit.expand, children: [
                    RepaintBoundary(
                      child: CustomPaint(painter: _ScenePainter(_landmark, alive, _loop.value)),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 90,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x0014302A), Color(0xFF14302A)],
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  flex: 3,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          Opacity(
                            opacity: text,
                            child: Transform.translate(
                              offset: Offset(0, 16 * (1 - text)),
                              child: Column(children: [
                                Text('${widget.world.name} is alive!',
                                    key: const Key('revival_title'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Jin.goldLight, fontSize: 30, fontWeight: FontWeight.w800, height: 1.15)),
                                const SizedBox(height: 10),
                                Text(widget.card.text,
                                    key: const Key('story_text'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Jin.cream.withAlpha(225), fontSize: 18, height: 1.35)),
                              ]),
                            ),
                          ),
                          const Spacer(),
                          Text(text > 0.5 ? 'Tap to continue' : 'Tap to skip',
                              style: TextStyle(color: Jin.cream.withAlpha(150), fontSize: 15)),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final String landmark;
  final double alive;
  final double t;
  _ScenePainter(this.landmark, this.alive, this.t);

  @override
  void paint(Canvas canvas, Size size) => LandmarkScene.draw(canvas, size, landmark, alive, t);

  @override
  bool shouldRepaint(_ScenePainter old) => old.alive != alive || old.t != t || old.landmark != landmark;
}
