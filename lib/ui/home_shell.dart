// Dashboard: the app's home after login. A BottomNavigationBar switches
// between three tabs:
//   Home    - summary (stars, coins, levels cleared, lucky streak, world
//             progress) and shortcuts (Continue, World map, Daily pond)
//   Levels  - the main feature: every level in a scrolling ListView.builder
//   Profile - the player's profile, with Edit profile (Create/Edit form)

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/core.dart';
import '../services/storage_service.dart';
import 'coins.dart' show CoinIcon, showSignInReward;
import 'how_to_play_screen.dart';
import 'levels_screen.dart';
import 'palette.dart';
import 'profile_screens.dart';
import 'routes.dart';
import 'theme.dart';
import 'world_map_screen.dart';

/// Lets the dashboard refresh its numbers when the player comes back from a
/// level or the map (registered in MaterialApp.navigatorObservers).
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class HomeShell extends StatefulWidget {
  final int initialTab;
  const HomeShell({super.key, this.initialTab = 0});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with RouteAware {
  late int _tab = widget.initialTab;
  bool _offered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
    if (_offered) return;
    _offered = true;
    // First visit of the day: the Lucky Day check-in (daily reward).
    final storage = AppScope.of(context).storage;
    final today = dayNumber(DateTime.now());
    if (storage.signIn.canClaim(today)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showSignInReward(context, storage, today);
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Back on the dashboard after a pushed screen closes: refresh the numbers.
  @override
  void didPopNext() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardTab(onOpenLevels: () => setState(() => _tab = 1)),
      const LevelsTab(),
      const ProfileTab(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Jin.jadeMist, width: 1.5))),
        child: BottomNavigationBar(
          key: const Key('bottom_nav'),
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.format_list_bulleted_rounded),
                activeIcon: Icon(Icons.list_alt_rounded),
                label: 'Levels'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Home tab

class DashboardTab extends StatelessWidget {
  final VoidCallback onOpenLevels;
  const DashboardTab({super.key, required this.onOpenLevels});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final st = scope.storage;
    final ids = scope.levels.ids;
    final profile = st.profile;
    final text = Theme.of(context).textTheme;
    final cleared = ids.where((id) => st.record(id) != null).length;
    final next = st.nextUnplayed(ids);
    final today = dayNumber(DateTime.now());

    return ListView(
      key: const Key('dashboard'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Greeting
        Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Jin.jade,
            child: Text(profile.initial,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hi, ${profile.name}!', key: const Key('dash_greeting'), style: text.headlineSmall),
              Text(profile.motto.isEmpty ? 'Ready to bring the ponds back to life?' : profile.motto,
                  style: text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          IconButton(
            tooltip: 'How to play',
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HowToPlayScreen())),
            icon: const Icon(Icons.help_outline_rounded, color: Jin.jadeDeep),
          ),
        ]),
        const SizedBox(height: 20),

        // Summary: three equal tiles (Row + Expanded)
        Row(children: [
          Expanded(
              child: _StatTile(
                  key: const Key('dash_stars'),
                  icon: const Icon(Icons.star_rounded, color: Jin.gold, size: 28),
                  value: '${st.totalStars(ids)}',
                  label: 'of ${ids.length * 3} stars')),
          const SizedBox(width: 12),
          Expanded(
              child: _StatTile(
                  key: const Key('dash_coins'), icon: const CoinIcon(size: 26), value: '${st.coins}', label: 'coins')),
          const SizedBox(width: 12),
          Expanded(
              child: _StatTile(
                  key: const Key('dash_cleared'),
                  icon: const Icon(Icons.local_florist_rounded, color: Color(0xFFD9667F), size: 28),
                  value: '$cleared',
                  label: 'of ${ids.length} cleared')),
        ]),
        const SizedBox(height: 16),

        // Continue card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Jin.jade, Jin.jadeDeep]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(color: Color(0x332E8B6E), blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(next == null ? 'Every pond is in bloom!' : 'Up next: Level $next',
                style: text.titleLarge!.copyWith(color: Colors.white)),
            const SizedBox(height: 4),
            Text(
                next == null
                    ? 'Replay any level for three stars, or try today\'s Daily pond.'
                    : '${scope.levels.story.worldOf(next)?.name ?? ''} · Hops: ${scope.levels.byId(next).par}',
                style: text.bodyMedium!.copyWith(color: Colors.white.withAlpha(220))),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('dash_continue'),
              style: FilledButton.styleFrom(backgroundColor: Jin.gold, foregroundColor: Jin.ink),
              onPressed: () => Navigator.push(context, fadeRoute(RouteName.level, levelId: next ?? ids.last)),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(next == null ? 'Play level ${ids.last}' : 'Continue'),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Shortcuts (InkWell cards)
        Row(children: [
          Expanded(
            child: _ShortcutCard(
              key: const Key('dash_map'),
              icon: Icons.map_rounded,
              title: 'World map',
              subtitle: 'See your ponds bloom',
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const WorldMapScreen())),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ShortcutCard(
              key: const Key('dash_daily'),
              icon: Icons.wb_sunny_rounded,
              iconColor: Jin.gold,
              title: 'Daily pond',
              subtitle: st.dailyRecord(today) == null ? 'New puzzle today' : 'Solved today!',
              onTap: () => Navigator.push(context, fadeRoute(RouteName.daily)),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // World progress
        Container(
          padding: const EdgeInsets.all(18),
          decoration: jinCard(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('World progress', style: text.titleMedium)),
              TextButton(onPressed: onOpenLevels, child: const Text('All levels')),
            ]),
            for (final w in scope.levels.story.worlds) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(w.name, style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w700))),
                Text('${_clearedIn(st, w)} / ${w.levelCount}', style: text.bodySmall),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(minHeight: 10, value: _clearedIn(st, w) / w.levelCount),
              ),
            ],
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.local_fire_department_rounded, color: Jin.red),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Lucky Day streak: ${st.signIn.streak} day${st.signIn.streak == 1 ? '' : 's'}',
                    style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
      ],
    );
  }

  static int _clearedIn(StorageService st, WorldInfo w) {
    var n = 0;
    for (var id = w.first; id <= w.last; id++) {
      if (st.record(id) != null) n++;
    }
    return n;
  }
}

class _StatTile extends StatelessWidget {
  final Widget icon;
  final String value;
  final String label;
  const _StatTile({super.key, required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: jinCard(),
      child: Column(children: [
        icon,
        const SizedBox(height: 6),
        FittedBox(child: Text(value, style: text.titleLarge)),
        FittedBox(child: Text(label, style: text.bodySmall)),
      ]),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ShortcutCard(
      {super.key,
      required this.icon,
      this.iconColor = Jin.jade,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: jinCard(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: iconColor, size: 30),
              const SizedBox(height: 10),
              Text(title, style: text.titleMedium),
              Text(subtitle, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }
}
