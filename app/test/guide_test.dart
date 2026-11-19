import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/detection/change_detector.dart';
import 'package:mypet/models/care_entry.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/state/demo_data.dart';
import 'package:mypet/ui/app.dart';
import 'package:mypet/ui/feedback.dart';

import 'app_flow_test.dart' show settle, signedInState;
import 'behaviour_test.dart' show FakeEngine, bark, phoneSize;

void main() {
  Feel.sounds = false;

  testWidgets('first run: Pip shows each tab once, then never again', (t) async {
    final s = await signedInState();
    await s.addPet(name: 'Milo', species: Species.dog);
    s.tourSeen = false;
    var remembered = false;
    s.onTourSeen = () => remembered = true;
    phoneSize(t);
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await settle(t);
    expect(find.textContaining("I'm Pip"), findsOneWidget);
    for (var tab = 1; tab <= 4; tab++) {
      await t.tap(find.text('Next'));
      await settle(t);
      expect(s.tab, tab);
    }
    await t.tap(find.text('Done'));
    await settle(t);
    expect(s.guide, isNull);
    expect(s.tourSeen, isTrue);
    expect(remembered, isTrue);
    expect(find.textContaining("I'm Pip"), findsNothing);
  });

  testWidgets('demo: each example pet tells its story on demo data and leaves your pets alone', (t) async {
    final s = await signedInState();
    await s.addPet(name: 'Milo', species: Species.dog);
    phoneSize(t);
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await settle(t);
    await t.tap(find.byTooltip('More').first);
    await settle(t);
    await t.tap(find.text('Try a demo'));
    await settle(t);
    for (final title in ['A dog not feeling well', 'A cat off her food', 'A happy, healthy puppy', 'A new kitten']) {
      expect(find.text(title), findsOneWidget);
    }
    await t.tap(find.text('A dog not feeling well'));
    await settle(t);
    expect(find.textContaining("I'm Biscuit"), findsOneWidget);
    await t.tap(find.text('Next'));
    await settle(t);
    expect(find.textContaining('days for me'), findsOneWidget);
    await t.tap(find.text('Skip'));
    await settle(t);
    // Back on the picker; another pet's story starts from there.
    await t.tap(find.text('A cat off her food'));
    await settle(t);
    expect(find.textContaining("I'm Mochi"), findsOneWidget);
    await t.tap(find.text('Skip'));
    await settle(t);
    expect(find.text('Try a demo'), findsOneWidget);
    expect(s.pets.map((p) => p.name), ['Milo']);
  });

  test('demo pets: Biscuit and Mochi show a change, Pepper does not, Bean is still learning', () async {
    final s = await signedInState();
    await addDemoPets(s, fixedIds: true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    Pet pet(String n) => s.pets.firstWhere((p) => p.name == n);
    expect(s.detectionOf(pet('Biscuit').id)!.flags.map((f) => f.measure), contains(Measure.energy));
    expect(s.detectionOf(pet('Mochi').id)!.flags.map((f) => f.measure), contains(Measure.ate));
    expect(s.detectionOf(pet('Pepper').id)!.flags, isEmpty);
    expect(s.detectionOf(pet('Bean').id)!.ready, isFalse);
    expect(s.timelineOf(pet('Bean').id).ofKind(EntryKind.behaviourResult), hasLength(1));
  });
}
