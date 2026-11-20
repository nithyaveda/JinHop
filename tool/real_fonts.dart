// Loads the real app font and Material icons into flutter_test so exported
// images show actual text instead of the test placeholder font.
import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadRealFonts() async {
  final nunito = FontLoader('Nunito');
  for (final w in const ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    nunito.addFont(Future.value(ByteData.sublistView(File('assets/fonts/Nunito-$w.ttf').readAsBytesSync())));
  }
  await nunito.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}
