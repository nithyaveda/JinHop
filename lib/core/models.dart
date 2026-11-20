// JinHop core models. PURE DART: no Flutter imports allowed in lib/core.
//
// Coordinates: x = column (0 = left), y = row (0 = top). North is y - 1.

/// The four facings a frog can have, in clockwise order.
enum Facing {
  n,
  e,
  s,
  w;

  int get dx => const [0, 1, 0, -1][index];
  int get dy => const [-1, 0, 1, 0][index];

  /// Rotate clockwise by [quarterTurns] (may be negative).
  Facing rotated(int quarterTurns) => Facing.values[(index + quarterTurns) % 4];

  String get code => const ['N', 'E', 'S', 'W'][index];

  static Facing parse(String s) {
    switch (s.toUpperCase()) {
      case 'N':
        return Facing.n;
      case 'E':
        return Facing.e;
      case 'S':
        return Facing.s;
      case 'W':
        return Facing.w;
    }
    throw FormatException('Unknown facing "$s"');
  }
}

/// Pad types. Every grid cell is a lily pad; only special pads are listed in
/// level JSON. To add a pad type: add a value here, give it a JSON name in
/// [padTypeFromJson], and handle it in Rules.facingOf / Rules constructor.
enum PadType { normal, rotator }

PadType padTypeFromJson(String s) {
  switch (s) {
    case 'normal':
      return PadType.normal;
    case 'rotator':
      return PadType.rotator;
  }
  throw FormatException('Unknown pad type "$s"');
}

String padTypeToJson(PadType t) => t.name;

class Pad {
  final int x;
  final int y;
  final PadType type;
  const Pad(this.x, this.y, this.type);

  Map<String, Object?> toJson() =>
      {'x': x, 'y': y, 'type': padTypeToJson(type)};
  factory Pad.fromJson(Map<String, Object?> j) =>
      Pad(j['x'] as int, j['y'] as int, padTypeFromJson(j['type'] as String));
}

class Frog {
  final int x;
  final int y;

  /// Base facing. On a rotator pad the effective facing is
  /// facing.rotated(validTapCount % 4).
  final Facing facing;
  final bool golden;
  const Frog(this.x, this.y, this.facing, {this.golden = false});

  Map<String, Object?> toJson() => {
        'x': x,
        'y': y,
        'facing': facing.code,
        if (golden) 'golden': true,
      };
  factory Frog.fromJson(Map<String, Object?> j) => Frog(
        j['x'] as int,
        j['y'] as int,
        Facing.parse(j['facing'] as String),
        golden: (j['golden'] as bool?) ?? false,
      );
}

/// A sleeping guardian. Static, untappable, blocks rays.
class Snake {
  final int x;
  final int y;
  const Snake(this.x, this.y);

  Map<String, Object?> toJson() => {'x': x, 'y': y};
  factory Snake.fromJson(Map<String, Object?> j) =>
      Snake(j['x'] as int, j['y'] as int);
}

/// Budget slack at or above this value means the level never fails
/// (tutorial levels 1-5 use 99).
const int kUnlimitedSlack = 99;
const int kDefaultBudgetSlack = 5;

class Level {
  final int id;
  final int world;
  final int size;
  final List<Frog> frogs;
  final List<Pad> pads;
  final List<Snake> snakes;
  final int par;
  final int budgetSlack;

  /// One-time gentle pulse on rotator pads (L6).
  final bool rotatorIntro;

  /// Generator seed this level came from (informational).
  final int? seed;

  Level({
    required this.id,
    required this.world,
    required this.size,
    required List<Frog> frogs,
    List<Pad> pads = const [],
    List<Snake> snakes = const [],
    required this.par,
    this.budgetSlack = kDefaultBudgetSlack,
    this.rotatorIntro = false,
    this.seed,
  })  : frogs = List.unmodifiable(frogs),
        pads = List.unmodifiable(pads),
        snakes = List.unmodifiable(snakes);

  int get goldenIndex => frogs.indexWhere((f) => f.golden);
  bool get unlimitedBudget => budgetSlack >= kUnlimitedSlack;
  int get cap => par + budgetSlack;
  int cellIndex(int x, int y) => y * size + x;
  bool inBounds(int x, int y) => x >= 0 && y >= 0 && x < size && y < size;

  PadType padAt(int x, int y) {
    for (final p in pads) {
      if (p.x == x && p.y == y) return p.type;
    }
    return PadType.normal;
  }

  int get rotatorCount => pads.where((p) => p.type == PadType.rotator).length;

  Level copyWith(
          {int? id,
          int? world,
          int? par,
          int? budgetSlack,
          bool? rotatorIntro}) =>
      Level(
        id: id ?? this.id,
        world: world ?? this.world,
        size: size,
        frogs: frogs,
        pads: pads,
        snakes: snakes,
        par: par ?? this.par,
        budgetSlack: budgetSlack ?? this.budgetSlack,
        rotatorIntro: rotatorIntro ?? this.rotatorIntro,
        seed: seed,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'world': world,
        'size': size,
        'par': par,
        'budgetSlack': budgetSlack,
        if (rotatorIntro) 'rotatorIntro': true,
        if (seed != null) 'seed': seed,
        'frogs': [for (final f in frogs) f.toJson()],
        'pads': [for (final p in pads) p.toJson()],
        'snakes': [for (final s in snakes) s.toJson()],
      };

  factory Level.fromJson(Map<String, Object?> j) => Level(
        id: j['id'] as int,
        world: j['world'] as int,
        size: j['size'] as int,
        par: j['par'] as int,
        budgetSlack: (j['budgetSlack'] as int?) ?? kDefaultBudgetSlack,
        rotatorIntro: (j['rotatorIntro'] as bool?) ?? false,
        seed: j['seed'] as int?,
        frogs: [
          for (final f in (j['frogs'] as List<Object?>))
            Frog.fromJson(f as Map<String, Object?>)
        ],
        pads: [
          for (final p in ((j['pads'] as List<Object?>?) ?? const []))
            Pad.fromJson(p as Map<String, Object?>)
        ],
        snakes: [
          for (final s in ((j['snakes'] as List<Object?>?) ?? const []))
            Snake.fromJson(s as Map<String, Object?>)
        ],
      );
}

/// Number of set bits.
int bitCount(int v) {
  var c = 0;
  while (v != 0) {
    v &= v - 1;
    c++;
  }
  return c;
}

/// Hard limit so a board state fits in one 64-bit int bitmask.
const int kMaxFrogs = 62;
