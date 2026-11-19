import 'package:flutter/widgets.dart' show AxisDirection, Offset, Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/ui/feedback.dart';
import 'package:mypet/data/local_backend.dart';
import 'package:mypet/detection/change_detector.dart';
import 'package:mypet/models/care_entry.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/state/app_state.dart';
import 'package:mypet/state/demo_data.dart';
import 'package:mypet/ui/app.dart';
import 'package:mypet/util/day.dart';

final fixedNow = DateTime(2027, 3, 15, 19, 30);

Future<AppState> signedInState() async {
  final b = LocalBackend();
  final s = AppState(b, clock: () => fixedNow, detectInBackground: false);
  await b.signIn('', '');
  return s;
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pumpAndSettle();
}

void main() {
  Feel.sounds = false;
  testWidgets('NFR01: a routine day is logged in 3 taps: Log now, energy, Save', (
    t,
  ) async {
    final s = await signedInState();
    final pet = await s.addPet(name: 'Milo', species: Species.dog);
    await s.addEntry(pet.id, EntryKind.dailyLog, {
      'ate': true,
      'energy': 4,
      'toiletingNormal': true,
    }, day: Day.of(fixedNow).addDays(-1));
    await t.pumpWidget(MyPetApp(state: s));
    await settle(t);

    var taps = 0;
    await t.tap(find.text('Log now'));
    taps++;
    await settle(t);
    expect(find.text('Same as last entry'), findsOneWidget);
    // Ate and toilet carry over; energy is asked fresh so a drop is not hidden.
    await t.tap(find.bySemanticsLabel('Energy: 4'));
    taps++;
    await t.pump();
    await t.tap(find.text('Save'));
    taps++;
    await settle(t);

    expect(taps, lessThanOrEqualTo(3));
    expect(s.loggedToday(pet.id), isTrue);
    final log = s.timelineOf(pet.id).lastDailyLog!;
    expect(log.day, Day.of(fixedNow));
    expect(log.energy, 4);
  });

  testWidgets(
    'first log for a new pet takes 5 taps: Log now, 3 answers, Save',
    (t) async {
      final s = await signedInState();
      final pet = await s.addPet(name: 'Mochi', species: Species.cat);
      await t.pumpWidget(MyPetApp(state: s));
      await settle(t);
      await t.tap(find.text('Log now'));
      await settle(t);
      await t.tap(find.bySemanticsLabel('Ate today: Yes'));
      await t.tap(find.bySemanticsLabel('Energy: 3'));
      await t.tap(find.bySemanticsLabel('Toileting normal: Yes'));
      await t.pump();
      await t.tap(find.text('Save'));
      await settle(t);
      expect(s.loggedToday(pet.id), isTrue);
    },
  );

  testWidgets('NFR07: Insights stay hidden before 7 logged days', (t) async {
    final s = await signedInState();
    final pet = await s.addPet(name: 'Milo', species: Species.dog);
    for (var i = 0; i < 6; i++) {
      await s.addEntry(pet.id, EntryKind.dailyLog, {
        'ate': true,
        'energy': 4,
        'toiletingNormal': true,
      }, day: Day.of(fixedNow).addDays(-i));
    }
    await t.pumpWidget(MyPetApp(state: s));
    await settle(t);
    await t.tap(find.text('Insights'));
    await settle(t);
    expect(find.textContaining('Insights unlock after 7 days'), findsOneWidget);
    expect(find.textContaining('6 of 7 days logged'), findsOneWidget);
  });

  testWidgets(
    'demo pets: Biscuit shows a change with evidence, Mochi does not',
    (t) async {
      final s = await signedInState();
      await addDemoPets(s);
      await t.pumpWidget(MyPetApp(state: s));
      await settle(t);
      final biscuit = s.pets.firstWhere((p) => p.name == 'Biscuit');
      final mochi = s.pets.firstWhere((p) => p.name == 'Mochi');
      expect(
        s.detectionOf(biscuit.id)!.flags.map((f) => f.measure),
        contains(Measure.energy),
      );
      expect(s.detectionOf(mochi.id)!.flags, isEmpty);

      s.selectPet(biscuit.id);
      await t.tap(find.text('Insights'));
      await settle(t);
      expect(
        find.textContaining("Energy lower than Biscuit's usual"),
        findsWidgets,
      );
      expect(find.textContaining('Not a medical diagnosis'), findsWidgets);
    },
  );

  testWidgets('FR12: a reminder not ticked by its time shows as missed', (
    t,
  ) async {
    final s = await signedInState();
    await addDemoPets(s);
    await t.pumpWidget(MyPetApp(state: s));
    await settle(t);
    await t.drag(
      find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
      const Offset(0, -500),
    );
    await settle(t);
    expect(find.textContaining('Missed'), findsWidgets);
  });
}
