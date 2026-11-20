// Solver: shortest number of valid taps from a state to tapping the golden
// frog. PURE DART.
//
// Search: A* over board masks (equivalent to BFS distances, because every
// edge costs 1 and the heuristic is admissible and consistent), with a
// per-board cache keyed by mask. The state key is the mask alone; see
// board.dart for why the rotator phase is implied by it.
//
// Heuristic (lower bound): frogs that MUST be removed before the golden frog
// can leave. A frog with exactly one snake-free escape direction (every
// non-rotator frog, or a rotator frog boxed in by snakes) must have every frog
// on that ray removed first; we follow that closure from the golden frog.
// A frog with no snake-free direction, or a cycle in that "must clear first"
// graph, proves the state unwinnable.

import 'board.dart';
import 'models.dart';

class SolveResult {
  /// Minimum taps still needed to win (counting the golden tap), or null if
  /// the state can never be won.
  final int? distance;

  /// First move (frog index) on a shortest path, or null.
  final int? nextMove;

  /// False only when the node limit was hit; [distance] is then a lower bound.
  final bool exact;

  const SolveResult(this.distance, this.nextMove, this.exact);
}

class Solver {
  final Board board;

  /// Safety valve for pathological states. Curated levels are validated to
  /// solve far below this.
  final int maxNodes;

  final Map<int, int> _dist = {}; // mask -> distance, -1 = unwinnable
  final Map<int, int> _next = {}; // mask -> next move on a shortest path
  final Map<int, int> _h = {}; // mask -> heuristic, -1 = provably unwinnable

  /// Nodes expanded by the most recent uncached search (diagnostics/tests).
  int lastExpanded = 0;

  Solver(this.board, {this.maxNodes = 200000});

  int? minRemaining(int mask) => solve(mask).distance;

  /// Hint: the next move on the solver's shortest path from [mask].
  int? hint(int mask) => solve(mask).nextMove;

  /// Full shortest move sequence from [mask] (ends with the golden frog).
  List<int>? solutionPath(int mask) {
    final r = solve(mask);
    if (r.distance == null || !r.exact) return null;
    final path = <int>[];
    var m = mask;
    while (board.isPresent(m, board.goldenIndex)) {
      final mv = _next[m];
      if (mv == null) return null;
      path.add(mv);
      m &= ~(1 << mv);
    }
    return path;
  }

  void clearCache() {
    _dist.clear();
    _next.clear();
    _h.clear();
  }

  SolveResult solve(int start) {
    if (board.isWon(start)) return const SolveResult(0, null, true);
    final cached = _dist[start];
    if (cached != null) {
      return cached < 0
          ? const SolveResult(null, null, true)
          : SolveResult(cached, _next[start], true);
    }
    final h0 = heuristic(start);
    if (h0 == null) {
      _dist[start] = -1;
      return const SolveResult(null, null, true);
    }

    final golden = board.goldenIndex;
    final n = board.frogCount;
    final heap = _Heap();
    final gScore = <int, int>{start: 0};
    final parent = <int, int>{};
    final parentMove = <int, int>{};
    final closed = <int>{};
    heap.push(_Node(start, 0, h0, _Node.kSearch));
    var expanded = 0;

    while (heap.isNotEmpty) {
      final node = heap.pop();
      if (node.kind != _Node.kSearch) {
        lastExpanded = expanded;
        return _finish(start, node, parent, parentMove);
      }
      final mask = node.mask;
      if (closed.contains(mask)) continue;
      closed.add(mask);
      expanded++;
      if (expanded > maxNodes) {
        lastExpanded = expanded;
        return SolveResult(h0, null, false);
      }

      if (board.canTap(mask, golden)) {
        heap.push(_Node(mask, node.g, node.g + 1, _Node.kGoldenGoal));
        continue; // every other child has f >= g + 2
      }
      if (mask != start) {
        final c = _dist[mask];
        if (c != null) {
          if (c >= 0) {
            heap.push(_Node(mask, node.g, node.g + c, _Node.kCachedGoal));
          }
          continue;
        }
      }
      final ng = node.g + 1;
      for (var f = 0; f < n; f++) {
        if (f == golden || !board.canTap(mask, f)) continue;
        final child = mask & ~(1 << f);
        if (closed.contains(child)) continue;
        final old = gScore[child];
        if (old != null && old <= ng) continue;
        final hc = heuristic(child);
        if (hc == null) continue;
        gScore[child] = ng;
        parent[child] = mask;
        parentMove[child] = f;
        heap.push(_Node(child, ng, ng + hc, _Node.kSearch));
      }
    }

    // Exhausted: nothing reachable from start can win, so every closed state
    // is unwinnable too.
    lastExpanded = expanded;
    for (final m in closed) {
      _dist[m] = -1;
    }
    return const SolveResult(null, null, true);
  }

  SolveResult _finish(
      int start, _Node goal, Map<int, int> parent, Map<int, int> parentMove) {
    final total = goal.f;
    // Walk back from the goal state to start, caching exact distances.
    final chain = <int>[]; // states from goal back to start
    final moves = <int>[]; // move that led INTO chain[i]
    var m = goal.mask;
    while (m != start) {
      chain.add(m);
      moves.add(parentMove[m]!);
      m = parent[m]!;
    }
    // Goal state itself.
    final goalRemaining = total - goal.g;
    _dist[goal.mask] = goalRemaining;
    if (goal.kind == _Node.kGoldenGoal) _next[goal.mask] = board.goldenIndex;
    // States between start and goal: chain[i] is at depth (chain.length - i).
    for (var i = 0; i < chain.length; i++) {
      final depth = chain.length - i;
      _dist[chain[i]] = total - depth;
    }
    for (var i = 0; i < chain.length; i++) {
      // The move into chain[i] is the next move from chain[i+1] (or start).
      final from = i + 1 < chain.length ? chain[i + 1] : start;
      _next[from] = moves[i];
    }
    _dist[start] = total;
    if (chain.isEmpty && goal.kind == _Node.kGoldenGoal) {
      _next[start] = board.goldenIndex;
    }
    return SolveResult(total, _next[start], true);
  }

  /// Admissible lower bound on taps to win, or null if provably unwinnable.
  int? heuristic(int mask) {
    final c = _h[mask];
    if (c != null) return c < 0 ? null : c;
    final v = _computeHeuristic(mask);
    _h[mask] = v ?? -1;
    return v;
  }

  int? _computeHeuristic(int mask) {
    final golden = board.goldenIndex;
    if (!board.isPresent(mask, golden)) return 0;
    final n = board.frogCount;
    // mustClear[f] = frogs that must leave before f can (only for frogs with a
    // single snake-free direction); 0 otherwise.
    final mustClear = List<int>.filled(n, 0);
    var required = 1 << golden;
    final stack = <int>[golden];
    while (stack.isNotEmpty) {
      final f = stack.removeLast();
      var feasible = 0;
      Facing? only;
      if (board.onRotator[f]) {
        for (final d in Facing.values) {
          if (!board.raySnake(f, d)) {
            feasible++;
            only = d;
          }
        }
      } else {
        final d = board.level.frogs[f].facing;
        if (!board.raySnake(f, d)) {
          feasible = 1;
          only = d;
        }
      }
      if (feasible == 0) return null;
      if (feasible == 1) {
        final blockers = board.rayFrogMask(f, only!) & mask;
        mustClear[f] = blockers;
        for (var g = 0; g < n; g++) {
          if ((blockers >> g) & 1 == 1 && (required >> g) & 1 == 0) {
            required |= 1 << g;
            stack.add(g);
          }
        }
      }
    }
    // Cycle in the must-clear graph => deadlock.
    final color = List<int>.filled(n, 0); // 0 new, 1 on stack, 2 done
    bool hasCycle(int f) {
      color[f] = 1;
      final edges = mustClear[f];
      for (var g = 0; g < n; g++) {
        if ((edges >> g) & 1 == 1) {
          if (color[g] == 1) return true;
          if (color[g] == 0 && hasCycle(g)) return true;
        }
      }
      color[f] = 2;
      return false;
    }

    for (var f = 0; f < n; f++) {
      if ((required >> f) & 1 == 1 && color[f] == 0 && hasCycle(f)) return null;
    }
    return bitCount(required);
  }
}

class _Node {
  static const int kSearch = 0;
  static const int kGoldenGoal = 1;
  static const int kCachedGoal = 2;
  final int mask;
  final int g;
  final int f;
  final int kind;
  const _Node(this.mask, this.g, this.f, this.kind);
}

/// Binary min-heap on f; ties prefer larger g (deeper), then goals.
class _Heap {
  final List<_Node> _a = [];
  bool get isNotEmpty => _a.isNotEmpty;

  static bool _less(_Node x, _Node y) {
    if (x.f != y.f) return x.f < y.f;
    if (x.kind != y.kind) return x.kind > y.kind; // goals first on ties
    return x.g > y.g;
  }

  void push(_Node n) {
    _a.add(n);
    var i = _a.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (!_less(_a[i], _a[p])) break;
      final t = _a[i];
      _a[i] = _a[p];
      _a[p] = t;
      i = p;
    }
  }

  _Node pop() {
    final top = _a.first;
    final last = _a.removeLast();
    if (_a.isNotEmpty) {
      _a[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var s = i;
        if (l < _a.length && _less(_a[l], _a[s])) s = l;
        if (r < _a.length && _less(_a[r], _a[s])) s = r;
        if (s == i) break;
        final t = _a[i];
        _a[i] = _a[s];
        _a[s] = t;
        i = s;
      }
    }
    return top;
  }
}
