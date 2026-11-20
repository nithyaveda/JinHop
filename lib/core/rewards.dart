// Gold coin rewards. PURE DART.
//
// Coins are earned by finishing levels (once per newly earned star, plus a
// first-clear bonus), by checking in each day (Lucky Day: a fixed reward, 7 lanterns per cycle) and by
// solving the daily pond. They are spent on extra hints.

/// Coins for each star earned for the first time on a level.
const int kCoinsPerNewStar = 10;

/// Bonus the first time a level is cleared.
const int kFirstClearCoins = 10;

/// Solving the daily pond (once per day).
const int kDailyPondCoins = 25;

/// Price of one extra hint once the free ones are used.
const int kHintPrice = 20;

/// Coins for the daily Lucky Day check-in (the same every day).
const int kSignInCoins = 5;

/// Lanterns in one Lucky Day cycle; day 8 lights lantern 1 again.
const int kLuckyLanterns = 7;

/// Coins for a level win: new stars beyond the previous best, plus the
/// first-clear bonus. Replaying a level for the same stars earns nothing, so
/// coins cannot be farmed.
int coinsForLevelWin({required int previousStars, required int stars}) {
  final first = previousStars <= 0 ? kFirstClearCoins : 0;
  final newStars = stars > previousStars ? stars - previousStars : 0;
  return first + newStars * kCoinsPerNewStar;
}

/// A daily sign-in streak.
class SignIn {
  /// Consecutive days signed in, counting [lastDay] (0 = never).
  final int streak;

  /// dayNumber of the last claim, -1 = never.
  final int lastDay;
  const SignIn({this.streak = 0, this.lastDay = -1});

  bool canClaim(int today) => lastDay != today;

  /// Day of the 7-day cycle (1..7) that claiming on [today] would be.
  int nextCycleDay(int today) {
    final continues = lastDay >= 0 && today - lastDay == 1;
    final s = continues ? streak + 1 : 1;
    return (s - 1) % kLuckyLanterns + 1;
  }

  int rewardOn(int today) => kSignInCoins;

  /// Streak length after claiming on [today].
  int streakAfterClaim(int today) => lastDay >= 0 && today - lastDay == 1 ? streak + 1 : 1;

  /// State after claiming on [today]. Claiming twice the same day changes
  /// nothing.
  SignIn claimedOn(int today) {
    if (!canClaim(today)) return this;
    final continues = lastDay >= 0 && today - lastDay == 1;
    return SignIn(streak: continues ? streak + 1 : 1, lastDay: today);
  }
}
