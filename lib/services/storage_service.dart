import 'package:shared_preferences/shared_preferences.dart';

import '../core/daily.dart';
import '../core/profile.dart';
import '../core/rewards.dart';

/// Best result for one level.
class LevelRecord {
  final int stars;
  final int bestUsed;
  const LevelRecord(this.stars, this.bestUsed);
}

/// Local progress and settings (shared_preferences). Offline only.
/// Every read has a safe default so a corrupt or empty store never crashes.
class StorageService {
  final SharedPreferences _p;
  StorageService(this._p);

  static Future<StorageService> open() async =>
      StorageService(await SharedPreferences.getInstance());

  // ---- progress
  LevelRecord? record(int levelId) {
    final s = _p.getInt('stars_$levelId');
    if (s == null || s <= 0) return null;
    return LevelRecord(s, _p.getInt('best_$levelId') ?? 0);
  }

  /// Saves a win; keeps the best stars and the lowest budgetUsed.
  /// Returns true if this was the first completion of the level.
  Future<bool> saveWin(int levelId, int stars, int budgetUsed) async {
    final old = record(levelId);
    if (old == null || stars > old.stars) {
      await _p.setInt('stars_$levelId', stars);
    }
    if (old == null || budgetUsed < old.bestUsed) {
      await _p.setInt('best_$levelId', budgetUsed);
    }
    return old == null;
  }

  int totalStars(Iterable<int> levelIds) =>
      levelIds.fold(0, (a, id) => a + (record(id)?.stars ?? 0));

  /// The lowest level id not yet completed, or null if all are done.
  int? nextUnplayed(List<int> levelIds) {
    for (final id in levelIds) {
      if (record(id) == null) return id;
    }
    return null;
  }

  /// A level is open if it is the first one or the previous one is done.
  bool isUnlocked(int levelId, List<int> levelIds) {
    final i = levelIds.indexOf(levelId);
    if (i <= 0) return true;
    return record(levelIds[i - 1]) != null || record(levelId) != null;
  }

  // ---- player account and profile
  // Practical 1: kept on the device only and no password is stored.
  // Practical 2 moves this to a database with real authentication.
  bool get signedIn => _p.getBool('signed_in') ?? false;
  bool get isGuest => _p.getBool('guest') ?? false;

  /// Email of the account registered on this device (null = none yet).
  String? get accountEmail => _p.getString('account_email');

  PlayerProfile get profile => PlayerProfile(
        name: _p.getString('profile_name') ?? 'Player',
        email: _p.getString('profile_email') ?? '',
        motto: _p.getString('profile_motto') ?? '',
        favouriteWorld: _p.getInt('profile_world') ?? 1,
        guest: isGuest,
      );

  Future<void> saveProfile(PlayerProfile p) async {
    await _p.setString('profile_name', p.name.trim());
    await _p.setString('profile_email', p.email.trim());
    await _p.setString('profile_motto', p.motto.trim());
    await _p.setInt('profile_world', p.favouriteWorld);
  }

  /// Creates the account on this device (the player logs in afterwards).
  Future<void> register({required String name, required String email}) async {
    await _p.setString('account_email', email.trim().toLowerCase());
    await saveProfile(PlayerProfile(name: name, email: email));
  }

  Future<void> logIn(String email) async {
    if (_p.getString('profile_email')?.isEmpty ?? true) {
      await _p.setString('profile_email', email.trim());
    }
    await _p.setBool('guest', false);
    await _p.setBool('signed_in', true);
  }

  Future<void> playAsGuest() async {
    await _p.setBool('guest', true);
    await _p.setBool('signed_in', true);
  }

  /// Signs out; progress, coins and the registered account stay.
  Future<void> logOut() async {
    await _p.setBool('signed_in', false);
    await _p.setBool('guest', false);
  }

  // ---- one-time flags (story cards, rotator intro)
  bool seen(String key) => _p.getBool('seen_$key') ?? false;
  Future<void> markSeen(String key) => _p.setBool('seen_$key', true);

  // ---- settings
  bool get soundOn => _p.getBool('sound') ?? true;
  bool get musicOn => _p.getBool('music') ?? true;
  bool get hapticsOn => _p.getBool('haptics') ?? true;
  bool get colorblindArrows => _p.getBool('colorblind') ?? false;
  Future<void> setSoundOn(bool v) => _p.setBool('sound', v);
  Future<void> setMusicOn(bool v) => _p.setBool('music', v);
  Future<void> setHapticsOn(bool v) => _p.setBool('haptics', v);
  Future<void> setColorblindArrows(bool v) => _p.setBool('colorblind', v);

  // ---- daily puzzle + lucky streak
  LevelRecord? dailyRecord(int day) {
    final s = _p.getInt('daily_stars_$day');
    if (s == null || s <= 0) return null;
    return LevelRecord(s, _p.getInt('daily_best_$day') ?? 0);
  }

  LuckyStreak get luckyStreak => LuckyStreak(
        count: _p.getInt('streak_count') ?? 0,
        lastDay: _p.getInt('streak_last') ?? -1,
        tokenAvailable: _p.getBool('streak_token') ?? true,
      );

  /// Saves a daily win and advances the lucky streak. Returns the new streak.
  Future<LuckyStreak> saveDailyWin(int day, int stars, int budgetUsed) async {
    final old = dailyRecord(day);
    if (old == null || stars > old.stars) {
      await _p.setInt('daily_stars_$day', stars);
    }
    if (old == null || budgetUsed < old.bestUsed) {
      await _p.setInt('daily_best_$day', budgetUsed);
    }
    final s = luckyStreak.solvedOn(day);
    await _p.setInt('streak_count', s.count);
    await _p.setInt('streak_last', s.lastDay);
    await _p.setBool('streak_token', s.tokenAvailable);
    return s;
  }

  // ---- coins
  int get coins => _p.getInt('coins') ?? 0;
  Future<void> addCoins(int n) async {
    if (n <= 0) return;
    await _p.setInt('coins', coins + n);
  }

  /// Spends [n] coins if there are enough. Returns whether it worked.
  Future<bool> spendCoins(int n) async {
    if (coins < n) return false;
    await _p.setInt('coins', coins - n);
    return true;
  }

  /// Coins a win on [levelId] with [stars] would earn (call before saveWin).
  int coinsForWin(int levelId, int stars) => coinsForLevelWin(
      previousStars: record(levelId)?.stars ?? 0, stars: stars);

  /// Coins for solving the daily pond on [day] (only the first solve counts;
  /// call before saveDailyWin).
  int coinsForDaily(int day) => dailyRecord(day) == null ? kDailyPondCoins : 0;

  // ---- daily sign-in reward
  SignIn get signIn => SignIn(
      streak: _p.getInt('signin_streak') ?? 0,
      lastDay: _p.getInt('signin_last') ?? -1);

  /// Claims today's sign-in coins. Returns the coins added (0 if already
  /// claimed today).
  Future<int> claimSignIn(int today) async {
    final s = signIn;
    if (!s.canClaim(today)) return 0;
    final reward = s.rewardOn(today);
    final next = s.claimedOn(today);
    await _p.setInt('signin_streak', next.streak);
    await _p.setInt('signin_last', next.lastDay);
    await addCoins(reward);
    return reward;
  }

  // ---- generic access
  int? getInt(String k) => _p.getInt(k);
  Future<void> setInt(String k, int v) => _p.setInt(k, v);
  String? getString(String k) => _p.getString(k);
  Future<void> setString(String k, String v) => _p.setString(k, v);
}
