import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/core.dart';

/// Loads the committed level JSONs and the story/world data from assets.
class LevelRepository {
  static const int levelCount = 30;

  final List<Level> levels;
  final StoryBook story;
  LevelRepository(this.levels, [this.story = StoryBook.empty]);

  static String assetPath(int id) =>
      'assets/levels/level_${id.toString().padLeft(2, '0')}.json';

  static Future<LevelRepository> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final levels = <Level>[];
    for (var id = 1; id <= levelCount; id++) {
      final raw = await b.loadString(assetPath(id), cache: false);
      levels.add(Level.fromJson(jsonDecode(raw) as Map<String, Object?>));
    }
    final storyRaw =
        jsonDecode(await b.loadString('assets/worlds.json', cache: false))
            as Map<String, Object?>;
    return LevelRepository(levels, StoryBook.fromJson(storyRaw));
  }

  List<int> get ids => [for (final l in levels) l.id];
  Level byId(int id) => levels.firstWhere((l) => l.id == id);
  Level? after(int id) {
    final i = ids.indexOf(id);
    return i >= 0 && i + 1 < levels.length ? levels[i + 1] : null;
  }

  List<Level> world(int w) => levels.where((l) => l.world == w).toList();
}
