import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/core.dart';
import 'art/map_art.dart';
import 'art/pond.dart';
import 'coins.dart';
import 'how_to_play_screen.dart';
import 'palette.dart';
import 'routes.dart';
import 'settings_screen.dart';

/// 2.5D world map: one pond stretch per world (bottom = world 1), each ending
/// at its landmark. Finished levels bloom, the current level glows with a
/// bud, locked levels are grey pads.
class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});
  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  ScrollController? _scroll;
  bool _offered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_offered) return;
    _offered = true;
    final storage = AppScope.of(context).storage;
    final today = dayNumber(DateTime.now());
    if (storage.signIn.canClaim(today)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showSignInReward(context, storage, today);
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final st = scope.storage;
    final ids = scope.levels.ids;
    final worlds = scope.levels.story.worlds;
    final next = st.nextUnplayed(ids);
    final total = st.totalStars(ids);

    return Scaffold(
      backgroundColor: const Color(0xFF8C9B96),
      body: LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth;
        // Section heights, bottom (world 1) first.
        final layouts = [
          for (final w in worlds) MapSectionLayout(width, w.levelCount, w.id)
        ];
        if (_scroll == null) {
          var offset = 0.0;
          final target = next ?? ids.last;
          for (var i = 0; i < worlds.length; i++) {
            if (worlds[i].contains(target)) {
              final local = layouts[i].node(target - worlds[i].first);
              offset += layouts[i].height - local.dy - box.maxHeight / 2;
              break;
            }
            offset += layouts[i].height;
          }
          _scroll = ScrollController(initialScrollOffset: math.max(0, offset));
        }
        return Stack(
          children: [
            ListView.builder(
              key: const Key('map_scroll'),
              controller: _scroll,
              reverse: true,
              itemCount: worlds.length,
              itemBuilder: (context, i) => _WorldSection(
                world: worlds[i],
                layout: layouts[i],
                nodes: [
                  for (var id = worlds[i].first; id <= worlds[i].last; id++)
                    MapNode(
                      id,
                      st.record(id) != null
                          ? NodeState.done
                          : (st.isUnlocked(id, ids)
                              ? NodeState.current
                              : NodeState.locked),
                      st.record(id)?.stars ?? 0,
                    ),
                ],
              ),
            ),
            // Top HUD.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          heightFactor: 1,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              _Pill(
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: Jin.gold, size: 28),
                                      const SizedBox(width: 6),
                                      Text('$total / ${ids.length * 3}',
                                          key: const Key('total_stars'),
                                          style: const TextStyle(
                                              color: Jin.ink,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800)),
                                    ]),
                              ),
                              const SizedBox(width: 8),
                              CoinCounter(coins: st.coins),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (Navigator.of(context).canPop()) ...[
                        _RoundButton(
                          key: const Key('map_home'),
                          icon: Icons.home_rounded,
                          tooltip: 'Dashboard',
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),
                      ],
                      _RoundButton(
                        key: const Key('map_howto'),
                        icon: Icons.question_mark_rounded,
                        tooltip: 'How to play',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const HowToPlayScreen())),
                      ),
                      const SizedBox(width: 10),
                      _RoundButton(
                        key: const Key('map_settings'),
                        icon: Icons.settings_rounded,
                        tooltip: 'Settings',
                        onTap: () async {
                          await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const SettingsScreen()));
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom buttons.
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    _BigButton(
                      key: const Key('map_play'),
                      label: 'Play',
                      icon: Icons.play_arrow_rounded,
                      gold: false,
                      onTap: () => Navigator.of(context).pushReplacement(
                          fadeRoute(RouteName.level,
                              levelId: next ?? ids.last)),
                    ),
                    const Spacer(),
                    _BigButton(
                      key: const Key('map_daily'),
                      label: 'Daily',
                      icon: Icons.wb_sunny_rounded,
                      gold: true,
                      onTap: () => Navigator.of(context)
                          .pushReplacement(fadeRoute(RouteName.daily)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _WorldSection extends StatelessWidget {
  final WorldInfo world;
  final MapSectionLayout layout;
  final List<MapNode> nodes;
  const _WorldSection(
      {required this.world, required this.layout, required this.nodes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: layout.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: MapSectionPainter(
                  worldId: world.id,
                  worldName: world.name,
                  landmarkName: world.landmark,
                  nodes: nodes,
                ),
              ),
            ),
          ),
          for (var i = 0; i < nodes.length; i++) ...[
            if (nodes[i].state == NodeState.current)
              Positioned(
                left: layout.node(i).dx - 90,
                top: layout.node(i).dy - 130,
                width: 180,
                height: 180,
                child: const IgnorePointer(child: _CurrentNodeGlow()),
              ),
            if (nodes[i].state != NodeState.locked)
              Positioned(
                left: layout.node(i).dx - 52,
                top: layout.node(i).dy - 70,
                width: 104,
                height: 120,
                child: Semantics(
                  button: true,
                  label: 'Level ${nodes[i].levelId}, ${nodes[i].stars} stars',
                  child: GestureDetector(
                    key: Key('tile_${nodes[i].levelId}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pushReplacement(
                        fadeRoute(RouteName.level, levelId: nodes[i].levelId)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The current level: a warm glow with a bobbing lotus bud and sparkles.
class _CurrentNodeGlow extends StatefulWidget {
  const _CurrentNodeGlow();
  @override
  State<_CurrentNodeGlow> createState() => _CurrentNodeGlowState();
}

class _CurrentNodeGlowState extends State<_CurrentNodeGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _a,
      builder: (_, __) => CustomPaint(painter: _GlowPainter(_a.value)));
}

class _GlowPainter extends CustomPainter {
  final double t;
  _GlowPainter(this.t);
  static final _glow = Paint()
    ..color = const Color(0x99FFE9A0)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
  static final _spark = Paint()..color = const Color(0xFFFFF4C2);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height - 50);
    final pulse = 0.85 + 0.15 * math.sin(t * 2 * math.pi);
    canvas.drawOval(
        Rect.fromCenter(center: c, width: 170 * pulse, height: 100 * pulse),
        _glow);
    canvas.save();
    canvas.translate(c.dx, c.dy - 6 - 4 * math.sin(t * 2 * math.pi).abs());
    canvas.scale(1.3, 1.3);
    PondArt.bud(canvas, scale: 0.75);
    canvas.restore();
    for (var i = 0; i < 4; i++) {
      final a = t * 2 * math.pi + i * math.pi / 2;
      canvas.drawCircle(
          c + Offset(math.cos(a) * 60, -50 + math.sin(a) * 24), 3, _spark);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t;
}

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Jin.cream,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFC9A85A), width: 2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        child: child,
      );
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundButton(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Jin.jade,
          shape:
              const CircleBorder(side: BorderSide(color: Jin.cream, width: 3)),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(icon, color: Jin.cream, size: 28)),
          ),
        ),
      );
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool gold;
  final VoidCallback onTap;
  const _BigButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.gold,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: gold ? Jin.gold : Jin.jade,
            shape: const CircleBorder(
                side: BorderSide(color: Jin.cream, width: 4)),
            elevation: 6,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Icon(icon, color: Jin.cream, size: 44)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Jin.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Color(0x80000000), blurRadius: 4)])),
        ],
      );
}
