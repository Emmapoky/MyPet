// Renders the main screens at iPhone size with the real fonts, for comparing with Figma.
// Run: flutter test test/screens --update-goldens   (PNGs land in test/screens/out/)
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/local_backend.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/state/app_state.dart';
import 'package:mypet/state/demo_data.dart';
import 'package:mypet/ui/app.dart';

import '../behaviour_test.dart' show FakeEngine, bark, barkUnclear, purr, talk;

Future<void> loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  final now = DateTime(2027, 3, 15, 19, 30);

  setUpAll(() async {
    await loadFont('Nunito', 'assets/fonts/Nunito-Variable.ttf');
    await loadFont('Atkinson Hyperlegible Next', 'assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf');
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
    await loadFont('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

  Future<AppState> state({bool demo = true}) async {
    final b = LocalBackend();
    final s = AppState(b, clock: () => now, detectInBackground: false);
    await b.signIn('', '');
    if (demo) await addDemoPets(s);
    return s;
  }

  Future<void> shot(WidgetTester t, String name) async {
    await t.pumpAndSettle();
    await expectLater(find.byType(MyPetApp), matchesGoldenFile('out/$name.png'));
  }

  Future<void> setUp(WidgetTester t) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
  }

  testWidgets('screens', (t) async {
    await setUp(t);
    final s = await state();
    s.selectPet(s.pets.firstWhere((p) => p.name == 'Biscuit').id);
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await shot(t, '02-today');
    await t.scrollUntilVisible(find.text('Log again'), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Log again'));
    await shot(t, '03-quick-log');
    await t.tap(find.text('Save'));
    await shot(t, '04-today-logged');
    s.goToTab(3);
    await shot(t, '05-insights');
    s.goToTab(4);
    await shot(t, '10-reminders');
    s.goToTab(1);
    await shot(t, '11-pets');
    s.goToTab(2);
    await shot(t, '07-record');
    await t.tap(find.bySemanticsLabel('Record a clip'));
    await t.pump();
    await t.pump(const Duration(seconds: 6));
    await expectLater(find.byType(MyPetApp), matchesGoldenFile('out/08-recording.png'));
    await t.tap(find.bySemanticsLabel('Stop recording'));
    await shot(t, '09-result');
  });

  for (final (name, emb, species) in [
    ('09a-not-heard', talk, Species.dog),
    ('09b-cat-purring', purr, Species.cat),
    ('09c-not-sure', barkUnclear, Species.dog),
  ]) {
    testWidgets(name, (t) async {
      await setUp(t);
      final s = await state(demo: false);
      await s.addPet(name: species == Species.cat ? 'Mochi' : 'Milo', species: species);
      s.goToTab(2);
      await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(emb)));
      await t.pumpAndSettle();
      await t.tap(find.text('Choose a video'));
      await shot(t, name);
    });
  }

  testWidgets('empty states', (t) async {
    await setUp(t);
    final s = await state(demo: false);
    await t.pumpWidget(MyPetApp(state: s));
    await shot(t, '12-no-pets');
    await s.addPet(name: 'Milo', species: Species.dog);
    s.goToTab(3);
    await shot(t, '06-insights-before-7-days');
  });
}
