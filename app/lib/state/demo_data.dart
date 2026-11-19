import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../behaviour/analysis.dart';
import '../detection/synthetic_logs.dart';
import '../models/care_entry.dart';
import '../models/pet.dart';
import '../models/reminder.dart';
import '../util/day.dart';
import 'app_state.dart';

/// One example pet for the demo (stack plan section 7: seeded pets with planted changes).
class DemoPet {
  const DemoPet({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.weightKg,
    required this.seed,
    required this.title,
    required this.subtitle,
    this.days = 30,
    this.lowEnergy = false,
    this.offFood = false,
    this.checks = const [],
  });

  /// Fixed id in the demo, so its drawing is the same on the picker and in the app.
  final String id;
  final String name;
  final Species species;
  final String breed;
  final double weightKg;
  final int seed;

  /// The demo's name on the picker, and one line on what it shows.
  final String title, subtitle;

  /// Days of logs, ending today.
  final int days;

  /// Energy 1 on 2 of the last 3 days (Insights flags it).
  final bool lowEnergy;

  /// Did not eat on 2 of the last 3 days (Insights flags it).
  final bool offFood;
  final List<DemoCheck> checks;

  Pet get pet => Pet(id: id, name: name, species: species, breed: breed, carerIds: const [], createdAt: DateTime(2026));
}

/// A saved check on a demo pet, with a real clip when one is bundled in assets/demo_clips.
class DemoCheck {
  const DemoCheck(this.daysAgo, this.result, {this.clip});
  final int daysAgo;
  final CheckOutcome result;

  /// Clip file in assets/demo_clips (free-licence videos from Wikimedia Commons).
  final String? clip;
}

CheckOutcome _dog(List<(String, double)> feelings, List<(String, double)> sounds, List<Moment> moments,
        {double seconds = 8}) =>
    CheckOutcome(
      kind: feelings.first.$2 >= Analysis.unsureBelow ? OutcomeKind.feeling : OutcomeKind.notSure,
      species: Species.dog,
      feelings: feelings,
      sounds: sounds,
      picture: PictureUse.combined,
      moments: moments,
      seconds: seconds,
    );

CheckOutcome _cat(List<(String, double)> feelings, List<(String, double)> sounds, List<Moment> moments,
        {double seconds = 8}) =>
    CheckOutcome(
      kind: feelings.isEmpty
          ? OutcomeKind.heardOnly
          : feelings.first.$2 >= Analysis.unsureBelow
              ? OutcomeKind.feeling
              : OutcomeKind.notSure,
      species: Species.cat,
      feelings: feelings,
      sounds: sounds,
      picture: PictureUse.confirmed,
      moments: moments,
      seconds: seconds,
    );

Moment _s(String label, double a, double b, double p) => Moment(MomentSource.sound, label, a, b, p: p);
Moment _p(String label, double a, double b, double p) => Moment(MomentSource.picture, label, a, b, p: p);

/// The demo pets. Each tells its own story; all of them are loaded together.
final demoPets = <DemoPet>[
  DemoPet(
    id: 'demo-biscuit',
    name: 'Biscuit',
    species: Species.dog,
    breed: 'Shiba Inu',
    weightKg: 10.5,
    seed: 7,
    title: 'A dog not feeling well',
    subtitle: 'Biscuit has had low energy this week',
    lowEnergy: true,
    checks: [
      DemoCheck(
        1,
        _dog([('Likely sad or uneasy', 0.64), ('Likely calm', 0.17), ('Likely upset', 0.12), ('Likely happy or playful', 0.07)],
            [('Whimpering', 0.71), ('Howling', 0.12), ('Barking', 0.08)],
            [_p('Dog in view', 0, 8, 0.94), _s('Whimpering', 1, 3, 0.71), _s('Whimpering', 5, 7, 0.64), _p('Lying down', 3, 6, 0.58)]),
        clip: 'dog_whimper_1.mp4',
      ),
      DemoCheck(
        12,
        _dog([('Likely happy or playful', 0.81), ('Likely calm', 0.1), ('Likely upset', 0.06), ('Likely sad or uneasy', 0.03)],
            [('Barking', 0.77), ('Growling', 0.09), ('Whimpering', 0.05)],
            [_p('Dog in view', 0, 8, 0.96), _s('Barking', 0, 2, 0.77), _s('Barking', 4, 6, 0.72), _p('Playful', 2, 5, 0.66)]),
        clip: 'dog_playful_1.mp4',
      ),
    ],
  ),
  DemoPet(
    id: 'demo-mochi',
    name: 'Mochi',
    species: Species.cat,
    breed: 'Domestic shorthair',
    weightKg: 4.2,
    seed: 11,
    title: 'A cat off her food',
    subtitle: 'Mochi left her dinner twice this week',
    offFood: true,
    checks: [
      DemoCheck(
        2,
        _cat([('Likely stressed in a strange place', 0.58), ('Likely reacting to handling', 0.29), ('Likely hungry', 0.13)],
            [('Hissing', 0.74), ('Meowing', 0.14), ('Purring', 0.04)],
            [_p('Cat in view', 0, 7, 0.92), _s('Hissing', 2, 4, 0.74), _s('Meowing', 5, 6, 0.41)], seconds: 7),
        clip: 'cat_hiss_1.mp4',
      ),
      DemoCheck(
        9,
        _cat(const [], [('Purring', 0.82), ('Meowing', 0.08), ('Hissing', 0.02)],
            [_p('Cat in view', 0, 8, 0.95), _s('Purring', 0, 8, 0.82)]),
        clip: 'cat_purr_1.mp4',
      ),
    ],
  ),
  DemoPet(
    id: 'demo-pepper',
    name: 'Pepper',
    species: Species.dog,
    breed: 'Border Collie',
    weightKg: 6.0,
    seed: 23,
    title: 'A happy, healthy puppy',
    subtitle: 'What a normal month looks like',
    checks: [
      DemoCheck(
        2,
        _dog([('Likely happy or playful', 0.86), ('Likely calm', 0.07), ('Likely upset', 0.05), ('Likely sad or uneasy', 0.02)],
            [('Barking', 0.83), ('Growling', 0.06), ('Whimpering', 0.03)],
            [_p('Dog in view', 0, 8, 0.97), _s('Barking', 1, 2, 0.83), _s('Barking', 3, 5, 0.79), _s('Barking', 6, 7, 0.7), _p('Playful', 1, 6, 0.71)]),
        clip: 'dog_bark_1.mp4',
      ),
      DemoCheck(
        6,
        _dog([('Likely calm', 0.72), ('Likely happy or playful', 0.18), ('Likely sad or uneasy', 0.06), ('Likely upset', 0.04)],
            [('Panting', 0.44), ('Barking', 0.1), ('Whimpering', 0.05)],
            [_p('Dog in view', 0, 8, 0.95), _p('Calm', 2, 8, 0.69), _s('Panting', 3, 6, 0.44)]),
        clip: 'dog_calm_1.mp4',
      ),
    ],
  ),
  DemoPet(
    id: 'demo-bean',
    name: 'Bean',
    species: Species.cat,
    breed: 'Ragdoll kitten',
    weightKg: 1.1,
    seed: 31,
    title: 'A new kitten',
    subtitle: 'Bean came home 4 days ago, so MyPet is still learning',
    days: 4,
    checks: [
      DemoCheck(
        1,
        _cat([('Likely hungry', 0.66), ('Likely reacting to handling', 0.2), ('Likely stressed in a strange place', 0.14)],
            [('Meowing', 0.79), ('Purring', 0.07), ('Hissing', 0.02)],
            [_p('Cat in view', 0, 6, 0.9), _s('Meowing', 1, 2, 0.79), _s('Meowing', 3, 4, 0.75), _s('Meowing', 5, 6, 0.61)], seconds: 6),
        clip: 'cat_meow_1.mp4',
      ),
    ],
  ),
];

/// Copies the bundled demo clips to a folder the video player can open, and returns it.
/// Null when no clips are bundled (or in tests), so the demo checks show their moments only.
Future<String?> unpackDemoClips() async {
  // Widget tests run on fake time, where file reads never finish.
  if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
  try {
    final dir = Directory('${Directory.systemTemp.path}/mypet_demo_clips');
    await dir.create(recursive: true);
    var any = false;
    for (final c in demoPets.expand((p) => p.checks)) {
      final name = c.clip;
      if (name == null) continue;
      final f = File('${dir.path}/$name');
      if (!await f.exists()) {
        try {
          final b = await rootBundle.load('assets/demo_clips/$name');
          await f.writeAsBytes(b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes));
        } catch (_) {
          continue;
        }
      }
      any = true;
    }
    return any ? dir.path : null;
  } catch (_) {
    return null;
  }
}

/// Adds the demo pets with their made-up logs, reminders and checks. [fixedIds] gives
/// them the ids above (used by the demo, which runs on its own data); otherwise they get
/// new ids, so adding them to a real account twice does not clash.
Future<void> addDemoPets(AppState s, {bool fixedIds = false, String? clipDir}) async {
  final today = s.today;
  for (final d in demoPets) {
    final first = today.addDays(1 - d.days);
    final pet = await s.addPet(
        id: fixedIds ? d.id : null, name: d.name, species: d.species, breed: d.breed, weightKg: d.weightKg);
    final id = pet.id;
    await _logs(s, d, id, first, today);
    await _breakfast(s, d, id, first);
    for (final c in d.checks) {
      final day = today.addDays(-c.daysAgo);
      final data = c.result.toEntryData(ms: 900, source: 'recording');
      final clip = c.clip;
      if (clip != null && clipDir != null && File('$clipDir/$clip').existsSync()) data['clip'] = clip;
      await s.backend.addEntry(CareEntry(
        id: s.backend.newId(),
        petId: id,
        kind: EntryKind.behaviourResult,
        day: day,
        createdAt: day.asDateTime.add(const Duration(hours: 18, minutes: 30)),
        createdBy: s.carer!.id,
        data: data,
      ));
    }
  }
}

Future<void> _logs(AppState s, DemoPet d, String id, Day first, Day today) async {
  // History before the last 3 days is made up; the last 3 are written out so the demo
  // always shows the same thing.
  final history = d.days > 3 ? SyntheticLogs(d.seed).pet(petId: id, first: first, days: d.days - 3, logRate: d.days < 7 ? 1 : 0.9) : <CareEntry>[];
  final last = [
    for (var i = 0; i < 3; i++)
      (
        today.addDays(i - 2),
        {
          'ate': !(d.offFood && i != 1),
          'energy': d.lowEnergy && i != 1 ? 1 : 4,
          'toiletingNormal': true,
        }
      ),
  ];
  for (final e in [for (final h in history) (h.day, h.data), ...last.where((l) => !l.$1.isBefore(first))]) {
    final day = e.$1;
    await s.backend.addEntry(CareEntry(
      id: s.backend.newId(),
      petId: id,
      kind: EntryKind.dailyLog,
      day: day,
      createdAt: day.asDateTime.add(const Duration(hours: 19)),
      createdBy: s.carer!.id,
      data: e.$2,
    ));
  }
}

Future<void> _breakfast(AppState s, DemoPet d, String id, Day first) async {
  final breakfast = Reminder(
    id: s.backend.newId(),
    petId: id,
    title: 'Breakfast',
    kind: ReminderKind.feeding,
    start: first,
    times: const [8 * 60],
  );
  await s.saveReminder(breakfast);
  // Ticked off on every day but one, so Today shows a single missed item.
  for (var i = 0; i < d.days; i++) {
    if (i == d.days - 4) continue;
    final day = first.addDays(i);
    final at = DateTime(day.year, day.month, day.dayOfMonth, 8);
    await s.backend.addEntry(CareEntry(
      id: s.backend.newId(),
      petId: id,
      kind: EntryKind.taskDone,
      day: day,
      createdAt: at.add(const Duration(minutes: 5)),
      createdBy: s.carer!.id,
      data: {'reminderId': breakfast.id, 'occurrence': at.toIso8601String(), 'title': 'Breakfast'},
    ));
  }
}
