import 'package:flutter/services.dart';

/// Light haptics. Uses the platform's view haptics (no VIBRATE permission).
class HapticsService {
  bool enabled;
  HapticsService({this.enabled = true});

  /// Valid hop: a light tick.
  void validTap() {
    if (!enabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Blocked tap: an even lighter selection click (never a buzz).
  void blockedTap() {
    if (!enabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
