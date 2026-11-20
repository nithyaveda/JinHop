import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/core.dart';
import '../services/audio_service.dart';
import 'board_controller.dart';
import 'board_view.dart';
import 'budget_meter.dart';
import 'celebration.dart';
import 'coins.dart';
import 'how_to_play_screen.dart';
import 'overlays.dart';
import 'palette.dart';
import 'routes.dart';
import 'settings_screen.dart';
import 'story_screens.dart';
import 'world_revival.dart';
import 'art/map_art.dart' show MapNode, NodeState;

/// Play screen for a campaign level ([levelId]) or a ready-made level such
/// as today's daily pond ([level] with [daily] = true).
class GameScreen extends StatefulWidget {
  final int? levelId;
  final Level? level;
  final bool daily;
  const GameScreen({super.key, this.levelId, this.level, this.daily = false})
      : assert(levelId != null || level != null);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late Level _level;
  late BoardController _c;
  bool _ready = false;
  bool _paused = false;

  /// A dialog (buy hint, sign-in reward) is open: the clock waits.
  bool _dialog = false;
  bool _foreground = true;
  Timer? _clock;
  static const _clockStepMs = 250;

  /// Coins earned by this win (shown on the celebration card).
  int _coinsWon = 0;

  /// Winning tap made; the reverse-replay finale is playing.
  bool _finale = false;

  /// Finale over: story cards (if any) then the celebration.
  bool _won = false;
  int _winStars = 0;
  int _streak = 0;
  final List<StoryCard> _storyQueue = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final scope = AppScope.of(context);
    _level = widget.level ?? scope.levels.byId(widget.levelId!);
    _c = BoardController(_level)..addEventListener(_onEvent);
    final storage = scope.storage;
    WidgetsBinding.instance.addObserver(this);
    if (_c.session.isTimed) {
      _clock = Timer.periodic(
          const Duration(milliseconds: _clockStepMs), (_) => _onClock());
    }
    if (_level.rotatorIntro && !storage.seen('rotator_intro')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _c.pulseRotators();
        storage.markSeen('rotator_intro');
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _c.removeEventListener(_onEvent);
    _c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Leaving the app mid-level opens the pause menu, so the clock never runs
    // in the background and the player comes back to a calm screen.
    if (!_foreground && mounted && _clockRunning) {
      setState(() => _paused = true);
    }
  }

  bool get _clockRunning {
    final st = _c.session.status;
    return !_paused &&
        !_dialog &&
        _foreground &&
        !_won &&
        !_finale &&
        st != SessionStatus.won &&
        st != SessionStatus.failed &&
        !(ModalRoute.of(context)?.isCurrent == false);
  }

  void _onClock() {
    if (!mounted || !_clockRunning) return;
    _c.tick(_clockStepMs);
  }

  Future<void> _onHint() async {
    final s = _c.session;
    if (s.isFinished || _c.hintShowing) return;
    if (s.hintsLeft > 0) {
      _c.showHint();
      return;
    }
    final storage = AppScope.of(context).storage;
    setState(() => _dialog = true);
    final bought = await showBuyHint(context, storage);
    if (!mounted) return;
    setState(() => _dialog = false);
    if (bought && !_c.session.isFinished) {
      _c.grantHint();
      _c.showHint();
    }
  }

  Future<void> _onEvent(GameEvent e) async {
    final scope = AppScope.of(context);
    final audio = scope.audio;
    switch (e.type) {
      case GameEventType.hop:
        audio.play(Sfx.croak);
        audio.play(Sfx.splash);
        scope.haptics.validTap();
      case GameEventType.blocked:
        audio.play(Sfx.shake);
        scope.haptics.blockedTap();
      case GameEventType.won:
        audio.play(Sfx.croak, rate: 1.0);
        audio.play(Sfx.splash);
        scope.haptics.validTap();
        await _recordWin();
      case GameEventType.finaleDone:
        audio.play(Sfx.bloom);
        if (mounted) {
          setState(() {
            _finale = false;
            _won = true;
          });
        }
      case GameEventType.failed:
      case GameEventType.timeUp:
      case GameEventType.restart:
      case GameEventType.hint:
      case GameEventType.restless:
        break; // calm: no harsh sounds, ever
    }
  }

  Future<void> _recordWin() async {
    final scope = AppScope.of(context);
    final s = _c.session;
    final today = dayNumber(DateTime.now());
    final int coins;
    if (widget.daily) {
      coins = scope.storage.coinsForDaily(today);
      final streak =
          await scope.storage.saveDailyWin(today, s.stars, s.budgetUsed);
      _streak = streak.count;
    } else {
      coins = scope.storage.coinsForWin(_level.id, s.stars);
      await scope.storage.saveWin(_level.id, s.stars, s.budgetUsed);
      _streak = scope.storage.luckyStreak.currentOn(today);
    }
    await scope.storage.addCoins(coins);
    _coinsWon = coins;
    final cards = widget.daily
        ? const <StoryCard>[]
        : [
            for (final c in scope.levels.story.cardsAfter(_level.id))
              // The world-end revival plays every time a world is finished;
              // other story cards are shown once.
              if (c.key.endsWith('_end') ||
                  !scope.storage.seen('story_${c.key}'))
                c
          ];
    if (!mounted) return;
    setState(() {
      _finale = true;
      _winStars = s.stars;
      _storyQueue
        ..clear()
        ..addAll(cards);
    });
  }

  /// A world's ending card plays as the animated world revival; other cards
  /// are the usual illustrated story card.
  Widget _storyView(StoryCard card) {
    final scope = AppScope.of(context);
    final w = scope.levels.story.worldOf(_level.id);
    if (w != null && card.key == 'w${w.id}_end') {
      return WorldRevivalOverlay(
        key: ValueKey(card.key),
        world: w,
        card: card,
        nodes: [
          for (var id = w.first; id <= w.last; id++)
            MapNode(id, NodeState.done, scope.storage.record(id)?.stars ?? 0),
        ],
        onDismiss: _dismissStory,
      );
    }
    return StoryOverlay(card: card, onDismiss: _dismissStory);
  }

  void _dismissStory() {
    final k = _storyQueue.removeAt(0);
    AppScope.of(context).storage.markSeen('story_${k.key}');
    setState(() {});
  }

  void _restart() {
    setState(() {
      _paused = false;
      _coinsWon = 0;
      _won = false;
      _finale = false;
      _storyQueue.clear();
    });
    _c.restart();
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {}); // settings may have changed
  }

  void _goMap() =>
      Navigator.of(context).pushReplacement(fadeRoute(RouteName.map));

  void _goLevel(int id) => Navigator.of(context)
      .pushReplacement(fadeRoute(RouteName.level, levelId: id));

  String get _title => widget.daily ? 'Daily pond' : 'Level ${_level.id}';

  String get _subtitle {
    if (widget.daily) {
      final d = DateTime.now();
      return '${d.day}/${d.month}/${d.year}';
    }
    return AppScope.of(context).levels.story.worldName(_level.world);
  }

  (String, String) get _celebrationText {
    if (widget.daily) {
      return ('Daily pond complete!', 'Luck flows back into today\'s pond.');
    }
    final w = AppScope.of(context).levels.story.worldOf(_level.id);
    if (w != null && w.last == _level.id) {
      return ('${w.name} is alive!', 'The ${w.landmark} glows again.');
    }
    return ('Level ${_level.id} complete!', 'The pond comes back to life.');
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final next = widget.daily ? null : scope.levels.after(_level.id);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_storyQueue.isNotEmpty && _won) return;
        if (_finale) {
          _c.skipFinale();
        } else if (_won || _c.session.status == SessionStatus.failed) {
          _goMap();
        } else {
          setState(() => _paused = !_paused);
        }
      },
      child: Scaffold(
        backgroundColor: Jin.cream,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) {
              final s = _c.session;
              final (title, subtitle) = _celebrationText;
              return Stack(
                children: [
                  Column(
                    children: [
                      _TopBar(
                        title: _title,
                        subtitle: _subtitle,
                        session: s,
                        onPause: () => setState(() => _paused = true),
                        onHome: _goMap,
                      ),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: BoardView(
                              controller: _c,
                              highContrast: scope.storage.colorblindArrows,
                            ),
                          ),
                        ),
                      ),
                      _BottomBar(
                        hintsLeft: s.hintsLeft,
                        coins: scope.storage.coins,
                        onRestart: s.isFinished ? null : _restart,
                        onHint: s.isFinished ? null : _onHint,
                      ),
                    ],
                  ),
                  if (s.status == SessionStatus.restless && !_paused)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 96,
                      child: RestlessBanner(onRestart: _restart),
                    ),
                  if (s.status == SessionStatus.failed)
                    Positioned.fill(
                        child: FailOverlay(
                            reason: s.failReason ?? FailReason.hops,
                            onTryAgain: _restart,
                            onHome: _goMap)),
                  if (_finale)
                    Positioned.fill(
                      child: GestureDetector(
                        key: const Key('finale_skip'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_c.finaleElapsedMs >= 1000) _c.skipFinale();
                        },
                        child: const Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 92),
                            child: Text('Tap to skip',
                                style: TextStyle(
                                    color: Jin.jadeDeep, fontSize: 15)),
                          ),
                        ),
                      ),
                    ),
                  if (_won && _storyQueue.isEmpty)
                    Positioned.fill(
                      child: CelebrationOverlay(
                        title: title,
                        subtitle: subtitle,
                        levelLabel: _title,
                        stars: _winStars,
                        used: s.budgetUsed,
                        par: s.par,
                        coins: _coinsWon,
                        luckyStreak: _streak,
                        onStar: (i) =>
                            scope.audio.play(Sfx.bloom, rate: 1.0 + i * 0.12),
                        onNext: next == null ? null : () => _goLevel(next.id),
                        onReplay: _restart,
                        onMap: _goMap,
                      ),
                    ),
                  if (_paused &&
                      !_won &&
                      !_finale &&
                      s.status != SessionStatus.failed)
                    Positioned.fill(
                      child: PauseOverlay(
                        onResume: () => setState(() => _paused = false),
                        onRestart: _restart,
                        onMap: _goMap,
                        onHowTo: () => _push(const HowToPlayScreen()),
                        onSettings: () => _push(const SettingsScreen()),
                      ),
                    ),
                  if (_won && _storyQueue.isNotEmpty)
                    Positioned.fill(child: _storyView(_storyQueue.first)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final GameSession session;
  final VoidCallback onPause;
  final VoidCallback onHome;
  const _TopBar(
      {required this.title,
      required this.subtitle,
      required this.session,
      required this.onPause,
      required this.onHome});

  @override
  Widget build(BuildContext context) {
    final left = session.timeLeftMs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('pause'),
                tooltip: 'Pause',
                iconSize: 30,
                color: Jin.jadeDeep,
                onPressed: onPause,
                icon: const Icon(Icons.pause_circle_outline_rounded),
              ),
              IconButton(
                key: const Key('top_home'),
                tooltip: 'World map',
                iconSize: 30,
                color: Jin.jadeDeep,
                onPressed: onHome,
                icon: const Icon(Icons.home_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        key: const Key('level_title'),
                        style: const TextStyle(
                            color: Jin.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Jin.ink.withAlpha(160), fontSize: 14)),
                  ],
                ),
              ),
              if (left != null) ...[
                CountdownPill(msLeft: left),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Hops: ${session.par}',
                          key: const Key('hops_target'),
                          style: const TextStyle(
                              color: Jin.gold,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      Text('used ${session.budgetUsed}',
                          key: const Key('hops_used'),
                          style: TextStyle(
                              color: Jin.ink.withAlpha(160), fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 0, 0),
            child: BudgetMeter(
              par: session.par,
              used: session.budgetUsed,
              cap: session.hasCap ? session.cap : null,
              minRemaining: session.minRemaining,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seconds left as m:ss. Turns red for the last 15 seconds.
class CountdownPill extends StatelessWidget {
  final int msLeft;
  const CountdownPill({super.key, required this.msLeft});

  static const int warnSeconds = 15;

  @override
  Widget build(BuildContext context) {
    final secs = (msLeft + 999) ~/ 1000;
    final warn = secs <= warnSeconds;
    final text = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    final color = warn ? Jin.red : Jin.jadeDeep;
    return Semantics(
      label: '$secs seconds left',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
        decoration: BoxDecoration(
          color: warn ? const Color(0xFFFBE3E1) : Jin.jadeMist,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: color.withAlpha(warn ? 255 : 90), width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.timer_outlined, size: 20, color: color),
          const SizedBox(width: 4),
          Text(text,
              key: const Key('timer'),
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int hintsLeft;
  final int coins;
  final VoidCallback? onRestart;
  final VoidCallback? onHint;
  const _BottomBar(
      {required this.hintsLeft,
      required this.coins,
      required this.onRestart,
      required this.onHint});

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
        fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w600);
    final buy = hintsLeft <= 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(children: [
        Expanded(
          child: TextButton(
            key: const Key('restart'),
            onPressed: onRestart,
            style: TextButton.styleFrom(
                foregroundColor: Jin.jadeDeep,
                minimumSize: const Size(0, 56),
                textStyle: label),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.replay_rounded, size: 26),
                SizedBox(width: 6),
                Text('Restart'),
              ]),
            ),
          ),
        ),
        Expanded(
          child: TextButton(
            key: const Key('hint'),
            onPressed: onHint,
            style: TextButton.styleFrom(
                foregroundColor: Jin.jadeDeep,
                minimumSize: const Size(0, 56),
                textStyle: label),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 26),
                const SizedBox(width: 6),
                const Text('Hint'),
                const SizedBox(width: 6),
                if (!buy)
                  _Badge(
                      child: Text('$hintsLeft', key: const Key('hints_left')))
                else
                  const _Badge(
                    key: Key('hint_price'),
                    gold: true,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      CoinIcon(size: 15),
                      SizedBox(width: 3),
                      Text('$kHintPrice'),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
        CoinCounter(coins: coins),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;
  final bool gold;
  const _Badge({super.key, required this.child, this.gold = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: gold ? const Color(0xFFFFF1C2) : Jin.jade,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
              color: gold ? const Color(0xFF8A5A0A) : Jin.cream,
              fontSize: 14,
              fontWeight: FontWeight.w800),
          child: child,
        ),
      );
}
