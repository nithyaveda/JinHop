// Glue between the pure-Dart GameSession and the board animations.
// Owns the animation clock state (driven by BoardView's ticker) and emits
// GameEvents that audio/haptics/analytics will subscribe to in later stages.

import 'package:flutter/foundation.dart';

import '../core/core.dart';
import 'board_painter.dart';

enum GameEventType {
  hop,
  blocked,
  won,
  failed,
  restart,
  hint,
  restless,
  finaleDone,
  timeUp
}

class GameEvent {
  final GameEventType type;
  final int frog;
  const GameEvent(this.type, [this.frog = -1]);
}

class BoardController extends ChangeNotifier {
  GameSession _session;
  BoardFx _fx;

  /// Bumped every animation frame; the painter repaints on it (no rebuilds).
  final ValueNotifier<int> frame = ValueNotifier<int>(0);

  /// Set by BoardView: starts its ticker if it is idle.
  VoidCallback? wake;

  final List<void Function(GameEvent)> _listeners = [];

  BoardController(Level level)
      : _session = GameSession(level),
        _fx = BoardFx(level.frogs.length);

  GameSession get session => _session;
  BoardFx get fx => _fx;
  Board get board => _session.board;

  void addEventListener(void Function(GameEvent) l) => _listeners.add(l);
  void removeEventListener(void Function(GameEvent) l) => _listeners.remove(l);

  void _emit(GameEvent e) {
    for (final l in List.of(_listeners)) {
      l(e);
    }
  }

  /// Swap to a new level (fresh session and effects).
  void load(Level level) {
    _session = GameSession(level);
    _fx = BoardFx(level.frogs.length);
    notifyListeners();
  }

  bool get _hasRotatorFrogs {
    for (var f = 0; f < board.frogCount; f++) {
      if (board.onRotator[f] && board.isPresent(session.mask, f)) return true;
    }
    return false;
  }

  TapOutcome tapFrog(int f) {
    if (f < 0 || f >= board.frogCount || !board.isPresent(session.mask, f)) {
      return TapOutcome.ignored;
    }
    final facing = session.facingOf(f);
    final distance = board.rayCells(f, facing).length + 1.0;
    final blocker = board.firstBlocker(session.mask, f);
    final wasRestless = session.status == SessionStatus.restless;
    final out = session.tap(f);
    final now = _fx.nowUs;
    switch (out) {
      case TapOutcome.blocked:
        _fx.shakeStartUs[f] = now;
        _fx.flashFrog = -1;
        _fx.flashSnakeCell = -1;
        if (blocker >= 0) {
          _fx.flashFrog = blocker;
        } else if (blocker == -2) {
          for (final c in board.rayCells(f, facing)) {
            if (board.snakeAtCell[c]) {
              _fx.flashSnakeCell = c;
              break;
            }
          }
        }
        _fx.flashStartUs = now;
        _emit(GameEvent(GameEventType.blocked, f));
      case TapOutcome.removed:
      case TapOutcome.won:
        _fx.hintFrog = -1;
        if (_hasRotatorFrogs) {
          _fx.turnStartUs = now;
          _fx.turnDir = 1;
        }
        if (out == TapOutcome.won) {
          // Finale: Jin Chan's golden leap (it IS the winning hop), then the
          // colour wash and the bloom. No replay of earlier moves.
          _fx.finaleStartUs = now;
          _fx.finaleScheduled = true;
          _fx.finaleNotified = false;
          _fx.previewFrog = -1;
        } else {
          _fx.jumps.add(JumpFx(f, facing, now, distance));
        }
        _emit(GameEvent(
            out == TapOutcome.won ? GameEventType.won : GameEventType.hop, f));
        if (!wasRestless && session.status == SessionStatus.restless) {
          _emit(const GameEvent(GameEventType.restless));
        }
      case TapOutcome.failed:
        _emit(GameEvent(GameEventType.failed, f));
      case TapOutcome.ignored:
        break;
    }
    wake?.call();
    notifyListeners();
    return out;
  }

  void restart() {
    session.restart();
    final now = _fx.nowUs;
    _fx = BoardFx(board.frogCount)..nowUs = now;
    _emit(const GameEvent(GameEventType.restart));
    wake?.call();
    notifyListeners();
  }

  /// Spends a hint (if any are left) and highlights the frog to tap.
  int? showHint() {
    if (_fx.hintFrog >= 0 && session.isFrogPresent(_fx.hintFrog)) {
      return _fx.hintFrog; // already showing
    }
    final h = session.hint();
    _fx.hintFrog = h ?? -1;
    _fx.hintStartUs = _fx.nowUs;
    if (h != null) _emit(GameEvent(GameEventType.hint, h));
    wake?.call();
    notifyListeners();
    return h;
  }

  /// Whether a hint is on screen right now.
  bool get hintShowing =>
      _fx.hintFrog >= 0 && session.isFrogPresent(_fx.hintFrog);

  /// Adds one hint (bought with coins).
  void grantHint() {
    session.grantHint();
    notifyListeners();
  }

  /// Advances the level countdown by [ms]. Emits [GameEventType.timeUp]
  /// when it runs out. Only notifies listeners when the shown second changes.
  void tick(int ms) {
    final before = session.timeLeftMs;
    if (before == null) return;
    final failed = session.tick(ms);
    if (failed) {
      _fx.hintFrog = -1;
      _emit(const GameEvent(GameEventType.timeUp));
      notifyListeners();
      return;
    }
    if ((before + 999) ~/ 1000 != (session.timeLeftMs! + 999) ~/ 1000) {
      notifyListeners();
    }
  }

  bool get finaleRunning => _fx.finaleScheduled && !_fx.finaleNotified;

  /// Milliseconds since the finale started (negative before it starts).
  int get finaleElapsedMs =>
      _fx.finaleScheduled ? (_fx.nowUs - _fx.finaleStartUs) ~/ 1000 : -1;

  /// Jump to the end of the finale (pond alive, lotuses open).
  void skipFinale() {
    if (!finaleRunning) return;
    _fx.jumps.clear();
    _fx.finaleStartUs = _fx.nowUs - _fx.finaleDurationUs;
    wake?.call();
  }

  /// Called by BoardView when the finale has played out.
  void finaleFinished() {
    _fx.alive = true;
    _emit(const GameEvent(GameEventType.finaleDone));
    notifyListeners();
  }

  /// One-time gentle pulse on rotator pads (rotator intro level).
  void pulseRotators() {
    _fx.pulseStartUs = _fx.nowUs;
    wake?.call();
  }

  void setPreview(int f) {
    if (_fx.previewFrog == f) return;
    _fx.previewFrog = f;
    frame.value++;
  }

  @override
  void dispose() {
    frame.dispose();
    super.dispose();
  }
}
