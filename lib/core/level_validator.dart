// Level validator. PURE DART.

import 'board.dart';
import 'models.dart';
import 'solver.dart';

class ValidationResult {
  final List<String> errors;
  final int? solvedPar;
  final int decoys;
  const ValidationResult(this.errors, this.solvedPar, this.decoys);
  bool get ok => errors.isEmpty;
  @override
  String toString() =>
      ok ? 'OK (par $solvedPar, decoys $decoys)' : errors.join('; ');
}

class LevelRules {
  static const int minSize = 4;
  static const int maxSize = 8;
  static const int minPar = 4;
  static const int minFrogsOn6x6 = 12;
  static const double minDecoyRatio = 0.3;
  static const int minSlack = 3;
  static const int maxSlack = 7;
}

class LevelValidator {
  /// Full validation including the generator acceptance rules. Pass
  /// [checkPar] = false to skip comparing the stored par (used by the
  /// generator before it writes par in).
  static ValidationResult validate(Level level,
      {bool checkPar = true, int maxNodes = 200000}) {
    final errors = <String>[];
    if (level.size < LevelRules.minSize || level.size > LevelRules.maxSize) {
      errors.add(
          'size ${level.size} outside ${LevelRules.minSize}-${LevelRules.maxSize}');
    }
    final goldens = level.frogs.where((f) => f.golden).length;
    if (goldens != 1) {
      errors.add('expected exactly 1 golden frog, found $goldens');
    }
    if (level.frogs.length > kMaxFrogs) errors.add('too many frogs');
    for (final p in level.pads) {
      if (!level.inBounds(p.x, p.y)) {
        errors.add('pad (${p.x},${p.y}) out of bounds');
      }
    }
    final s = level.budgetSlack;
    if (!(s >= kUnlimitedSlack ||
        (s >= LevelRules.minSlack && s <= LevelRules.maxSlack))) {
      errors.add(
          'budgetSlack $s must be 99 or ${LevelRules.minSlack}-${LevelRules.maxSlack}');
    }
    if (level.size >= 6 && level.frogs.length < LevelRules.minFrogsOn6x6) {
      errors.add(
          '${level.size}x${level.size} board has ${level.frogs.length} frogs (< ${LevelRules.minFrogsOn6x6})');
    }
    if (errors.isNotEmpty) return ValidationResult(errors, null, 0);

    final Board board;
    try {
      board = Board(level);
    } on ArgumentError catch (e) {
      return ValidationResult(['${e.message}'], null, 0);
    }
    final r = Solver(board, maxNodes: maxNodes).solve(board.fullMask);
    if (!r.exact) {
      return const ValidationResult(['solver node limit hit'], null, 0);
    }
    final par = r.distance;
    if (par == null) {
      return const ValidationResult(['unwinnable from the start'], null, 0);
    }
    if (checkPar && par != level.par) {
      errors.add('stored par ${level.par} != solver par $par');
    }
    if (par < LevelRules.minPar) errors.add('par $par < ${LevelRules.minPar}');
    final decoys = level.frogs.length - par;
    if (decoys < LevelRules.minDecoyRatio * level.frogs.length) {
      errors.add(
          'decoys $decoys/${level.frogs.length} below ${(LevelRules.minDecoyRatio * 100).round()}%');
    }
    return ValidationResult(errors, par, decoys);
  }
}
