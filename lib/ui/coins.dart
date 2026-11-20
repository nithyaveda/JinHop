// Gold coins: the little coin icon, the counter, the daily sign-in reward
// card and the "buy a hint" card.

import 'package:flutter/material.dart';

import '../core/core.dart';
import '../services/storage_service.dart';
import 'overlays.dart' show JinButton;
import '../app_scope.dart';
import '../services/audio_service.dart';
import 'lucky_day.dart';
import 'palette.dart';

/// A square-holed gold coin.
class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 20});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _CoinPainter()));
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();
  static final Paint _face = Paint()..color = const Color(0xFFF2C64E);
  static final Paint _rim = Paint()
    ..color = const Color(0xFF8A5A0A)
    ..style = PaintingStyle.stroke;
  static final Paint _hole = Paint()..color = const Color(0xFF8A5A0A);
  static final Paint _shine = Paint()..color = const Color(0xCCFFF6CF);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    _rim.strokeWidth = r * 0.16;
    canvas.drawCircle(c, r * 0.92, _face);
    canvas.drawCircle(c, r * 0.92, _rim);
    canvas.drawCircle(c + Offset(-r * 0.38, -r * 0.38), r * 0.16, _shine);
    canvas.drawRect(
        Rect.fromCenter(center: c, width: r * 0.62, height: r * 0.62), _hole);
  }

  @override
  bool shouldRepaint(_CoinPainter old) => false;
}

/// Coin balance chip.
class CoinCounter extends StatelessWidget {
  final int coins;
  const CoinCounter({super.key, required this.coins});
  @override
  Widget build(BuildContext context) => Semantics(
        label: '$coins coins',
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1C2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Jin.gold, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const CoinIcon(size: 22),
            const SizedBox(width: 5),
            Text('$coins',
                key: const Key('coins'),
                style: const TextStyle(
                    color: Color(0xFF8A5A0A),
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

Widget _card(BuildContext context,
        {required Key key, required List<Widget> children}) =>
    Dialog(
      key: key,
      backgroundColor: Jin.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Jin.gold, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );

/// The daily Lucky Day check-in: a full screen where the player taps the
/// lucky coin to light today's lantern and collect the day's coins.
Future<void> showSignInReward(BuildContext context, StorageService storage, int today) async {
  final s = storage.signIn;
  if (!s.canClaim(today)) return;
  final scope = AppScope.maybeOf(context);
  await Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (ctx, _, __) => LuckyDayScreen(
      streak: s.streakAfterClaim(today),
      cycleDay: s.nextCycleDay(today),
      reward: s.rewardOn(today),
      lanterns: kLuckyLanterns,
      onClaim: () async {
        scope?.audio.play(Sfx.bloom);
        scope?.haptics.validTap();
        await storage.claimSignIn(today);
      },
      onDone: () => Navigator.of(ctx).pop(),
    ),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

/// Offers one extra hint for [kHintPrice] coins. Returns true if bought.
Future<bool> showBuyHint(BuildContext context, StorageService storage) async {
  final enough = storage.coins >= kHintPrice;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => _card(ctx, key: const Key('buy_hint'), children: [
      const Icon(Icons.lightbulb_outline_rounded, color: Jin.gold, size: 44),
      const SizedBox(height: 6),
      const Text('Out of free hints',
          style: TextStyle(
              color: Jin.jadeDeep, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(
          enough
              ? 'Use $kHintPrice coins for one more hint?'
              : 'A hint costs $kHintPrice coins. Finish levels, solve the daily pond and sign in each day to earn more.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Jin.ink, fontSize: 16, height: 1.3)),
      const SizedBox(height: 10),
      CoinCounter(coins: storage.coins),
      const SizedBox(height: 18),
      Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            JinButton(enough ? 'Not now' : 'OK',
                key: const Key('buy_hint_cancel'),
                primary: !enough,
                onPressed: () => Navigator.of(ctx).pop(false)),
            if (enough)
              JinButton('Use $kHintPrice', key: const Key('buy_hint_ok'),
                  onPressed: () async {
                final ok = await storage.spendCoins(kHintPrice);
                if (ctx.mounted) Navigator.of(ctx).pop(ok);
              }),
          ]),
    ]),
  );
  return r ?? false;
}
