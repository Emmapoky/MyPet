import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/models/pet.dart';
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

  testWidgets("story: Biscuit's week runs on demo data and leaves your pets alone", (t) async {
    final s = await signedInState();
    await s.addPet(name: 'Milo', species: Species.dog);
    phoneSize(t);
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await settle(t);
    await t.tap(find.byTooltip('More').first);
    await settle(t);
    await t.tap(find.text("Story: Biscuit's week"));
    await settle(t);
    expect(find.textContaining("I'm Biscuit"), findsOneWidget);
    await t.tap(find.text('Next'));
    await settle(t);
    expect(find.textContaining('days for me'), findsOneWidget);
    await t.tap(find.text('Skip'));
    await settle(t);
    expect(find.textContaining('Biscuit'), findsNothing);
    expect(s.pets.map((p) => p.name), ['Milo']);
  });
}
