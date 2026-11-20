import 'package:flutter/material.dart';

import 'palette.dart';

/// The ONE app theme, defined once here and applied to the whole app through
/// `MaterialApp(theme: jinhopTheme())` in main.dart. Screens read colours,
/// text styles, buttons and form fields from it with `Theme.of(context)`, so
/// the look stays consistent and can be changed in a single place.
/// Font is the bundled Nunito (OFL, assets/fonts); nothing is fetched at
/// runtime.
ThemeData jinhopTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Jin.jade,
    primary: Jin.jade,
    secondary: Jin.gold,
    error: Jin.red,
    surface: Jin.cream,
  );
  final rounded16 = BorderRadius.circular(16);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: Jin.cream,

    // Typography: one scale for every screen.
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Jin.jadeDeep),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Jin.jadeDeep),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Jin.ink),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Jin.ink),
      bodyLarge: TextStyle(fontSize: 16, color: Jin.ink, height: 1.4),
      bodyMedium: TextStyle(fontSize: 15, color: Jin.ink, height: 1.4),
      bodySmall: TextStyle(fontSize: 13, color: Color(0xFF5A5A62)),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Jin.cream,
      foregroundColor: Jin.jadeDeep,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Nunito', fontSize: 20, fontWeight: FontWeight.w800, color: Jin.jadeDeep),
    ),

    // Form fields (Login, Register, Edit profile).
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: Jin.jade,
      labelStyle: const TextStyle(color: Color(0xFF5A5A62)),
      border: OutlineInputBorder(borderRadius: rounded16, borderSide: const BorderSide(color: Jin.jadeMist)),
      enabledBorder:
          OutlineInputBorder(borderRadius: rounded16, borderSide: const BorderSide(color: Jin.jadeMist, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: rounded16, borderSide: const BorderSide(color: Jin.jade, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: rounded16, borderSide: const BorderSide(color: Jin.red, width: 1.5)),
      focusedErrorBorder:
          OutlineInputBorder(borderRadius: rounded16, borderSide: const BorderSide(color: Jin.red, width: 2)),
    ),

    // Buttons.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Jin.jade,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Jin.jadeDeep,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: Jin.jade, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Jin.jadeDeep,
        textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),

    // Dashboard navigation.
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0, // a thin top border is drawn instead (see HomeShell)
      selectedItemColor: Jin.jade,
      unselectedItemColor: Jin.ink.withAlpha(120),
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
      unselectedLabelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600),
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Jin.jadeDeep,
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(fontFamily: 'Nunito', fontSize: 15, color: Colors.white),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Jin.jade, linearTrackColor: Jin.jadeMist),
  );
}

/// Shared card look (Container + BoxDecoration): white, rounded corners, a
/// soft border and a gentle shadow. Used by the dashboard, level list and
/// profile so every card matches.
BoxDecoration jinCard({Color color = Colors.white, Color? border}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border ?? Jin.jadeMist, width: 1.5),
      boxShadow: const [
        BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
      ],
    );
