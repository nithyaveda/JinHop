// GameSession: one play-through of a level. PURE DART.
//
// Rules:
//   budgetUsed = hops made (valid taps). Blocked taps cost nothing. There is
//   no undo; restart is free and resets the board and the clock.
//   - A hop that would push budgetUsed to cap + 1 before winning fails the
//     level instead of being applied. Winning exactly at the cap is allowed.
//   - Timed levels fail when the countdown reaches zero ([tick]).
//   - Levels with budgetSlack >= 99 (tutorial L1-5) have no cap, no timer and
//     never fail.
//   - Stars depend on hops only, never on time.
//   - Hints: [kFreeHints] per level; extra ones are granted with [grantHint]
//     (bought with coins). Hints used survive a restart.

import 'board.dart';
import 'models.dart';
import 'solver.dart';

enum SessionStatus { playing, restless, won, failed }

/// Why a level failed.
enum FailReason { hops, time }

/// Free hints per level.
const int kFreeHints = 2;

/// Countdown for a level in seconds, or null for untimed (tutorial) levels.
/// World 1: 60 s, World 2 and the daily pond: 90 s.
int? timeLimitFor(Level level) {
  if (level.unlimitedBudget) return null;
  return level.world == 1 ? 60 : 90;
}

enum TapOutcome {
  /// Frog's ray is blocked. Shake + thud. Costs nothing.
  blocked,

  /// Frog hopped home.
  removed,

  /// Golden frog tapped: level won.
  won,

  /// This tap would have exceeded the budget: level failed.
  failed,

  /// Session already finished, or not a frog on the board.
  ignored,
}

/// Stars for a win: 3 if used <= par, 2 if used <= par + 2, else 1.
int starsFor(int budgetUsed, int par) {
  if (budgetUsed <= par) return 3;
  if (budgetUsed <= par + 2) return 2;
  return 1;
}

class GameSession {
  final Level level;
  final Board board;
  final Solver solver;

  int _mask;
  final List<int> _history = []; // net move stack (frog indices)
  int _validTaps = 0;
  SessionStatus _status = SessionStatus.playing;
  FailReason? _failReason;
  int? _lastMinRemaining;

  /// Countdown length in ms (null = untimed).
  final int? timeLimitMs;
  int _elapsedMs = 0;
  int _hintsUsed = 0;
  int _bonusHints = 0;

  factory GameSession(Level level,
      {Board? board,
      Solver? solver,
      int? timeLimitSeconds,
      bool timed = true}) {
    final b = solver?.board ?? board ?? Board(level);
    final secs = timed ? (timeLimitSeconds ?? timeLimitFor(level)) : null;
    return GameSession._(
        level, b, solver ?? Solver(b), secs == null ? null : secs * 1000);
  }

  GameSession._(this.level, this.board, this.solver, this.timeLimitMs)
      : _mask = board.fullMask {
    _refreshRestless();
  }

  // ---------------------------------------------------------------- state
  int get mask => _mask;
  SessionStatus get status => _status;
  bool get isFinished =>
      _status == SessionStatus.won || _status == SessionStatus.failed;
  int get par => level.par;
  bool get hasCap => !level.unlimitedBudget;

  /// Budget cap (par + slack). Meaningless when [hasCap] is false.
  int get cap => level.cap;

  /// Valid taps so far. Drives rotator orientation.
  int get validTapCount => _history.length;
  int get totalValidTaps => _validTaps;
  int get budgetUsed => _validTaps;
  FailReason? get failReason => _failReason;

  // ---------------------------------------------------------------- clock
  bool get isTimed => timeLimitMs != null;
  int get elapsedMs => _elapsedMs;

  /// Milliseconds left on the countdown (null = untimed).
  int? get timeLeftMs => timeLimitMs == null
      ? null
      : (timeLimitMs! - _elapsedMs).clamp(0, timeLimitMs!);

  /// Advances the countdown. Returns true if this made the level fail.
  bool tick(int ms) {
    if (!isTimed || isFinished || ms <= 0) return false;
    _elapsedMs += ms;
    if (_elapsedMs >= timeLimitMs!) {
      _elapsedMs = timeLimitMs!;
      _status = SessionStatus.failed;
      _failReason = FailReason.time;
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------- hints
  int get hintsUsed => _hintsUsed;
  int get hintsLeft => kFreeHints + _bonusHints - _hintsUsed;

  /// Adds one hint (bought with coins).
  void grantHint() => _bonusHints++;

  /// Taps left before failing; null when the level has no cap.
  int? get tapsLeft {
    if (!hasCap) return null;
    final left = cap - budgetUsed;
    return left < 0 ? 0 : left;
  }

  /// Last solver result after a tap (null = unwinnable).
  int? get minRemaining => _lastMinRemaining;

  int get stars => _status == SessionStatus.won ? starsFor(budgetUsed, par) : 0;

  bool isFrogPresent(int f) => board.isPresent(_mask, f);
  Facing facingOf(int f) => board.facingOf(_mask, f);
  bool canTap(int f) => board.canTap(_mask, f);

  /// Net move history (the final board-history stack), oldest first.
  List<int> get history => List.unmodifiable(_history);

  // -------------------------------------------------------------- actions
  TapOutcome tap(int f) {
    if (isFinished ||
        f < 0 ||
        f >= board.frogCount ||
        !board.isPresent(_mask, f)) {
      return TapOutcome.ignored;
    }
    if (!board.canTap(_mask, f)) return TapOutcome.blocked;
    if (hasCap && budgetUsed + 1 > cap) {
      _validTaps++; // budgetUsed is now exactly cap + 1
      _status = SessionStatus.failed;
      _failReason = FailReason.hops;
      return TapOutcome.failed;
    }
    _validTaps++;
    _mask &= ~(1 << f);
    _history.add(f);
    if (f == board.goldenIndex) {
      _status = SessionStatus.won;
      return TapOutcome.won;
    }
    _refreshRestless();
    return TapOutcome.removed;
  }

  /// Free and unlimited: resets the board and the clock (hints used stay
  /// used, so restarting is not a way to get more of them).
  void restart() {
    _mask = board.fullMask;
    _history.clear();
    _validTaps = 0;
    _elapsedMs = 0;
    _failReason = null;
    _status = SessionStatus.playing;
    _refreshRestless();
  }

  /// Next move on a shortest path from the current state, without spending
  /// a hint (null when finished or unwinnable).
  int? peekHint() => isFinished ? null : solver.hint(_mask);

  /// Spends one hint and returns the frog to tap. Returns null (and spends
  /// nothing) when no hints are left, the level is over, or it is unwinnable.
  int? hint() {
    if (hintsLeft <= 0) return null;
    final h = peekHint();
    if (h != null) _hintsUsed++;
    return h;
  }

  void _refreshRestless() {
    final min = solver.minRemaining(_mask);
    _lastMinRemaining = min;
    final bool restless;
    if (min == null) {
      restless = true;
    } else if (hasCap) {
      restless = min > cap - budgetUsed;
    } else {
      restless = false;
    }
    _status = restless ? SessionStatus.restless : SessionStatus.playing;
  }
}
