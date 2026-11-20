// Readable text grids -> Level. PURE DART. Used by tests and by the How to
// Play demo boards, so the guide is built from the same engine as the game.
//
// One token per cell, space separated:
//   .  empty pad          X  snake
//   N E S W  frog facing that way
//   n e s w  GOLDEN frog facing that way
// Append `r` to put the cell on a rotator pad, e.g. `Wr` or `.r`.
// Frogs are indexed in row-major order.

import 'models.dart';

Level levelFromRows(List<String> rows,
    {int par = 0,
    int budgetSlack = kDefaultBudgetSlack,
    int id = 0,
    int world = 1}) {
  final size = rows.length;
  final frogs = <Frog>[];
  final pads = <Pad>[];
  final snakes = <Snake>[];
  for (var y = 0; y < size; y++) {
    final tokens = rows[y].trim().split(RegExp(r'\s+'));
    if (tokens.length != size) {
      throw ArgumentError('row $y has ${tokens.length} cells, expected $size');
    }
    for (var x = 0; x < size; x++) {
      final t = tokens[x];
      final c = t[0];
      if (t.length > 1 && t[1] == 'r') pads.add(Pad(x, y, PadType.rotator));
      if (c == '.') continue;
      if (c == 'X') {
        snakes.add(Snake(x, y));
        continue;
      }
      frogs.add(Frog(x, y, Facing.parse(c), golden: c == c.toLowerCase()));
    }
  }
  return Level(
      id: id,
      world: world,
      size: size,
      frogs: frogs,
      pads: pads,
      snakes: snakes,
      par: par,
      budgetSlack: budgetSlack);
}
