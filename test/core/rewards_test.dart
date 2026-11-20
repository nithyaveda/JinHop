import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/core.dart';

void main() {
  group('level coins', () {
    test('first clear bonus plus 10 per new star; replays for the same stars earn nothing', () {
      expect(coinsForLevelWin(previousStars: 0, stars: 3), kFirstClearCoins + 30);
      expect(coinsForLevelWin(previousStars: 0, stars: 1), kFirstClearCoins + 10);
      expect(coinsForLevelWin(previousStars: 1, stars: 3), 20);
      expect(coinsForLevelWin(previousStars: 3, stars: 3), 0);
      expect(coinsForLevelWin(previousStars: 3, stars: 2), 0);
    });
  });

  group('daily sign-in', () {
    test('fixed +5 every day; 7 lanterns per cycle, then lantern 1 again', () {
      var s = const SignIn();
      final got = <int>[];
      final lanterns = <int>[];
      for (var day = 100; day < 109; day++) {
        expect(s.canClaim(day), isTrue);
        got.add(s.rewardOn(day));
        lanterns.add(s.nextCycleDay(day));
        expect(s.streakAfterClaim(day), day - 99);
        s = s.claimedOn(day);
        expect(s.canClaim(day), isFalse);
      }
      expect(got, List.filled(9, kSignInCoins));
      expect(kSignInCoins, 5);
      expect(lanterns, [1, 2, 3, 4, 5, 6, 7, 1, 2]);
    });

    test('missing a day restarts at day 1; claiming twice a day changes nothing', () {
      var s = const SignIn().claimedOn(10).claimedOn(11).claimedOn(12);
      expect(s.nextCycleDay(13), 4);
      expect(s.claimedOn(12).streak, s.streak);
      expect(s.nextCycleDay(15), 1);
      s = s.claimedOn(15);
      expect(s.streak, 1);
    });
  });
}
