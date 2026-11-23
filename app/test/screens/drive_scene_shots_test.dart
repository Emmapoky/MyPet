// Renders the "Log while driving" scenes at iPhone size, for before/after comparisons.
// Run: flutter test test/screens/drive_scene_shots_test.dart --update-goldens
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mypet/ui/feedback.dart';
import 'package:mypet/ui/guide.dart';
import 'package:mypet/ui/theme.dart';

Future<void> _font(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}

void main() {
  Feel.sounds = false;
  setUpAll(() async {
    await _font('Nunito', 'assets/fonts/Nunito-Variable.ttf');
    await _font('Atkinson Hyperlegible Next', 'assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf');
    final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
    await _font('MaterialIcons', '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

  for (final dark in [false, true]) {
    for (final closeUp in [false, true]) {
      final name = '25-drive-${closeUp ? 'closeup' : 'road'}${dark ? '-dark' : ''}';
      testWidgets(name, (t) async {
        t.view.physicalSize = const Size(1179, 2556);
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: VoiceScene(closeUp: closeUp, petName: 'Biscuit'),
        ));
        await t.pump(const Duration(seconds: 1));
        await expectLater(find.byType(VoiceScene), matchesGoldenFile('out/$name.png'));
      });
    }
  }
}
