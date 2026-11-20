// Main feature screen: every level of JinHop in a scrolling list built with
// ListView.builder (only the rows on screen are built). Each row is a
// Container with BoxDecoration; tapping an open level (InkWell) pushes the
// game screen.

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/core.dart';
import 'palette.dart';
import 'routes.dart';
import 'theme.dart';

class LevelsTab extends StatelessWidget {
  const LevelsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final st = scope.storage;
    final levels = scope.levels.levels; // hard-coded level data (assets/levels)
    final ids = scope.levels.ids;
    final story = scope.levels.story;
    final text = Theme.of(context).textTheme;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Levels', style: text.headlineSmall),
          Text('${st.totalStars(ids)} of ${ids.length * 3} stars collected', style: text.bodyMedium),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          key: const Key('level_list'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: levels.length,
          itemBuilder: (context, i) {
            final level = levels[i];
            final world = story.worldOf(level.id);
            final record = st.record(level.id);
            final open = st.isUnlocked(level.id, ids);
            final row = _LevelRow(
              level: level,
              stars: record?.stars ?? 0,
              bestHops: record?.bestUsed,
              open: open,
              isNext: open && record == null,
              onTap: open ? () => Navigator.push(context, fadeRoute(RouteName.level, levelId: level.id)) : null,
            );
            // A heading before the first level of each world.
            if (world == null || world.first != level.id) return row;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: EdgeInsets.fromLTRB(4, i == 0 ? 4 : 18, 4, 8),
                child: Row(children: [
                  Icon(world.id == 1 ? Icons.water_rounded : Icons.light_rounded, color: Jin.jadeDeep),
                  const SizedBox(width: 8),
                  Expanded(child: Text('World ${world.id} · ${world.name}', style: text.titleMedium)),
                ]),
              ),
              row,
            ]);
          },
        ),
      ),
    ]);
  }
}

class _LevelRow extends StatelessWidget {
  final Level level;
  final int stars;
  final int? bestHops;
  final bool open;
  final bool isNext;
  final VoidCallback? onTap;
  const _LevelRow(
      {required this.level,
      required this.stars,
      required this.bestHops,
      required this.open,
      required this.isNext,
      required this.onTap});

  String get _features {
    final f = <String>['${level.size}×${level.size} pond', '${level.frogs.length} frogs'];
    if (level.pads.any((p) => p.type == PadType.rotator)) f.add('turning pads');
    if (level.snakes.isNotEmpty) f.add('snakes');
    return f.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final done = stars > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: open ? 1 : 0.55,
        child: Container(
          key: Key('level_row_${level.id}'),
          decoration: jinCard(border: isNext ? Jin.gold : null, color: open ? Colors.white : const Color(0xFFEDE7DA)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  // Number badge
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? Jin.jade : (open ? const Color(0xFFFFF1C2) : Jin.jadeMist),
                      border: Border.all(color: done ? Jin.jadeDeep : (open ? Jin.gold : Jin.jadeMist), width: 2),
                    ),
                    child: open
                        ? Text('${level.id}',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, color: done ? Colors.white : Jin.jadeDeep))
                        : const Icon(Icons.lock_rounded, color: Jin.jadeDeep, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Level ${level.id}', style: text.titleMedium),
                      Text(_features, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                          !open
                              ? 'Clear the level before to open'
                              : (done ? 'Best: $bestHops hops · Hops: ${level.par}' : 'Hops: ${level.par}'),
                          style: text.bodySmall!.copyWith(fontWeight: FontWeight.w700, color: Jin.jadeDeep)),
                    ]),
                  ),
                  if (isNext)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Jin.gold, borderRadius: BorderRadius.circular(12)),
                      child: const Text('Play',
                          style: TextStyle(color: Jin.ink, fontWeight: FontWeight.w800, fontSize: 13)),
                    )
                  else
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var s = 1; s <= 3; s++)
                        Icon(s <= stars ? Icons.star_rounded : Icons.star_border_rounded,
                            color: s <= stars ? Jin.gold : Jin.jadeMist, size: 22),
                    ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
