import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_scope.dart';
import 'services/audio_service.dart';
import 'services/haptics_service.dart';
import 'services/level_repository.dart';
import 'services/storage_service.dart';
import 'core/story.dart';
import 'ui/auth_screens.dart';
import 'ui/home_shell.dart';
import 'ui/palette.dart';
import 'ui/story_screens.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const JinHopApp());
}

typedef _Services = (
  LevelRepository,
  StorageService,
  AudioService,
  HapticsService
);

/// Loads services (local JSON + preferences, a few ms), then:
///   first launch -> onboarding (illustrated intro) -> Login -> Dashboard
///   later        -> Dashboard (or Login after logging out).
/// The only "splash" is this brief cream screen.
class JinHopApp extends StatefulWidget {
  /// Tests pass a silent backend; the app uses audioplayers.
  final AudioBackend? audioBackend;
  const JinHopApp({super.key, this.audioBackend});

  @override
  State<JinHopApp> createState() => _JinHopAppState();
}

class _JinHopAppState extends State<JinHopApp> with WidgetsBindingObserver {
  late final Future<_Services> _boot = _load();
  AudioService? _audio;

  Future<_Services> _load() async {
    final r = await Future.wait<Object>(
        [LevelRepository.load(), StorageService.open()]);
    final levels = r[0] as LevelRepository;
    final storage = r[1] as StorageService;
    final audio = AudioService(widget.audioBackend ?? AudioplayersBackend(),
        soundOn: storage.soundOn, musicOn: storage.musicOn);
    _audio = audio;
    // Audio warms up in the background; the first level never waits for it.
    audio.init().catchError((Object e) => debugPrint('Audio init failed: $e'));
    return (levels, storage, audio, HapticsService(enabled: storage.hapticsOn));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final a = _audio;
    if (a == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      a.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      a.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Services>(
      future: _boot,
      builder: (context, snap) {
        final data = snap.data;
        final Widget home;
        if (data == null) {
          home = const _Splash();
        } else {
          // Signed-in players land on the dashboard, others on Login.
          const Widget play = StartScreen();
          final intro = data.$1.story.intro;
          home = intro.isEmpty || data.$2.seen('intro')
              ? play
              : _IntroGate(cards: intro, then: play);
        }
        final app = MaterialApp(
          title: 'JinHop',
          debugShowCheckedModeBanner: false,
          theme: jinhopTheme(), // the one ThemeData for every screen
          navigatorObservers: [routeObserver],
          home: home,
        );
        return data == null
            ? app
            : AppScope(
                levels: data.$1,
                storage: data.$2,
                audio: data.$3,
                haptics: data.$4,
                child: app);
      },
    );
  }
}

/// Dashboard if signed in (or playing as a guest), otherwise Login.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      AppScope.of(context).storage.signedIn ? const HomeShell() : const LoginScreen();
}

/// Onboarding: shows the illustrated prologue once, then [then].
class _IntroGate extends StatelessWidget {
  final List<StoryCard> cards;
  final Widget then;
  const _IntroGate({required this.cards, required this.then});

  @override
  Widget build(BuildContext context) => IntroScreen(
        cards: cards,
        onDone: () {
          AppScope.of(context).storage.markSeen('intro');
          Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, __, ___) => then,
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
          ));
        },
      );
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Jin.cream,
        body: Center(
          child: Text('JinHop',
              style: TextStyle(
                  color: Jin.jadeDeep,
                  fontSize: 40,
                  fontWeight: FontWeight.w800)),
        ),
      );
}
