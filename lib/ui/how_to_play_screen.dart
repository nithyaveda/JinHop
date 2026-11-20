// How to Play: 5 cards. Every demo board is a real Level run through the real
// GameSession, BoardController, BoardView and BudgetMeter, so the guide can
// never drift from the build. tool/render_board_preview_test.dart exports
// these cards as PNGs for the written user guide.

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/core.dart';
import 'board_controller.dart';
import 'board_view.dart';
import 'budget_meter.dart';
import 'palette.dart';

/// One scripted action in a demo loop.
class DemoStep {
  final void Function(BoardController c) run;
  final int ms; // pause after this step
  const DemoStep(this.run, this.ms);
}

DemoStep tapStep(int frog, [int ms = 1100]) =>
    DemoStep((c) => c.tapFrog(frog), ms);
DemoStep hintStep([int ms = 1500]) => DemoStep((c) {
      if (c.session.hintsLeft <= 0) c.grantHint(); // the demo loops forever
      c.showHint();
    }, ms);
DemoStep previewStep(int frog, [int ms = 1500]) =>
    DemoStep((c) => c.setPreview(frog), ms);
DemoStep waitStep(int ms) => DemoStep((_) {}, ms);

class HowToCard {
  final String title;
  final String body;
  final List<String> rows;
  final int par;
  final int slack;
  final List<DemoStep> script;
  final bool showMeter;
  const HowToCard(this.title, this.body, this.rows, this.script,
      {this.par = 2, this.slack = 3, this.showMeter = false});
}

/// The five cards. Frog indices are row-major (see levelFromRows).
final howToCards = <HowToCard>[
  HowToCard(
    'Send frogs home',
    'Tap a frog and it hops the way its arrow points, but only if nothing is in its path. '
        'A blocked frog just shakes, and that costs nothing.',
    const ['. . . .', 'E . N .', '. . . .', '. . . n'],
    // 0: E frog (blocked by 1), 1: N frog (free), 2: golden (idle)
    [
      previewStep(0),
      DemoStep((c) => c.setPreview(-1), 200),
      tapStep(0),
      tapStep(1),
      tapStep(0),
      waitStep(900)
    ],
  ),
  HowToCard(
    'Free the golden frog',
    'The golden Jin Chan follows the same rule. Clear its path, then tap it to win.',
    const ['. . . .', '. e . S', '. . . .', '. . . .'],
    // 0: golden E (blocked by 1), 1: S frog (free)
    [tapStep(0), tapStep(1), tapStep(0, 1800)],
  ),
  HowToCard(
    'Turning pads',
    'Gold-ringed pads are the pond\'s currents. After every hop, a frog on one turns a quarter '
        'turn clockwise. A stuck frog may be free a hop or two later.',
    const ['. S . n', '. . . .', '. Nr . .', '. . . E'],
    // 0: S frog, 1: golden, 2: rotator frog (N, blocked by 0), 3: free frog
    [tapStep(2), tapStep(3, 1400), tapStep(2), tapStep(0), waitStep(900)],
  ),
  HowToCard(
    'Hops and the clock',
    'Every hop uses a petal, and hops can\'t be taken back. Finish within the Hops number for '
        'three stars. Blocked taps are free. From level 6 a clock counts down, and restart is always free.',
    const ['. . . .', '. e . S', '. . . .', 'E . . .'],
    // 0: golden, 1: S frog (free), 2: E frog (free decoy)
    [tapStep(2), tapStep(1), tapStep(0, 1800)],
    showMeter: true,
  ),
  HowToCard(
    'Hints and coins',
    'Stuck? Hint dims the pond and lights up a good next frog, with a trail showing where it will hop. '
        'You get 2 hints per level. Earn gold coins to buy more.',
    const ['. . . .', 'e . N .', '. . . .', '. W . .'],
    // 0: golden E, 1: N frog (free, blocks golden), 2: W frog (free decoy)
    [hintStep(2000), tapStep(1), tapStep(0, 1800)],
    showMeter: true,
  ),
];

class HowToPlayScreen extends StatefulWidget {
  /// Start page (tests / user-guide export).
  final int initialPage;

  /// When false the demos stay on their first frame (for still exports).
  final bool animate;
  const HowToPlayScreen({super.key, this.initialPage = 0, this.animate = true});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  late final PageController _pages =
      PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == howToCards.length - 1;
    return Scaffold(
      backgroundColor: Jin.cream,
      appBar: AppBar(
          backgroundColor: Jin.cream,
          foregroundColor: Jin.jadeDeep,
          title: const Text('How to play')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                key: const Key('howto_pages'),
                controller: _pages,
                itemCount: howToCards.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, i) =>
                    HowToCardView(card: howToCards[i], animate: widget.animate),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < howToCards.length; i++)
                  Container(
                    width: i == _page ? 22 : 9,
                    height: 9,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: i == _page ? Jin.jade : Jin.ink.withAlpha(50),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const Key('howto_next'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Jin.jade, foregroundColor: Jin.cream),
                  onPressed: () {
                    if (last) {
                      Navigator.of(context).maybePop();
                    } else {
                      _pages.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut);
                    }
                  },
                  child: Text(last ? 'Back to the pond' : 'Next',
                      style: const TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HowToCardView extends StatefulWidget {
  final HowToCard card;
  final bool animate;
  const HowToCardView({super.key, required this.card, this.animate = true});
  @override
  State<HowToCardView> createState() => _HowToCardViewState();
}

class _HowToCardViewState extends State<HowToCardView> {
  late final BoardController _c = BoardController(levelFromRows(
      widget.card.rows,
      par: widget.card.par,
      budgetSlack: widget.card.slack));
  Timer? _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _schedule(900);
  }

  void _schedule(int ms) {
    _timer = Timer(Duration(milliseconds: ms), _next);
  }

  void _next() {
    if (!mounted) return;
    final script = widget.card.script;
    if (_step >= script.length) {
      _step = 0;
      _c.setPreview(-1);
      _c.restart();
      _schedule(900);
      return;
    }
    final s = script[_step++];
    s.run(_c);
    _schedule(s.ms);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highContrast =
        AppScope.maybeOf(context)?.storage.colorblindArrows ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          Text(widget.card.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Jin.ink, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(widget.card.body,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Jin.ink, fontSize: 17, height: 1.4)),
          const SizedBox(height: 16),
          if (widget.card.showMeter)
            ListenableBuilder(
              listenable: _c,
              builder: (context, _) => BudgetMeter(
                par: _c.session.par,
                used: _c.session.budgetUsed,
                cap: _c.session.cap,
                minRemaining: _c.session.minRemaining,
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: IgnorePointer(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: BoardView(controller: _c, highContrast: highContrast),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
