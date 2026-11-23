// Renders the main screens at iPhone size with the real fonts, for comparing with Figma.
// Run: flutter test test/screens --update-goldens   (PNGs land in test/screens/out/)
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Scrollable, NavigatorState, Navigator;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Brightness, MaterialApp, MaterialPageRoute, ThemeMode;
import 'package:mypet/ui/settings_screen.dart';
import 'package:mypet/state/speed_test.dart';
import 'package:mypet/ui/speed_test_screen.dart';
import 'package:mypet/ui/health_record_screen.dart';
import 'package:mypet/ui/pet_edit_screen.dart';
import 'package:mypet/ui/pet_detail_screen.dart';
import 'package:mypet/ui/quick_log_screen.dart';
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
    await t.tap(find.byTooltip('Close the guide'));
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
    await t.tap(find.byTooltip('Tap me to shrink'));
    await t.pumpAndSettle();
    await shot(t, '14-story-shrunk');
  });

  testWidgets('pet owner review: log, weight, starter guide, pet page', (t) async {
    await setUp(t);
    final s = await state();
    final pepper = s.pets.firstWhere((p) => p.name == 'Pepper');
    final bean = s.pets.firstWhere((p) => p.name == 'Bean');
    await s.updatePet(bean.copyWith(checks: const ['drinking', 'accidents', 'vomited']));
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await t.pumpAndSettle();
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => QuickLogScreen(pet: s.pets.firstWhere((p) => p.name == 'Bean'))));
    await shot(t, '17-quick-log-all-some-none');
    await t.scrollUntilVisible(find.text('Add a note (optional)'), 200, scrollable: find.byType(Scrollable).last);
    await shot(t, '17b-quick-log-weight-note');
    nav.pop();
    s.selectPet(pepper.id);
    s.goToTab(3);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Weight'), 200, scrollable: find.byType(Scrollable).first);
    await shot(t, '18-insights-weight');
    s.selectPet(bean.id);
    await t.pumpAndSettle();
    await shot(t, '19-insights-getting-to-know');
    nav.push(MaterialPageRoute(builder: (_) => PetDetailScreen(petId: pepper.id)));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.textContaining('What is typical'), 200, scrollable: find.byType(Scrollable).last);
    await shot(t, '20-pet-page-starter');
  });

  testWidgets('quick log from the widget: short form and confirmation', (t) async {
    await setUp(t);
    final s = await state();
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await t.pumpAndSettle();
    navigatorKey.currentState!.pushNamed('/log');
    await shot(t, '21-short-log');
    await t.tap(find.bySemanticsLabel(RegExp('^All normal for')));
    await shot(t, '22-short-log-logged');
    await t.pump(const Duration(seconds: 11));
  });

  testWidgets('test this phone', (t) async {
    await setUp(t);
    final s = await state();
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await t.pumpAndSettle();
    navigatorKey.currentState!.push(MaterialPageRoute(
        builder: (_) => SpeedTestScreen(
              clips: [
                SpeedClip('Dog clip', Species.dog, () async => 'a.mp4'),
                SpeedClip('Cat clip', Species.cat, () async => 'b.mp4'),
                SpeedClip('Dog clip again', Species.dog, () async => 'a.mp4'),
              ],
              device: const {'platform': 'ios', 'device': 'iPhone 15 Pro', 'os': 'iOS 27.2'},
            )));
    await shot(t, '23-test-this-phone');
    await t.tap(find.text('Start the test'));
    await shot(t, '24-test-this-phone-result');
  });

  testWidgets('settings: quick log doors', (t) async {
    await setUp(t);
    final s = await state();
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await t.pumpAndSettle();
    navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Quick log'), 100, scrollable: find.byType(Scrollable).last);
    await shot(t, '25-settings-quick-log');
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
    await t.scrollUntilVisible(find.text('Extra daily questions (optional)'), 300, scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await expectLater(find.byType(PetEditScreen), matchesGoldenFile('out/16b-pet-edit-more.png'));
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
