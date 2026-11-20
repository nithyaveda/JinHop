// Story presentation: the illustrated intro before level 1 and the story
// cards between levels. Illustrations come from SceneArt (the game's own art).

import 'package:flutter/material.dart';

import '../core/story.dart';
import 'art/scenes.dart';
import 'palette.dart';

class _SceneView extends StatefulWidget {
  final String scene;
  const _SceneView(this.scene);
  @override
  State<_SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<_SceneView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: SceneArt.w / SceneArt.h,
        child: AnimatedBuilder(
          animation: _a,
          builder: (_, __) =>
              CustomPaint(painter: _ScenePainter(widget.scene, _a.value)),
        ),
      );
}

class _ScenePainter extends CustomPainter {
  final String scene;
  final double t;
  _ScenePainter(this.scene, this.t);
  @override
  void paint(Canvas canvas, Size size) => SceneArt.draw(canvas, size, scene, t);
  @override
  bool shouldRepaint(_ScenePainter old) => old.t != t || old.scene != scene;
}

class _CardBody extends StatelessWidget {
  final StoryCard card;
  const _CardBody(this.card);
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Jin.gold, width: 3),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 16,
                    offset: Offset(0, 6))
              ],
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: _SceneView(card.scene)),
          ),
          const SizedBox(height: 22),
          Text(card.text,
              key: const Key('story_text'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Jin.cream, fontSize: 20, height: 1.45)),
        ],
      );
}

/// A story card between levels: soft fade over the board, tap to continue.
class StoryOverlay extends StatefulWidget {
  final StoryCard card;
  final VoidCallback onDismiss;
  const StoryOverlay({super.key, required this.card, required this.onDismiss});
  @override
  State<StoryOverlay> createState() => _StoryOverlayState();
}

class _StoryOverlayState extends State<StoryOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..forward();

  @override
  void didUpdateWidget(StoryOverlay old) {
    super.didUpdateWidget(old);
    if (old.card.key != widget.card.key) _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        key: const Key('story'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_fade.value > 0.6) widget.onDismiss();
        },
        child: Container(
          color: Jin.jadeDeep,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CardBody(widget.card),
                const SizedBox(height: 28),
                Text('Tap to continue',
                    style: TextStyle(
                        color: Jin.cream.withAlpha(170), fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Illustrated prologue shown once, before level 1. Skippable.
class IntroScreen extends StatefulWidget {
  final List<StoryCard> cards;
  final VoidCallback onDone;
  const IntroScreen({super.key, required this.cards, required this.onDone});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page >= widget.cards.length - 1;
    return Scaffold(
      backgroundColor: Jin.jadeDeep,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('intro_skip'),
                onPressed: widget.onDone,
                style: TextButton.styleFrom(
                    foregroundColor: Jin.cream,
                    minimumSize: const Size(64, 48)),
                child: const Text('Skip',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 17)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.cards.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (_, i) => Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: _CardBody(widget.cards[i]),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.cards.length; i++)
                  Container(
                    width: i == _page ? 22 : 9,
                    height: 9,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: i == _page ? Jin.gold : Jin.cream.withAlpha(90),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  key: const Key('intro_next'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Jin.gold, foregroundColor: Jin.ink),
                  onPressed: () {
                    if (last) {
                      widget.onDone();
                    } else {
                      _pages.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut);
                    }
                  },
                  child: Text(last ? 'Begin' : 'Next',
                      style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 19,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
