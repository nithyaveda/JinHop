// Practical 1 flows: Login/Register validation, Navigator.push/pop between
// them, the dashboard's BottomNavigationBar, the level list
// (ListView.builder) and the Edit profile form.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/core.dart';
import 'package:jinhop/main.dart';
import 'package:jinhop/services/audio_service.dart';
import 'package:jinhop/ui/auth_screens.dart';
import 'package:jinhop/ui/game_screen.dart';
import 'package:jinhop/ui/home_shell.dart';
import 'package:jinhop/ui/profile_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<void> frames(WidgetTester tester, [int ms = 800]) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> launch(WidgetTester tester, Map<String, Object> prefs) async {
  phone(tester);
  SharedPreferences.setMockInitialValues({'seen_intro': true, 'signin_last': dayNumber(DateTime.now()), ...prefs});
  await tester.pumpWidget(JinHopApp(audioBackend: SilentAudioBackend()));
  await frames(tester, 400);
}

void main() {
  testWidgets('Login validates its fields before doing anything', (tester) async {
    await launch(tester, {});
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('login_email')), 'rana@msu');
    await tester.enterText(find.byKey(const Key('login_password')), 'abc');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(find.text('Enter a valid email, e.g. name@example.com'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);

    // Valid format but no account yet.
    await tester.enterText(find.byKey(const Key('login_email')), 'rana@msu.edu.my');
    await tester.enterText(find.byKey(const Key('login_password')), 'lotus7');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(find.byKey(const Key('login_error')), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('Register (push) validates, pops back to Login with the email, then Login opens the dashboard',
      (tester) async {
    await launch(tester, {});
    await tester.tap(find.byKey(const Key('go_register')));
    await frames(tester);
    expect(find.byType(RegisterScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('reg_submit')));
    await tester.pump();
    expect(find.text('Please enter a player name'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reg_name')), 'Rana');
    await tester.enterText(find.byKey(const Key('reg_email')), 'rana@msu.edu.my');
    await tester.enterText(find.byKey(const Key('reg_password')), 'lotus7');
    await tester.enterText(find.byKey(const Key('reg_confirm')), 'lotus8');
    await tester.tap(find.byKey(const Key('reg_submit')));
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reg_confirm')), 'lotus7');
    await tester.tap(find.byKey(const Key('reg_submit')));
    await frames(tester);
    expect(find.byType(RegisterScreen), findsNothing, reason: 'Navigator.pop back to Login');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('rana@msu.edu.my'), findsOneWidget, reason: 'email comes back with pop');

    await tester.enterText(find.byKey(const Key('login_password')), 'lotus7');
    await tester.tap(find.byKey(const Key('login_submit')));
    await frames(tester);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Hi, Rana!'), findsOneWidget);
  });

  testWidgets('Register back button pops without creating an account', (tester) async {
    await launch(tester, {});
    await tester.tap(find.byKey(const Key('go_register')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('register_back')));
    await frames(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('account_email'), isNull);
  });

  testWidgets('Dashboard: bottom navigation, level list opens a level, profile can be edited', (tester) async {
    await launch(tester,
        {'signed_in': true, 'profile_name': 'Lotus', 'profile_email': 'lotus@msu.edu.my', 'stars_1': 3, 'best_1': 3});
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Hi, Lotus!'), findsOneWidget);

    // Levels tab: ListView.builder; level 1 done, level 2 next, level 3 locked.
    await tester.tap(find.text('Levels'));
    await frames(tester, 300);
    expect(find.byKey(const Key('level_list')), findsOneWidget);
    expect(find.byKey(const Key('level_row_1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('level_row_3')));
    await frames(tester, 300);
    expect(find.byType(GameScreen), findsNothing, reason: 'locked levels do not open');
    await tester.tap(find.byKey(const Key('level_row_2')));
    await frames(tester);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(textOf(tester, 'level_title'), 'Level 2');
    Navigator.of(tester.element(find.byType(GameScreen))).pop();
    await frames(tester);
    expect(find.byType(HomeShell), findsOneWidget);

    // Profile tab -> Edit profile (push), validation, Save (pop with result).
    await tester.tap(find.text('Profile'));
    await frames(tester, 300);
    await tester.tap(find.byKey(const Key('edit_profile')));
    await frames(tester);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await tester.enterText(find.byKey(const Key('edit_name')), 'L');
    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pump();
    expect(find.text('Name is too short (at least 2 characters)'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('edit_name')), 'Lotus Hopper');
    await tester.enterText(find.byKey(const Key('edit_motto')), 'Think smart, hop forward');
    await tester.tap(find.byKey(const Key('edit_save')));
    await frames(tester);
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(textOf(tester, 'profile_name'), 'Lotus Hopper');
    expect(find.text('Profile saved'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('profile_name'), 'Lotus Hopper');

    // Cancel leaves the profile unchanged.
    await tester.tap(find.byKey(const Key('edit_profile')));
    await frames(tester);
    await tester.enterText(find.byKey(const Key('edit_name')), 'Someone Else');
    await tester.tap(find.byKey(const Key('edit_cancel')));
    await frames(tester);
    expect(textOf(tester, 'profile_name'), 'Lotus Hopper');

    // Log out returns to Login.
    await tester.tap(find.byKey(const Key('logout')));
    await frames(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(prefs.getBool('signed_in'), isFalse);
  });
}
