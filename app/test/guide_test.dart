import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/detection/change_detector.dart';
import 'package:mypet/behaviour/analysis.dart';
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
    // The app stays usable under the bubble: switch tabs, then shrink and reopen the guide.
    await t.tap(find.text('Insights'));
    await settle(t);
    await t.tap(find.byTooltip('Tap me to shrink'));
    await settle(t);
    expect(find.textContaining('days for me'), findsNothing);
    await t.tap(find.bySemanticsLabel(RegExp("Open Biscuit's guide")));
    await settle(t);
    expect(find.textContaining('days for me'), findsOneWidget);
    // A pet page opened inside the demo shows the demo pet, not a blank page.
    await t.tap(find.text('Pets').last);
    await settle(t);
    await t.tap(find.text('Biscuit').last);
    await settle(t);
    expect(find.text('Something changed'), findsWidgets);
    await t.tap(find.byTooltip('Leave the demo'));
    await settle(t);
    // Back on the picker; another pet's story starts from there.
    await t.tap(find.text('A cat off her food'));
    await settle(t);
    expect(find.textContaining("I'm Mochi"), findsOneWidget);
    await t.tap(find.byTooltip('Leave the demo'));
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
    expect(s.timelineOf(pet('Bean').id).ofKind(EntryKind.behaviourResult), hasLength(2));
  });

  test('a bundled demo clip becomes a saved check with its real answer and moments', () async {
    final dog = DemoClip({
      'file': 'dog_dog_whimper_01.mp4', 'species': 'dog', 'slot': 'dog_whimper', 'title': 'Sad dog',
      'author': 'A. Person', 'licence': 'CC BY 4.0', 'page': 'https://commons.wikimedia.org/x', 'seconds': 8.0,
      'result': {
        'feeling_name': 'Likely sad or uneasy', 'p': 0.61,
        'feelings': {'Likely sad or uneasy': 0.61, 'Likely calm': 0.2, 'Likely upset': 0.12, 'Likely happy or playful': 0.07},
        'top_sounds': [{'key': 'dog_whimper', 'name': 'Whimpering', 'p': 0.7}],
      },
      'moments': [
        {'src': 'sound', 'label': 'Whimpering', 's': 1, 'e': 2, 'p': 0.7},
        {'src': 'sound', 'label': 'Whimpering', 's': 2, 'e': 3, 'p': 0.6},
        {'src': 'picture', 'label': 'Dog in view', 's': 0, 'e': 1, 'p': 0.9},
      ],
    });
    final o = dog.result;
    expect(o.kind, OutcomeKind.feeling);
    expect(o.feelings, hasLength(4));
    expect(o.moments, hasLength(2)); // the two whimper seconds join up
    expect(dog.credit, 'Sad dog, A. Person, CC BY 4.0');
    final purr = DemoClip({
      ...dog.json,
      'species': 'cat',
      'result': {'feeling_name': 'Likely hungry', 'p': 0.5, 'top_sounds': [{'key': 'cat_purr', 'name': 'Purring', 'p': 0.8}]},
    });
    expect(purr.result.kind, OutcomeKind.heardOnly);

    final s = await signedInState();
    await addDemoPets(s, fixedIds: true, clips: [dog], clipDir: '/tmp/none');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final checks = s.timelineOf('demo-biscuit').ofKind(EntryKind.behaviourResult);
    expect(checks.where((e) => e.data['clip'] == 'dog_dog_whimper_01.mp4'), hasLength(1));
  });

  test('every bundled demo clip lands on one demo check', () async {
    final j = jsonDecode(File('assets/demo_clips/clips.json').readAsStringSync()) as Map<String, dynamic>;
    final clips = [for (final c in j['clips'] as List) DemoClip(c as Map<String, dynamic>)];
    expect(clips, hasLength(10));
    for (final c in clips) {
      expect(File('assets/demo_clips/${c.file}').existsSync(), isTrue, reason: c.file);
      expect(c.json['licence'], startsWith('CC BY'));
      // Only the pet's own sounds and the pet in view, as on the phone.
      for (final m in c.result.moments) {
        expect(m.p, greaterThanOrEqualTo(0.4));
        if (m.source == MomentSource.picture) expect(m.label, endsWith('in view'));
      }
    }
    final s = await signedInState();
    await addDemoPets(s, fixedIds: true, clips: clips, clipDir: '/tmp/none');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final used = [
      for (final p in demoPets)
        for (final e in s.timelineOf(p.id).ofKind(EntryKind.behaviourResult))
          if (e.data['clip'] != null) e.data['clip'],
    ];
    expect(used.toSet(), {for (final c in clips) c.file});
  });
}
