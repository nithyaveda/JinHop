import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound effect ids. Files live at assets/audio/<name>.ogg.
enum Sfx { croak, splash, shake, bloom }

/// What actually makes noise. Swappable so tests (and devices where audio
/// fails) never crash.
abstract class AudioBackend {
  Future<void> preload(List<String> assets);
  Future<void> play(String asset,
      {required double rate, required double volume});
  Future<void> startLoop(String asset, {required double volume});
  Future<void> stopLoop();
  Future<void> pauseLoop();
  Future<void> resumeLoop();
}

class SilentAudioBackend implements AudioBackend {
  @override
  Future<void> preload(List<String> assets) async {}
  @override
  Future<void> play(String asset,
      {required double rate, required double volume}) async {}
  @override
  Future<void> startLoop(String asset, {required double volume}) async {}
  @override
  Future<void> stopLoop() async {}
  @override
  Future<void> pauseLoop() async {}
  @override
  Future<void> resumeLoop() async {}
}

/// audioplayers backend. SFX use low-latency mode (Android SoundPool), where
/// the playback rate also shifts pitch, giving each croak its own voice.
/// Every call is wrapped: audio problems must never crash the game.
class AudioplayersBackend implements AudioBackend {
  static const int voices = 3;
  final Map<String, List<AudioPlayer>> _pools = {};
  final Map<String, int> _next = {};
  AudioPlayer? _loop;

  @override
  Future<void> preload(List<String> assets) async {
    for (final a in assets) {
      try {
        final pool = <AudioPlayer>[];
        for (var i = 0; i < voices; i++) {
          final p = AudioPlayer();
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(AssetSource(a));
          pool.add(p);
        }
        _pools[a] = pool;
        _next[a] = 0;
      } catch (e) {
        debugPrint('Audio preload failed for $a: $e');
      }
    }
  }

  @override
  Future<void> play(String asset,
      {required double rate, required double volume}) async {
    try {
      final pool = _pools[asset];
      if (pool == null || pool.isEmpty) return;
      final i = _next[asset]!;
      _next[asset] = (i + 1) % pool.length;
      final p = pool[i];
      await p.stop();
      await p.setPlaybackRate(rate);
      await p.setVolume(volume);
      await p.resume();
    } catch (e) {
      debugPrint('Audio play failed for $asset: $e');
    }
  }

  @override
  Future<void> startLoop(String asset, {required double volume}) async {
    try {
      final p = _loop ??= AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(volume);
      await p.play(AssetSource(asset));
    } catch (e) {
      debugPrint('Ambient loop failed: $e');
    }
  }

  @override
  Future<void> stopLoop() async {
    try {
      await _loop?.stop();
    } catch (_) {}
  }

  @override
  Future<void> pauseLoop() async {
    try {
      await _loop?.pause();
    } catch (_) {}
  }

  @override
  Future<void> resumeLoop() async {
    try {
      await _loop?.resume();
    } catch (_) {}
  }
}

/// Game-facing audio API: pitch-varied croak, splash, shake, bloom, ambient
/// loop, with separate sound/music mutes.
class AudioService {
  static const ambientAsset = 'audio/ambient_loop.ogg';
  static String assetOf(Sfx s) => 'audio/${s.name}.ogg';

  final AudioBackend backend;
  final math.Random _rng;
  bool soundOn;
  bool musicOn;
  bool _loopRunning = false;

  AudioService(this.backend,
      {this.soundOn = true, this.musicOn = true, math.Random? rng})
      : _rng = rng ?? math.Random();

  factory AudioService.silent() =>
      AudioService(SilentAudioBackend(), soundOn: false, musicOn: false);

  Future<void> init() async {
    await backend.preload([for (final s in Sfx.values) assetOf(s)]);
    if (musicOn) await _startLoop();
  }

  /// Rate range per effect: croaks vary the most so repeats never sound alike.
  static const _rates = {
    Sfx.croak: (0.85, 1.2),
    Sfx.splash: (0.92, 1.08),
    Sfx.shake: (0.95, 1.05),
    Sfx.bloom: (1.0, 1.0),
  };
  static const _volumes = {
    Sfx.croak: 0.7,
    Sfx.splash: 0.55,
    Sfx.shake: 0.6,
    Sfx.bloom: 0.8
  };

  /// Returns the playback rate used, or null when muted (handy for tests).
  double? play(Sfx s, {double? rate}) {
    if (!soundOn) return null;
    final (lo, hi) = _rates[s]!;
    final r = rate ?? lo + _rng.nextDouble() * (hi - lo);
    backend.play(assetOf(s), rate: r, volume: _volumes[s]!);
    return r;
  }

  Future<void> setSound(bool on) async => soundOn = on;

  Future<void> setMusic(bool on) async {
    musicOn = on;
    if (on) {
      await _startLoop();
    } else {
      _loopRunning = false;
      await backend.stopLoop();
    }
  }

  Future<void> _startLoop() async {
    if (_loopRunning) return;
    _loopRunning = true;
    await backend.startLoop(ambientAsset, volume: 0.35);
  }

  /// App lifecycle: silence the pond while the app is in the background.
  Future<void> onAppPaused() => backend.pauseLoop();
  Future<void> onAppResumed() async {
    if (musicOn && _loopRunning) await backend.resumeLoop();
  }
}
