import 'package:flutter/widgets.dart';

import 'services/audio_service.dart';
import 'services/haptics_service.dart';
import 'services/level_repository.dart';
import 'services/storage_service.dart';

/// Gives every screen access to the app's services.
class AppScope extends InheritedWidget {
  final LevelRepository levels;
  final StorageService storage;
  final AudioService audio;
  final HapticsService haptics;

  AppScope({
    super.key,
    required this.levels,
    required this.storage,
    AudioService? audio,
    HapticsService? haptics,
    required super.child,
  })  : audio = audio ?? AudioService.silent(),
        haptics = haptics ?? HapticsService(enabled: false);

  static AppScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>();

  static AppScope of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope missing above this widget');
    return s!;
  }

  @override
  bool updateShouldNotify(AppScope old) =>
      old.levels != levels ||
      old.storage != storage ||
      old.audio != audio ||
      old.haptics != haptics;
}
