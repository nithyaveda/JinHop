// Daily puzzle and "lucky streak". PURE DART.
//
// The daily level is produced by the validated generator from a seed built
// from the calendar date, so everyone gets the same pond on the same day.

import 'generator.dart';
import 'models.dart';

/// Days since 1970-01-01 for the given local calendar date.
int dayNumber(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// yyyymmdd, the seed shared by every player that day.
int dailySeed(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

const dailyConfig = GeneratorConfig(
  size: 6,
  frogCount: 14,
  chainLength: 8,
  rotatorCount: 3,
  snakeCount: 1,
  minPar: 6,
  requireRotatorOnChain: true,
);

/// Daily level id space (never clashes with the campaign levels).
const int kDailyLevelId = 10000;

Level dailyLevel(DateTime date) {
  final g = const LevelGenerator().generate(dailyConfig,
      seed: dailySeed(date),
      id: kDailyLevelId,
      world: 0,
      budgetSlack: kDefaultBudgetSlack);
  if (g != null) return g.level;
  // Practically unreachable (the generator has thousands of attempts); fall
  // back to a neighbouring seed so the daily never fails to appear.
  return const LevelGenerator()
      .generate(dailyConfig,
          seed: dailySeed(date) + 1, id: kDailyLevelId, world: 0)!
      .level;
}

/// Consecutive days with a solved daily puzzle. One missed day can be
/// forgiven once (the forgiveness token), so a single busy day doesn't break
/// a long run.
class LuckyStreak {
  final int count;
  final int lastDay; // dayNumber of the last solved daily, -1 = never
  final bool tokenAvailable;
  const LuckyStreak(
      {this.count = 0, this.lastDay = -1, this.tokenAvailable = true});

  /// Streak as shown today (0 if it has lapsed beyond forgiveness).
  int currentOn(int today) {
    if (lastDay < 0) return 0;
    final gap = today - lastDay;
    if (gap <= 1) return count;
    if (gap == 2 && tokenAvailable) return count;
    return 0;
  }

  /// Records solving the daily on [day]. Solving twice the same day changes
  /// nothing.
  LuckyStreak solvedOn(int day) {
    if (lastDay < 0) {
      return LuckyStreak(
          count: 1, lastDay: day, tokenAvailable: tokenAvailable);
    }
    final gap = day - lastDay;
    if (gap <= 0) return this;
    if (gap == 1) {
      return LuckyStreak(
          count: count + 1, lastDay: day, tokenAvailable: tokenAvailable);
    }
    if (gap == 2 && tokenAvailable) {
      return LuckyStreak(count: count + 1, lastDay: day, tokenAvailable: false);
    }
    return LuckyStreak(count: 1, lastDay: day, tokenAvailable: tokenAvailable);
  }
}
