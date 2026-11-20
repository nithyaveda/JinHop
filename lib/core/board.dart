// Board = a Level compiled for fast play, plus the rules engine.
// PURE DART.
//
// A board STATE is a single int bitmask: bit f is set while frog f is still
// on the board. Every valid tap removes exactly one frog, so
//   validTapCount = frogCount - bitCount(mask)
// which means the rotator phase (validTapCount mod 4) is fully determined by
// the mask. The solver's state key (frog set, validTapCount mod 4) therefore
// collapses to the mask alone.

import 'models.dart';

class Board {
  final Level level;
  final int size;
  final int frogCount;
  final int goldenIndex;

  /// Mask with every frog present (the starting state).
  final int fullMask;

  /// Frog index by cell, -1 when empty.
  final List<int> frogAtCell;
  final List<bool> snakeAtCell;
  final List<bool> onRotator;

  // Precomputed rays, indexed [frog * 4 + facing.index].
  final List<int> _rayFrogMask;
  final List<bool> _raySnake;
  final List<List<int>> _rayCells;

  Board._(
    this.level,
    this.size,
    this.frogCount,
    this.goldenIndex,
    this.fullMask,
    this.frogAtCell,
    this.snakeAtCell,
    this.onRotator,
    this._rayFrogMask,
    this._raySnake,
    this._rayCells,
  );

  factory Board(Level level) {
    final size = level.size;
    final n = level.frogs.length;
    if (n > kMaxFrogs) {
      throw ArgumentError('Too many frogs ($n > $kMaxFrogs)');
    }
    final golden = level.goldenIndex;
    if (golden < 0) throw ArgumentError('Level ${level.id} has no golden frog');

    final frogAt = List<int>.filled(size * size, -1);
    final snakeAt = List<bool>.filled(size * size, false);
    for (var f = 0; f < n; f++) {
      final fr = level.frogs[f];
      if (!level.inBounds(fr.x, fr.y)) {
        throw ArgumentError('Frog $f out of bounds');
      }
      final c = level.cellIndex(fr.x, fr.y);
      if (frogAt[c] != -1) {
        throw ArgumentError('Two frogs on cell (${fr.x},${fr.y})');
      }
      frogAt[c] = f;
    }
    for (final s in level.snakes) {
      if (!level.inBounds(s.x, s.y)) throw ArgumentError('Snake out of bounds');
      final c = level.cellIndex(s.x, s.y);
      if (frogAt[c] != -1 || snakeAt[c]) {
        throw ArgumentError('Snake overlaps at (${s.x},${s.y})');
      }
      snakeAt[c] = true;
    }
    final onRot = List<bool>.generate(
        n,
        (f) =>
            level.padAt(level.frogs[f].x, level.frogs[f].y) == PadType.rotator);

    final rayMask = List<int>.filled(n * 4, 0);
    final raySnake = List<bool>.filled(n * 4, false);
    final rayCells = List<List<int>>.filled(n * 4, const []);
    for (var f = 0; f < n; f++) {
      final fr = level.frogs[f];
      for (final d in Facing.values) {
        var x = fr.x + d.dx, y = fr.y + d.dy;
        var m = 0;
        var snake = false;
        final cells = <int>[];
        while (level.inBounds(x, y)) {
          final c = level.cellIndex(x, y);
          cells.add(c);
          final o = frogAt[c];
          if (o >= 0) m |= 1 << o;
          if (snakeAt[c]) snake = true;
          x += d.dx;
          y += d.dy;
        }
        rayMask[f * 4 + d.index] = m;
        raySnake[f * 4 + d.index] = snake;
        rayCells[f * 4 + d.index] = List.unmodifiable(cells);
      }
    }
    final full = n == 0 ? 0 : (1 << n) - 1;
    return Board._(
        level,
        size,
        n,
        golden,
        full,
        List.unmodifiable(frogAt),
        List.unmodifiable(snakeAt),
        List.unmodifiable(onRot),
        rayMask,
        raySnake,
        rayCells);
  }

  bool isPresent(int mask, int f) => (mask >> f) & 1 == 1;

  /// Valid taps made so far in this state.
  int validTapCount(int mask) => frogCount - bitCount(mask);

  /// Rotator orientation rule: baseFacing + (validTapCount mod 4) clockwise.
  Facing facingAtCount(int f, int validTapCount) {
    final base = level.frogs[f].facing;
    return onRotator[f] ? base.rotated(validTapCount % 4) : base;
  }

  Facing facingOf(int mask, int f) => facingAtCount(f, validTapCount(mask));

  /// Ray rule: a frog may jump only if no frog or snake lies between it and
  /// the board edge in its current facing.
  bool canTap(int mask, int f) {
    if (!isPresent(mask, f)) return false;
    final d = facingOf(mask, f).index;
    final k = f * 4 + d;
    return !_raySnake[k] && (_rayFrogMask[k] & mask) == 0;
  }

  /// Applies a tap. Returns the new mask, or null if the tap is blocked.
  int? resolveTap(int mask, int f) =>
      canTap(mask, f) ? (mask & ~(1 << f)) : null;

  bool isWon(int mask) => !isPresent(mask, goldenIndex);

  List<int> tappableFrogs(int mask) => [
        for (var f = 0; f < frogCount; f++)
          if (canTap(mask, f)) f
      ];

  // ---- Raw ray data for the solver and UI (ray preview on long-press). ----

  int rayFrogMask(int f, Facing d) => _rayFrogMask[f * 4 + d.index];
  bool raySnake(int f, Facing d) => _raySnake[f * 4 + d.index];

  /// Cells (y*size+x) from the frog to the edge in direction [d].
  List<int> rayCells(int f, Facing d) => _rayCells[f * 4 + d.index];

  /// First blocking frog index or -1, in the frog's current facing.
  /// Snakes block too; returns -2 when the first blocker is a snake.
  int firstBlocker(int mask, int f) {
    final cells = rayCells(f, facingOf(mask, f));
    for (final c in cells) {
      if (snakeAtCell[c]) return -2;
      final o = frogAtCell[c];
      if (o >= 0 && isPresent(mask, o)) return o;
    }
    return -1;
  }
}
