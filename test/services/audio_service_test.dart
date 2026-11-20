import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/services/audio_service.dart';

import 'fake_audio.dart';

void main() {
  test('croak pitch varies within 0.85-1.2', () {
    final b = FakeAudioBackend();
    final a = AudioService(b, rng: math.Random(1));
    final rates = [for (var i = 0; i < 30; i++) a.play(Sfx.croak)!];
    expect(rates.every((r) => r >= 0.85 && r <= 1.2), isTrue);
    expect(rates.toSet().length, greaterThan(20), reason: 'repeats should not sound alike');
    expect(b.plays.toSet(), {'audio/croak.ogg'});
  });

  test('sound mute stops effects; music toggle stops and restarts the loop', () async {
    final b = FakeAudioBackend();
    final a = AudioService(b);
    await a.init();
    expect(b.calls, ['preload 4', 'loop audio/ambient_loop.ogg']);
    await a.setSound(false);
    expect(a.play(Sfx.splash), isNull);
    expect(b.plays, isEmpty);
    await a.setMusic(false);
    expect(b.calls.last, 'stopLoop');
    await a.setMusic(true);
    expect(b.calls.last, 'loop audio/ambient_loop.ogg');
  });

  test('music off at start: no loop; lifecycle pause/resume', () async {
    final b = FakeAudioBackend();
    final a = AudioService(b, musicOn: false);
    await a.init();
    expect(b.calls.where((c) => c.startsWith('loop')), isEmpty);
    await a.setMusic(true);
    await a.onAppPaused();
    await a.onAppResumed();
    expect(b.calls.sublist(b.calls.length - 2), ['pauseLoop', 'resumeLoop']);
  });

  test('every sound asset the service uses exists', () {
    for (final s in Sfx.values) {
      expect(AudioService.assetOf(s), 'audio/${s.name}.ogg');
    }
  });
}
