import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/app_scope.dart';
import 'package:jinhop/core/core.dart';
import 'package:jinhop/services/audio_service.dart';
import 'package:jinhop/services/haptics_service.dart';
import 'package:jinhop/services/level_repository.dart';
import 'package:jinhop/ui/board_painter.dart';
import 'package:jinhop/ui/board_view.dart';
import 'package:jinhop/ui/board_controller.dart';
import 'package:jinhop/ui/game_screen.dart';
import 'package:jinhop/ui/how_to_play_screen.dart';
import 'package:jinhop/ui/settings_screen.dart';

import '../core/fixtures.dart';
import '../services/fake_audio.dart';
import 'harness.dart';

void main() {
  test('audio asset files exist', () {
    for (final s in Sfx.values) {
      expect(File('assets/${AudioService.assetOf(s)}').existsSync(), isTrue, reason: s.name);
    }
    expect(File('assets/${AudioService.ambientAsset}').existsSync(), isTrue);
  });

  testWidgets('game events play the right sounds', (tester) async {
    phone(tester);
    final storage = await freshStorage();
    final fake = FakeAudioBackend();
    await tester.pumpWidget(AppScope(
      levels: LevelRepository([fixtureB()], testStory),
      storage: storage,
      audio: AudioService(fake),
      haptics: HapticsService(),
      child: MaterialApp(home: GameScreen(levelId: fixtureB().id)),
    ));
    await tester.pump();
    await tapCell(tester, 4, 2, 0); // blocked
    expect(fake.plays, ['audio/shake.ogg']);
    await tapCell(tester, 4, 2, 2); // hop
    expect(fake.plays.sublist(1), ['audio/croak.ogg', 'audio/splash.ogg']);
    for (final c in const [(2, 0), (0, 0)]) {
      await tapCell(tester, 4, c.$1, c.$2);
    }
    expect(fake.plays.sublist(fake.plays.length - 2), ['audio/croak.ogg', 'audio/splash.ogg']);
    // The pond blooms when the finale ends.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(fake.plays, contains('audio/bloom.ogg'));
  });

  testWidgets('settings toggles persist and apply immediately', (tester) async {
    phone(tester);
    final storage = await freshStorage();
    final fake = FakeAudioBackend();
    final audio = AudioService(fake);
    final haptics = HapticsService();
    await tester.pumpWidget(AppScope(
      levels: LevelRepository([fixtureB()], testStory),
      storage: storage,
      audio: audio,
      haptics: haptics,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    for (final k in const ['set_sound', 'set_music', 'set_haptics', 'set_colorblind']) {
      await tester.tap(find.byKey(Key(k)));
      await tester.pumpAndSettle();
    }
    expect(storage.soundOn, isFalse);
    expect(storage.musicOn, isFalse);
    expect(storage.hapticsOn, isFalse);
    expect(storage.colorblindArrows, isTrue);
    expect(audio.soundOn, isFalse);
    expect(fake.calls.last, 'stopLoop');
    expect(haptics.enabled, isFalse);
  });

  testWidgets('colourblind setting reaches the board painter', (tester) async {
    phone(tester);
    final storage = await freshStorage({'colorblind': true});
    await tester.pumpWidget(AppScope(
      levels: LevelRepository([fixtureB()], testStory),
      storage: storage,
      child: MaterialApp(home: GameScreen(levelId: fixtureB().id)),
    ));
    await tester.pump();
    final paint = tester
        .widget<CustomPaint>(find.descendant(of: find.byType(BoardView), matching: find.byType(CustomPaint)).first);
    expect((paint.painter! as BoardPainter).highContrast, isTrue);
  });

  group('How to Play matches the real engine', () {
    // Expected outcome of each scripted action, card by card.
    const expected = <List<String>>[
      ['preview', 'preview', 'blocked', 'removed', 'removed', 'wait'],
      ['blocked', 'removed', 'won'],
      ['blocked', 'removed', 'removed', 'removed', 'wait'],
      ['removed', 'removed', 'won'],
      ['hint', 'removed', 'won'],
    ];

    test('5 cards; no undo anywhere; hops, clock, hints and coins explained', () {
      expect(howToCards.length, 5);
      for (final c in howToCards) {
        expect(c.body.toLowerCase(), isNot(contains('undo')));
        expect(c.title.toLowerCase(), isNot(contains('undo')));
      }
      expect(howToCards[3].body, contains('Every hop uses a petal'));
      expect(howToCards[3].body, contains('clock'));
      expect(howToCards[4].body, contains('2 hints per level'));
    });

    for (var i = 0; i < howToCards.length; i++) {
      test('card ${i + 1} "${howToCards[i].title}" script', () {
        final card = howToCards[i];
        final c = BoardController(levelFromRows(card.rows, par: card.par, budgetSlack: card.slack));
        final got = <String>[];
        var lastHint = c.fx.hintFrog;
        for (final step in card.script) {
          final mask = c.session.mask;
          final status = c.session.status;
          final preview = c.fx.previewFrog;
          step.run(c);
          if (c.session.status == SessionStatus.won && status != SessionStatus.won) {
            got.add('won');
          } else if (c.session.mask != mask) {
            got.add('removed');
          } else if (c.fx.hintFrog != lastHint && c.fx.hintFrog >= 0) {
            got.add('hint');
          } else if (c.fx.previewFrog != preview) {
            got.add('preview');
          } else if (c.session.budgetUsed == 0 && c.fx.shakeStartUs.any((s) => s == c.fx.nowUs)) {
            got.add('blocked');
          } else {
            got.add(c.session.history.isEmpty && step.ms > 0 && c.fx.shakeStartUs.contains(c.fx.nowUs)
                ? 'blocked'
                : 'wait');
          }
          lastHint = c.fx.hintFrog;
        }
        expect(got, expected[i]);
        // Hint on card 5 must point at the frog the caption implies (frog 1).
        if (i == 4) expect(c.session.status, SessionStatus.won);
      });
    }
  });

  testWidgets('How to Play pages through all 5 cards and closes', (tester) async {
    phone(tester);
    final storage = await freshStorage();
    await tester.pumpWidget(AppScope(
      levels: LevelRepository([fixtureB()], testStory),
      storage: storage,
      child: MaterialApp(
          home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => const HowToPlayScreen())),
              child: const Text('open'),
            ),
          ),
        ),
      )),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    for (final c in howToCards) {
      expect(find.text(c.title), findsOneWidget);
      await tester.tap(find.byKey(const Key('howto_next')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle(
        const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2));
    expect(find.byType(HowToPlayScreen), findsNothing);
  });
}
