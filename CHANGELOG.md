# JinHop dev log

## Stage 6 — Hops, clock, hints, coins, world revival, new Jin Chan (2026-10-30)

### Changed
- "Par" is gone from the game. The HUD shows **Hops: N** (the three-star target) with "used X" under it;
  the win card says "Hops: N · used X". Stars depend on hops only, never on time.
- **No undo.** Hops are final. The Undo button is replaced by **Restart** in the bottom bar (still also in
  Pause); the restless banner now offers Restart only.
- **Countdown clock** from level 6: 60 s in World 1 (L6-15), 90 s in World 2 (L16-30) and the daily pond.
  Shown as m:ss, turns red for the last 15 s. At 0 the level fails ("Time's up!") and Try again resets the
  board and the clock. L1-5 stay untimed. The clock waits while paused, during dialogs, on other screens
  and while the app is in the background (leaving the app opens Pause). Running out of hops shows
  "Out of hops!".
- **Hints:** 2 free per level (badge on the button). Hints used stay used after a restart. Clearer visual:
  the pond dims, the hinted frog glows and bounces on a pulsing gold ring, and a trail of dots with an
  arrow shows the way it will hop.
- **Finale:** the reverse replay is removed. The winning tap is Jin Chan's golden leap, straight into the
  colour wash and the lotus bloom (about 2.6 s).
- **Story:** the Dou Dou scene now appears after level 5 (was 8), right before the turning pads arrive on
  level 6. Text unchanged.
- **Jin Chan redrawn:** rounder and cuter, bigger eyes, blush and a happy smile; the coin is now hugged
  against his belly with both front paws (side view: held at the chest) instead of sitting at his mouth.
  App icon and store icon regenerated from the new art.
- How to Play cards 4-5 rewritten: "Hops and the clock", "Hints and coins".

### Added
- **Gold coins** (`lib/core/rewards.dart`, `lib/ui/coins.dart`): +10 per newly earned star on a level and
  +10 the first time it is cleared (replays for the same stars earn nothing); +25 for the daily pond (once
  a day); **daily sign-in reward** card (7-day cycle: 10, 15, 20, 25, 30, 40, 60; missing a day restarts at
  day 1), shown on the first screen of the day. Coins buy extra hints (20 each) once the free ones are
  used. Coin balance shown in the game's bottom bar and on the world map; coins earned shown on the win card.
- **World revival** (`lib/ui/world_revival.dart`): when a world's last level is cleared, its ending plays
  as an ~8 s animation: the grey, misty world map, Jin Chan glowing at the start of the path, a wave of
  colour climbing the pond with a sparkle on each lotus as it blooms, mist drifting away, the landmark
  lighting up, then the ending text. Tap to skip (after 1 s), tap again to continue.

### Tests
- New: rewards (level coins, sign-in cycle), timer (limits per world, fail at 0, never affects stars,
  stops on win/fail), hints (2 free, granted, survive restart), countdown UI (red at 15 s, pauses with
  the menu, time-up screen, retry resets), hint purchase flow, sign-in card on first launch, world
  revival flow. Undo/reverse-replay tests removed.
- `flutter analyze`: no issues. `flutter test`: 92/92 passed.

## Stage 4 — Art, audio, haptics, Settings, How to Play (2026-10-27)

### Added
- Art pass (`lib/ui/art.dart`, all vector, no image assets): top-down frogs with haunches, feet,
  eyes and a bold back arrow; the golden Jin Chan with three legs, red spots and a square-holed
  coin in its mouth; coiled sleeping snakes with closed eyes; coin lily pads with shade and
  highlight; soft radial-lit pond; lotus blooms (used by the icon now, the finale in Stage 5).
- Colourblind-safe arrows (Settings): ink arrows with a thick cream halo; the golden frog is also
  told apart by shape (coin, three legs), not only colour.
- App icon drawn from the same art (`tool/render_icon_test.dart`): legacy + adaptive icons for all
  densities, 512 px store icon in `docs/store/`. Cream launch background (no white flash).
- Bundled font: Nunito (SIL OFL, `assets/fonts/`, Latin subset, 4 weights, ~140 KB). No runtime
  font fetching.
- `AudioService` (audioplayers): low-latency SFX pools where playback rate also shifts pitch, so
  every croak sounds a little different (0.85-1.2x); splash, soft shake thud, bloom chime,
  31 s seamless ambient loop; separate Sound and Music toggles; music pauses in the background.
  Every audio call is wrapped so audio failures can never crash the game.
- Placeholder audio synthesised by `tool/audio/make_placeholder_sfx.py` (original, CC0, ~270 KB).
  Verified CC0 replacements and ffmpeg commands in `docs/audio_credits.md`.
- `HapticsService`: light impact on a hop/undo/win, lighter selection click on a blocked tap.
- Settings screen: sound, music, haptics, colourblind-safe arrows, link to How to Play.
  Reachable from the world map and the pause menu.
- How to Play: 5 auto-playing cards (ray rule, golden frog, turning pads, petals/budget with the
  exact line "Every tap and every undo uses a petal", hint/undo). Each demo is a real Level run
  through the real GameSession, BoardController, BoardView and BudgetMeter.
- Exported guide images from the real widgets: `docs/how_to_play/card_1-5.png`,
  `docs/screens/*.png` (world map, settings, fail, story card, win).

### Tests added
- Audio: pitch range and variety, sound mute, music loop start/stop, lifecycle pause/resume,
  asset files exist. Game events -> correct sounds (blocked = shake, hop = croak + splash,
  undo = splash, win = croak + bloom). Settings toggles persist and apply immediately.
  Colourblind paints. Each How to Play script, replayed on the real engine, produces exactly the
  outcome its caption describes. How to Play pages through all 5 cards.

### Verified
- `flutter analyze`: no issues. `flutter test`: 75/75 passed.

## Stage 3 — Levels, budget HUD, progression (2026-10-27)

### Added
- 30 curated levels in `assets/levels/` (W1 Misty Pond L1-15, W2 Lantern Marsh L16-30), produced by
  `dart run tool/generate_levels.dart` (deterministic). Each is generator-built, solver-checked and
  validator-checked, then picked from up to 60 seeds so a random-tapping player's win rate follows a
  smooth curve (100% on L1-5, 64% on L6 down to 10% on L30). Table: `docs/difficulty_table.md`.
- `assets/story.json`: the 5 "The Last Jin Chan" cards; shown once each, after L1, L15 (two cards)
  and L30 (two cards), as a soft full-screen fade, tap to dismiss. L1 shows no card before play.
- HUD: lotus-petal budget meter (markers at par / par+2 / cap, jade-to-amber, never red),
  taps left, par, pause, undo, hint. L1-5 show "No limit".
- Restless banner (non-blocking, Undo/Restart), fail screen "The pond rests. Try again?" with the
  golden frog resting in slow ripples (Try again / Home), win card (stars, taps vs par, Next/Replay/Map),
  pause (Resume/Restart/World map), world map with stars and sequential unlocks.
- Rotator intro on L6: one-time gentle pulse on rotator pads.
- `StorageService` (shared_preferences): best stars and best taps per level, one-time flags,
  settings. App launches straight into the next unplayed level (world map once all are done).
- Tests: committed-level checks (validator, L1-5 slack 99, slack ranges, rotators/snakes per world,
  L1 blocked decoy, story cards), game flow widget tests (launch routing, restless -> fail at cap+1,
  banner buttons, story then win, progress saved, Next, pause -> map -> tile). Solver perf test now
  runs on the hardest committed level (L30).

### Decisions / assumptions
- Levels unlock in order; the world map shows locked levels with a lock.
- "Home" on the fail screen goes to the world map (there is no separate home screen; launch goes
  straight to play).
- Story cards appear right after the winning tap, before the win card.
- Settings and How to Play screens come with Stage 4 (audio/haptics toggles live there).

### Verified
- `flutter analyze`: no issues. `flutter test`: 60/60 passed.
- Solver perf, L30 (par 13, 22 frogs), cold cache, 61 states: avg 0.28 ms, worst 2.45 ms.
- First release APK build: `flutter build apk --release --split-per-abi` succeeded.
  arm64-v8a 16.6 MB, armeabi-v7a 13.8 MB, x86_64 18.1 MB (universal APK 46.9 MB).
  Package com.jinhop.game, label JinHop, targetSdk 36, no INTERNET permission, no GMS/Firebase
  classes in the APK. Not yet run on a device or emulator.

## Stage 2 — Playable board UI (2026-10-27)

### Added
- Android project (`flutter create`), package id `com.jinhop.game`, label `JinHop`, portrait only.
- `lib/ui/art.dart`: vector art primitives (coin pads with square hole, rotator arrows, frog with
  bold direction arrow, golden Jin Chan with coin, sleeping snake). Paths rebuilt only on resize;
  How to Play will reuse these so the guide matches the build.
- `lib/ui/board_painter.dart`: board rendering, hop (arc + shrink + ripple), shake across the
  facing, blocker "puff", sleepy stir when a snake blocks, rotator turn animation (reverses on undo),
  long-press ray preview with amber rings on blockers, hint ring. No Paint/Path/Shader allocation
  per frame.
- `lib/ui/board_controller.dart`: wraps GameSession, drives effects, emits GameEvents
  (hop, blocked, won, failed, undo, restart, hint, restless) for audio/haptics/analytics later.
- `lib/ui/board_view.dart`: tap/long-press hit testing; one Ticker that stops when idle.
- Temporary `GameScreen` (undo, restart, taps/par text) on a generated placeholder level.
- `test/ui/board_view_test.dart` (6 widget tests), `tool/render_board_preview_test.dart`
  (renders PNG previews to build/preview).

### Verified
- `flutter analyze`: no issues. `flutter test`: 47/47 passed.
- Not yet built as an APK (Android SDK download blocked in the build environment).

## Stage 1 — Core, solver, generator, GameSession, tests (2026-10-27)

### Added
- `lib/core/models.dart`: Facing, PadType/Pad, Frog, Snake, Level (JSON in/out, `budgetSlack` default 5).
- `lib/core/board.dart`: compiled board + rules engine (ray rule, tap resolution, rotator orientation
  `base + validTapCount mod 4`). State is one int bitmask.
- `lib/core/solver.dart`: A* (BFS-equivalent) with an admissible, consistent "must clear first"
  heuristic, per-board cache, `minRemaining`, `hint`, `solutionPath`.
- `lib/core/game_session.dart`: tap / undo / restart, budget (`validTaps + undoCount`), cap, stars,
  fail at cap+1, restless nudge, reverse-replay order from the net history stack.
- `lib/core/generator.dart`: seeded reverse-removal-order generator (acyclic by construction),
  `lib/core/level_validator.dart` (par >= 4, >= 12 frogs on 6x6+, >= 30% decoys, slack 99 or 3-7),
  `lib/core/rng.dart` (own xorshift32 so seeds match on every device).
- Tests in `test/core/`: rules, rotator orientation, budget, stars, nudge, replay, generator cycle
  prevention, validator, solver vs plain BFS, solver performance.

### Verified (Flutter 3.47.8 / Dart 3.13.7, Linux x64)
- `flutter analyze`: No issues found.
- `flutter test test/core`: 41/41 passed.
- Solver perf (hardest 7x7 shape, 22 frogs, par 11, cold cache, 61 states):
  avg 0.19 ms, worst 1.70 ms, worst 11 nodes expanded. Not yet measured on a phone.

### Decisions / assumptions
- Every grid cell is a lily pad; level JSON lists only special pads.
- `budgetSlack >= 99` means "no cap" (L1-5 can never fail; HUD shows no cap).
- A tap or undo that would make budgetUsed = cap + 1 fails the level and is not applied; winning
  exactly at the cap is allowed.
- "Decoy" = a frog not on the solver's shortest path; decoys = frogCount - par.
- The 12-frog minimum is applied to 7x7 boards too.

## Stage 5 — 2.5D art, story, finale, celebration, daily (2026-10-29)
- 2.5D board: cute vector frogs and Jin Chan (back/side/front views), pads drawn in perspective, taps hit the frog body (nearest row first).
- Dull → alive: every board starts grey; on a win the colour wash spreads from Jin Chan and empty pads bloom.
- Finale: reverse replay of the solved path (~4 s, tap to skip after 1 s) → golden leap → wash → bloom.
- Celebration on every win: Jin Chan bounce, stars pop with a chime each, coin/petal confetti, share card (PNG via share sheet).
- Story: illustrated intro before level 1 (skippable, shown once); data-driven `assets/worlds.json`, 15 levels per world, each ending at a landmark (Moon Bridge, Lantern Shrine) that lights up. 9 illustrated scenes drawn in code.
- 2.5D world map: grey pads → bloomed lotus on completion, glowing bud on the current level, landmark per world, world banner, total stars, Play / Daily buttons.
- Daily puzzle (date-seeded, same for everyone on a day) with Lucky streak and one forgiveness token.
- Fixes: finale skip could stall when skipped early in a session; celebration footer overflow on narrow fonts; scene/celebration painters no longer allocate per frame.
- Tests: 90 passing (new: story book, daily determinism/solvability, streak rules, 2.5D hit testing, finale, celebration chimes, world map, intro).
