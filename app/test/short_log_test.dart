import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mypet/models/care_entry.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/state/app_state.dart';
import 'package:mypet/ui/app.dart';
import 'package:mypet/ui/feedback.dart';
import 'package:mypet/ui/short_log_screen.dart';

import 'app_flow_test.dart' show settle, signedInState;
import 'behaviour_test.dart' show FakeEngine, bark, phoneSize;

void main() {
  Feel.sounds = false;

  test('widget links open the short form, other links do not', () {
    expect(shortLogRoute(const RouteSettings(name: '/log?pet=p1')), isNotNull);
    expect(shortLogRoute(const RouteSettings(name: 'mypet://log')), isNotNull);
    expect(shortLogRoute(const RouteSettings(name: '/')), isNull);
    expect(shortLogRoute(const RouteSettings(name: '/other')), isNull);
  });

  test('energy on the short form is judged against the pet\'s own usual', () {
    expect(shortEnergy(4, 'low'), 3);
    expect(shortEnergy(4, 'usual'), 4);
    expect(shortEnergy(4, 'high'), 5);
    expect(shortEnergy(5, 'high'), 5);
    expect(shortEnergy(1, 'low'), 1);
  });

  testWidgets('short form: All normal in one tap, Undo, then the next pet with three rows', (t) async {
    final s = await signedInState();
    await s.addPet(name: 'Biscuit', species: Species.dog);
    await s.addPet(name: 'Mochi', species: Species.cat);
    await settle(t);
    phoneSize(t);
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await settle(t);
    navigatorKey.currentState!.pushNamed('/log');
    await settle(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text("How was Biscuit's day?"), findsOneWidget);

    await t.tap(find.bySemanticsLabel('All normal for Biscuit'));
    await settle(t);
    expect(find.text('Biscuit is logged'), findsOneWidget);
    expect(find.text('Today 1 of 2 done'), findsOneWidget);
    final biscuit = s.activePets.firstWhere((p) => p.name == 'Biscuit');
    expect(s.loggedToday(biscuit.id), isTrue);

    await t.tap(find.textContaining('Undo'));
    await settle(t);
    expect(s.loggedToday(biscuit.id), isFalse);
    expect(find.text("How was Biscuit's day?"), findsOneWidget);

    await t.tap(find.bySemanticsLabel('All normal for Biscuit'));
    await settle(t);
    await t.pump(const Duration(seconds: 11));
    expect(find.textContaining('Undo'), findsNothing);
    await t.tap(find.text('Next: Mochi'));
    await settle(t);
    expect(find.text("How was Mochi's day?"), findsOneWidget);
    expect(find.text('Answer all three to save'), findsOneWidget);
    await t.tap(find.text('Some'));
    await t.tap(find.text('Low'));
    await t.tap(find.text("Didn't see"));
    await settle(t);
    await t.tap(find.text('Save'));
    await settle(t);
    expect(find.text('Mochi is logged'), findsOneWidget);
    expect(find.text('Today 2 of 2 done'), findsOneWidget);
    final mochi = s.activePets.firstWhere((p) => p.name == 'Mochi');
    final e = s.timelineOf(mochi.id).current.firstWhere((e) => e.kind == EntryKind.dailyLog);
    expect(e.ateAmount, 'some');
    expect(e.energy, 2);
    expect(e.toiletingUnseen, isTrue);
    await t.pump(const Duration(seconds: 11));
  });

  testWidgets('a widget link with no pets, or as the only page, still leads back to the app', (t) async {
    final s = await signedInState();
    phoneSize(t);
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await settle(t);
    navigatorKey.currentState!.pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => const ShortLogScreen()), (_) => false);
    await settle(t);
    expect(find.text('No pets yet'), findsOneWidget);
    await t.tap(find.text('Go to MyPet'));
    await settle(t);
    expect(find.text('No pets yet'), findsNothing);
    expect(find.byType(ShortLogScreen), findsNothing);
  });

  testWidgets('with the short form switched off, a widget link opens the full daily log', (t) async {
    final s = await signedInState();
    await s.addPet(name: 'Biscuit', species: Species.dog);
    s.setDoors(s.doors.copyWith(shortForm: false, voice: false));
    phoneSize(t);
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await settle(t);
    navigatorKey.currentState!.pushNamed('/log');
    await settle(t);
    expect(find.text("How was Biscuit's day?"), findsNothing);
    expect(find.text('Ate today'), findsOneWidget);
    expect(find.textContaining('Tell us about'), findsNothing);
    expect(QuickDoors.fromMap(s.doors.toMap()).shortForm, isFalse);
  });
}
