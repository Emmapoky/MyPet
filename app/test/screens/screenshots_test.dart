// Renders the main screens at iPhone size with the real fonts, for comparing with Figma.
// Run: flutter test test/screens --update-goldens   (PNGs land in test/screens/out/)
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Brightness, MaterialApp, ThemeMode;
import 'package:mypet/ui/health_record_screen.dart';
import 'package:mypet/ui/pet_edit_screen.dart';
import 'package:mypet/ui/theme.dart';
import 'package:provider/provider.dart';

import '../fixtures/vet_samples.dart';
import 'package:mypet/ui/feedback.dart';
import 'package:mypet/data/local_backend.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/state/app_state.dart';
import 'package:mypet/state/demo_data.dart';
import 'package:mypet/ui/app.dart';

import '../behaviour_test.dart' show FakeEngine, bark, barkUnclear, purr, talk;

Future<void> loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  Feel.sounds = false;
  final now = DateTime(2027, 3, 15, 19, 30);

  setUpAll(() async {
    await loadFont('Nunito', 'assets/fonts/Nunito-Variable.ttf');
    await loadFont(
      'Atkinson Hyperlegible Next',
      'assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf',
    );
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
    await loadFont(
      'MaterialIcons',
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
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
    await expectLater(
      find.byType(MyPetApp),
      matchesGoldenFile('out/$name.png'),
    );
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
    await t.scrollUntilVisible(
      find.text('Edit today'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Edit today'));
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
    await t.tap(find.bySemanticsLabel('Record a clip of Biscuit'));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    await t.pump(const Duration(seconds: 6));
    await expectLater(
      find.byType(MyPetApp),
      matchesGoldenFile('out/08-recording.png'),
    );
    await t.tap(find.bySemanticsLabel('Stop recording'));
    await shot(t, '09-result');
  });

  testWidgets('walkthroughs', (t) async {
    await setUp(t);
    final s = await state(demo: false);
    await s.addPet(name: 'Mao', species: Species.cat);
    await s.addPet(name: 'Woof', species: Species.dog);
    s.tourSeen = false;
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await shot(t, '13-tour-1');
    await t.tap(find.text('Next'));
    await t.tap(find.text('Next'));
    await shot(t, '13-tour-3');
    await t.tap(find.text('Skip'));
    s.goToTab(0);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('More').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Try a demo'));
    await t.pumpAndSettle();
    await shot(t, '14-demo-picker');
    await t.tap(find.text('A dog not feeling well'));
    await t.pump(const Duration(seconds: 1));
    await shot(t, '14-story-1');
    await t.tap(find.text('Next'));
    await t.tap(find.text('Next'));
    await shot(t, '14-story-3');
    await t.tap(find.text('Next'));
    await shot(t, '14-story-4');
  });

  testWidgets('health record from a vet PDF', (t) async {
    await setUp(t);
    final s = await state(demo: false);
    final pet = await s.addPet(name: 'Biscuit', species: Species.dog);
    final text = vetSamples['vaccination-certificate']!.replaceFirst('Sunway Paws Veterinary Clinic\n', '');
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: s,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        debugShowCheckedModeBanner: false,
        home: HealthRecordScreen(pet: pet, pickPdf: () async => '/x/biscuit-vaccines.pdf', readPdf: (_) async => text),
      ),
    ));
    await t.tap(find.text('Fill from a vet PDF'));
    await t.pumpAndSettle();
    await expectLater(find.byType(HealthRecordScreen), matchesGoldenFile('out/15-vet-pdf.png'));
  });

  testWidgets('pet editor with photo and colours', (t) async {
    await setUp(t);
    final s = await state(demo: false);
    final pet = await s.addPet(name: 'Mao', species: Species.cat);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: s,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        debugShowCheckedModeBanner: false,
        home: PetEditScreen(pet: pet),
      ),
    ));
    await t.pumpAndSettle();
    await expectLater(find.byType(PetEditScreen), matchesGoldenFile('out/16-pet-edit.png'));
  });

  testWidgets('dark mode', (t) async {
    await setUp(t);
    final s = await state();
    s.selectPet(s.pets.firstWhere((p) => p.name == 'Biscuit').id);
    s.setLook(ThemeMode.dark);
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await shot(t, '02d-today-dark');
    s.goToTab(3);
    await shot(t, '05d-insights-dark');
  });

  for (final (name, emb, species) in [
    ('09a-not-heard', talk, Species.dog),
    ('09b-cat-purring', purr, Species.cat),
    ('09c-not-sure', barkUnclear, Species.dog),
  ]) {
    testWidgets(name, (t) async {
      await setUp(t);
      final s = await state(demo: false);
      await s.addPet(
        name: species == Species.cat ? 'Mochi' : 'Milo',
        species: species,
      );
      s.goToTab(2);
      await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(emb)));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Choose a video'));
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
