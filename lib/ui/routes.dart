import 'package:flutter/material.dart';

import '../core/daily.dart';
import 'game_screen.dart';
import 'world_map_screen.dart';

enum RouteName { level, map, daily }

/// Soft cross-fade between screens.
Route<void> fadeRoute(RouteName name, {int levelId = 1}) =>
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => switch (name) {
        RouteName.level => GameScreen(levelId: levelId),
        RouteName.map => const WorldMapScreen(),
        RouteName.daily =>
          GameScreen(level: dailyLevel(DateTime.now()), daily: true),
      },
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    );
