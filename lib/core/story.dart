// Story data model ("The Last Jin Chan"), loaded from assets/worlds.json.
// PURE DART. Data-driven so new worlds (15 levels each, ending at a
// landmark) are added by editing JSON only.

class StoryCard {
  /// Unique id, used to remember that the card was seen.
  final String key;

  /// Illustration id drawn by the scene painter.
  final String scene;
  final String text;
  const StoryCard(this.key, this.scene, this.text);
}

class WorldInfo {
  final int id;
  final String name;
  final int first;
  final int last;
  final String landmark;
  final StoryCard? start;
  final StoryCard? end;
  final Map<int, StoryCard> beats; // after level -> card
  const WorldInfo(this.id, this.name, this.first, this.last, this.landmark,
      this.start, this.end, this.beats);

  bool contains(int levelId) => levelId >= first && levelId <= last;
  int get levelCount => last - first + 1;
}

class StoryBook {
  final String title;
  final List<StoryCard> intro;
  final List<WorldInfo> worlds;
  const StoryBook(this.title, this.intro, this.worlds);

  static const empty = StoryBook('', [], []);

  factory StoryBook.fromJson(Map<String, Object?> j) {
    StoryCard? card(Object? o, String key) {
      if (o == null) return null;
      final m = o as Map<String, Object?>;
      return StoryCard(key, m['scene'] as String, m['text'] as String);
    }

    final intro = <StoryCard>[];
    final introJson = (j['intro'] as List<Object?>?) ?? const [];
    for (var i = 0; i < introJson.length; i++) {
      intro.add(card(introJson[i], 'intro_$i')!);
    }
    final worlds = <WorldInfo>[];
    for (final w in (j['worlds'] as List<Object?>?) ?? const []) {
      final m = w as Map<String, Object?>;
      final id = m['id'] as int;
      final beats = <int, StoryCard>{};
      for (final b in (m['beats'] as List<Object?>?) ?? const []) {
        final bm = b as Map<String, Object?>;
        final after = bm['after'] as int;
        beats[after] = card(bm, 'w${id}_after$after')!;
      }
      worlds.add(WorldInfo(
          id,
          m['name'] as String,
          m['first'] as int,
          m['last'] as int,
          (m['landmark'] as String?) ?? '',
          card(m['start'], 'w${id}_start'),
          card(m['end'], 'w${id}_end'),
          beats));
    }
    return StoryBook((j['title'] as String?) ?? '', intro, worlds);
  }

  WorldInfo? worldOf(int levelId) {
    for (final w in worlds) {
      if (w.contains(levelId)) return w;
    }
    return null;
  }

  String worldName(int worldId) {
    for (final w in worlds) {
      if (w.id == worldId) return w.name;
    }
    return '';
  }

  /// Cards to show, in order, after [levelId] is won: any story beat, then
  /// (at a world's last level) the landmark card and the next world's opening.
  List<StoryCard> cardsAfter(int levelId) {
    final out = <StoryCard>[];
    final w = worldOf(levelId);
    if (w == null) return out;
    final beat = w.beats[levelId];
    if (beat != null) out.add(beat);
    if (levelId == w.last) {
      if (w.end != null) out.add(w.end!);
      final i = worlds.indexOf(w);
      if (i + 1 < worlds.length && worlds[i + 1].start != null) {
        out.add(worlds[i + 1].start!);
      }
    }
    return out;
  }
}
