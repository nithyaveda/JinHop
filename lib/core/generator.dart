// Seeded level generator. PURE DART.
//
// Levels are built in REVERSE removal order:
//   1. Place the golden frog (removed last, at step m).
//   2. For t = m-1 down to 1, place frog X ON THE RAY of an already placed
//      chain frog Y (so Y depends on X), with a facing whose ray is clear of
//      every frog already placed at the phase X will be tapped in
//      ((t-1) mod 4 on a rotator).
//   3. Decoys and snakes go only on cells no chain ray needs.
// Every chain frog only ever depends on frogs removed BEFORE it, so the
// dependency graph is acyclic by construction and the intended order is a
// valid solution: no deadlock is possible from the starting position.
// The solver then measures the real par and the validator applies the
// acceptance rules.

import 'board.dart';
import 'level_validator.dart';
import 'models.dart';
import 'rng.dart';
import 'solver.dart';

class GeneratorConfig {
  final int size;
  final int frogCount;
  final int chainLength; // intended solution length including the golden tap
  final int rotatorCount;
  final int snakeCount;
  final int minPar;
  final double minDecoyRatio;

  /// Require the solver's shortest path to tap at least one frog that has
  /// been turned by a rotator.
  final bool requireRotatorOnChain;

  /// Probability that a decoy is placed facing into another frog (looks stuck).
  final double blockedDecoyBias;
  final int maxSolverNodes;
  final int maxAttempts;

  const GeneratorConfig({
    this.size = 6,
    this.frogCount = 12,
    this.chainLength = 6,
    this.rotatorCount = 0,
    this.snakeCount = 0,
    this.minPar = LevelRules.minPar,
    this.minDecoyRatio = LevelRules.minDecoyRatio,
    this.requireRotatorOnChain = false,
    this.blockedDecoyBias = 0.6,
    this.maxSolverNodes = 60000,
    this.maxAttempts = 4000,
  });
}

class GeneratedLevel {
  final Level level;

  /// The constructed solution (frog indices in tap order, ends with golden).
  final List<int> intendedOrder;
  final int attempts;
  final int solverNodes;
  const GeneratedLevel(
      this.level, this.intendedOrder, this.attempts, this.solverNodes);
}

class _P {
  final int x, y;
  final Facing base;
  final Facing eff; // effective facing at its intended tap step
  final int step; // 1-based removal step; 0 for decoys
  final bool golden;
  _P(this.x, this.y, this.base, this.eff, this.step, {this.golden = false});
}

typedef _Built = ({List<_P> frogs, List<int> rotators, List<int> snakes});

class LevelGenerator {
  const LevelGenerator();

  GeneratedLevel? generate(
    GeneratorConfig cfg, {
    required int seed,
    int id = 0,
    int world = 1,
    int budgetSlack = kDefaultBudgetSlack,
  }) {
    final rng = Rng(seed);
    for (var attempt = 1; attempt <= cfg.maxAttempts; attempt++) {
      final built = _attempt(cfg, rng);
      if (built == null) continue;
      final frogsP = built.frogs;
      // Stable row-major frog order for readable JSON.
      frogsP.sort((a, b) => a.y != b.y ? a.y - b.y : a.x - b.x);
      final rotCells = built.rotators;
      final level = Level(
        id: id,
        world: world,
        size: cfg.size,
        frogs: [
          for (final p in frogsP) Frog(p.x, p.y, p.base, golden: p.golden)
        ],
        pads: [
          for (final c in rotCells)
            Pad(c % cfg.size, c ~/ cfg.size, PadType.rotator)
        ],
        snakes: [
          for (final c in built.snakes) Snake(c % cfg.size, c ~/ cfg.size)
        ],
        par: 0,
        budgetSlack: budgetSlack,
        seed: seed,
      );
      final board = Board(level);
      final order = <int>[];
      final chainSorted = [
        for (var i = 0; i < frogsP.length; i++)
          if (frogsP[i].step > 0) i
      ]..sort((a, b) => frogsP[a].step - frogsP[b].step);
      order.addAll(chainSorted);
      if (!replays(board, order)) {
        continue; // should not happen; treated as a rejected attempt
      }
      final solver = Solver(board, maxNodes: cfg.maxSolverNodes);
      final r = solver.solve(board.fullMask);
      if (!r.exact || r.distance == null) continue;
      final par = r.distance!;
      if (par < cfg.minPar) continue;
      if (level.frogs.length - par < cfg.minDecoyRatio * level.frogs.length) {
        continue;
      }
      if (cfg.requireRotatorOnChain) {
        final path = solver.solutionPath(board.fullMask)!;
        var turned = false;
        for (var i = 0; i < path.length; i++) {
          if (board.onRotator[path[i]] && i % 4 != 0) turned = true;
        }
        if (!turned) continue;
      }
      final finalLevel = level.copyWith(par: par);
      final v =
          LevelValidator.validate(finalLevel, maxNodes: cfg.maxSolverNodes);
      if (!v.ok) continue;
      return GeneratedLevel(finalLevel, order, attempt, solver.lastExpanded);
    }
    return null;
  }

  /// True if tapping [order] from the start is all valid and ends in a win.
  static bool replays(Board board, List<int> order) {
    var m = board.fullMask;
    for (final f in order) {
      final next = board.resolveTap(m, f);
      if (next == null) return false;
      m = next;
    }
    return board.isWon(m);
  }

  _Built? _attempt(GeneratorConfig cfg, Rng rng) {
    final n = cfg.size;
    final cells = n * n;
    final occ = List<int>.filled(cells, 0); // 0 empty, 1 frog, 2 snake
    final reserved = List<bool>.filled(cells, false);
    final isRot = List<bool>.filled(cells, false);

    final all = List<int>.generate(cells, (i) => i);
    rng.shuffle(all);
    final rot = all.take(cfg.rotatorCount).toList();
    for (final c in rot) {
      isRot[c] = true;
    }

    List<int> ray(int c, Facing d) {
      final out = <int>[];
      var x = c % n + d.dx, y = c ~/ n + d.dy;
      while (x >= 0 && y >= 0 && x < n && y < n) {
        out.add(y * n + x);
        x += d.dx;
        y += d.dy;
      }
      return out;
    }

    final placed = <_P>[];
    final m = cfg.chainLength;

    // 1. Golden frog: needs room for at least 2 blockers on its ray.
    {
      _P? g;
      for (var tries = 0; tries < 60 && g == null; tries++) {
        final c = rng.nextInt(cells);
        final eff = Facing.values[rng.nextInt(4)];
        if (ray(c, eff).length < 2) continue;
        final phase = (m - 1) % 4;
        final base = isRot[c] ? eff.rotated(-phase) : eff;
        g = _P(c % n, c ~/ n, base, eff, m, golden: true);
      }
      if (g == null) return null;
      placed.add(g);
      occ[g.y * n + g.x] = 1;
    }

    // 2. Chain frogs in reverse removal order.
    for (var t = m - 1; t >= 1; t--) {
      final phase = (t - 1) % 4;
      final targets = List<_P>.of(placed);
      rng.shuffle(targets);
      // Bias toward deepening the newest branch.
      if (rng.chance(0.55)) {
        targets.remove(placed.last);
        targets.insert(0, placed.last);
      }
      _P? x;
      for (final y in targets) {
        final empties = [
          for (final c in ray(y.y * n + y.x, y.eff))
            if (occ[c] == 0) c
        ];
        rng.shuffle(empties);
        for (final c in empties) {
          final dirs = List<Facing>.of(Facing.values);
          rng.shuffle(dirs);
          // Prefer short rays so decoys keep room.
          // Total order (ties keep shuffled position) so results never depend
          // on the sort algorithm: the daily puzzle must match on every device.
          final shuffled = List<Facing>.of(dirs);
          dirs.sort((a, b) {
            final d = ray(c, a).length - ray(c, b).length;
            return d != 0 ? d : shuffled.indexOf(a) - shuffled.indexOf(b);
          });
          if (rng.chance(0.35)) rng.shuffle(dirs);
          for (final eff in dirs) {
            final r = ray(c, eff);
            if (r.any((rc) => occ[rc] != 0)) continue;
            final base = isRot[c] ? eff.rotated(-phase) : eff;
            x = _P(c % n, c ~/ n, base, eff, t);
            break;
          }
          if (x != null) break;
        }
        if (x != null) break;
      }
      if (x == null) return null;
      placed.add(x);
      occ[x.y * n + x.x] = 1;
    }
    for (final p in placed) {
      for (final c in ray(p.y * n + p.x, p.eff)) {
        reserved[c] = true;
      }
    }

    // 3. Decoys.
    final decoyCount = cfg.frogCount - m;
    for (var i = 0; i < decoyCount; i++) {
      final free = [
        for (var c = 0; c < cells; c++)
          if (occ[c] == 0 && !reserved[c]) c
      ];
      if (free.isEmpty) return null;
      final c = rng.pick(free);
      final dirs = List<Facing>.of(Facing.values);
      rng.shuffle(dirs);
      Facing base = dirs.first;
      if (rng.chance(cfg.blockedDecoyBias)) {
        for (final d in dirs) {
          if (ray(c, d).any((rc) => occ[rc] == 1)) {
            base = d;
            break;
          }
        }
      }
      placed.add(_P(c % n, c ~/ n, base, base, 0));
      occ[c] = 1;
    }

    // 4. Snakes: prefer cells that sit on decoy rays.
    final snakes = <int>[];
    for (var i = 0; i < cfg.snakeCount; i++) {
      final free = [
        for (var c = 0; c < cells; c++)
          if (occ[c] == 0 && !reserved[c] && !isRot[c]) c
      ];
      if (free.isEmpty) return null;
      final onDecoyRay = <int>{};
      for (final p in placed) {
        if (p.step != 0) continue;
        for (final d in Facing.values) {
          onDecoyRay.addAll(ray(p.y * n + p.x, d));
        }
      }
      final preferred = free.where(onDecoyRay.contains).toList();
      final c = preferred.isNotEmpty && rng.chance(0.8)
          ? rng.pick(preferred)
          : rng.pick(free);
      snakes.add(c);
      occ[c] = 2;
    }

    return (frogs: placed, rotators: rot, snakes: snakes);
  }
}
