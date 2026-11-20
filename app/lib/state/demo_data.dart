import 'dart:convert';
import '../util/io.dart';

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
    this.ageDays,
    this.neutered,
    this.portion = '',
    this.meals,
    this.gainPerDay = 0,
  });

  /// Age today, in days, so the starter guide and growth mode have something to go on.
  final int? ageDays;
  final bool? neutered;
  final String portion;
  final int? meals;

  /// Growing pets put on weight every day (Pepper); grown pets stay steady.
  final double gainPerDay;

  /// Weight on a day this many days before today.
  double weightOn(int daysAgo) => double.parse((weightKg - gainPerDay * daysAgo).toStringAsFixed(2));

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

/// A saved check on a demo pet. When a real clip for its [slot] is bundled in
/// assets/demo_clips, the clip and the check's real answer on it are used instead of [result].
class DemoCheck {
  const DemoCheck(this.daysAgo, this.result, {required this.slot});
  final int daysAgo;
  final CheckOutcome result;

  /// Kind of clip wanted, as in clips.json: dog_bark, dog_whimper, dog_calm_or_playful,
  /// cat_meow, cat_purr, cat_hiss or puppy_or_kitten.
  final String slot;
}

/// One bundled demo clip (ml/tool/make_demo_clips.py): a cut of a free-licence Commons video
/// and what the check says on it.
class DemoClip {
  DemoClip(this.json);
  final Map<String, dynamic> json;
  String get file => json['file'] as String;
  String get slot => json['slot'] as String;
  String get credit => '${json['title']}, ${json['author']}, ${json['licence']}';
  String get page => json['page'] as String? ?? '';

  /// The check's answer on this clip, as the app would show it.
  CheckOutcome get result {
    final r = json['result'] as Map<String, dynamic>;
    final species = json['species'] == 'cat' ? Species.cat : Species.dog;
    final sounds = [
      for (final t in (r['top_sounds'] as List? ?? const []))
        ((t['name'] as String), (t['p'] as num).toDouble()),
    ];
    final topKey = ((r['top_sounds'] as List?)?.firstOrNull as Map?)?['key'];
    final all = r['feelings'] as Map?;
    final feelings = all != null
        ? ([for (final e in all.entries) (e.key as String, (e.value as num).toDouble())]..sort((a, b) => b.$2.compareTo(a.$2)))
        : [(r['feeling_name'] as String, (r['p'] as num).toDouble())];
    final heardOnly = species == Species.cat && topKey != 'cat_meow';
    // The same moments the phone would show: this pet's own sounds at 40% or more, and the
    // seconds the picture showed the pet.
    final own = species == Species.cat ? _catSounds : _dogSounds;
    final petInView = species == Species.cat ? 'Cat in view' : 'Dog in view';
    final moments = mergeMoments([
      for (final m in (json['moments'] as List? ?? const []))
        if (((m['p'] as num?) ?? 0) >= 0.4)
          if (m['src'] == 'picture')
            if (m['label'] == 'a ${species.name}' || m['label'] == petInView)
              Moment(MomentSource.picture, petInView, (m['s'] as num).toDouble(), (m['e'] as num).toDouble(),
                  p: (m['p'] as num).toDouble())
            else
              ...[]
          else if (own.contains(m['label']))
            Moment(MomentSource.sound, m['label'] as String, (m['s'] as num).toDouble(), (m['e'] as num).toDouble(),
                p: (m['p'] as num).toDouble()),
    ]);
    return CheckOutcome(
      kind: heardOnly
          ? OutcomeKind.heardOnly
          : feelings.first.$2 >= Analysis.unsureBelow
              ? OutcomeKind.feeling
              : OutcomeKind.notSure,
      species: species,
      feelings: heardOnly ? const [] : feelings,
      sounds: sounds,
      picture: species == Species.dog ? PictureUse.combined : PictureUse.confirmed,
      moments: moments,
      seconds: (json['seconds'] as num?)?.toDouble() ?? 8,
    );
  }
}

const _dogSounds = {'Barking', 'Whimpering', 'Whining', 'Howling', 'Growling', 'Panting'};
const _catSounds = {'Meowing', 'Purring', 'Hissing', 'Yowling', 'Growling', 'Chirping'};

/// The bundled demo clips, or none (no clips.json, or in tests).
Future<List<DemoClip>> loadDemoClips() async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return const [];
  try {
    final j = jsonDecode(await rootBundle.loadString('assets/demo_clips/clips.json')) as Map<String, dynamic>;
    return [for (final c in j['clips'] as List) DemoClip(c as Map<String, dynamic>)];
  } catch (_) {
    return const [];
  }
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
    ageDays: 5 * 365 + 40,
    neutered: true,
    portion: '120 g dry food',
    meals: 2,
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
        slot: 'dog_whimper',
      ),
      DemoCheck(
        12,
        _dog([('Likely happy or playful', 0.81), ('Likely calm', 0.1), ('Likely upset', 0.06), ('Likely sad or uneasy', 0.03)],
            [('Barking', 0.77), ('Growling', 0.09), ('Whimpering', 0.05)],
            [_p('Dog in view', 0, 8, 0.96), _s('Barking', 0, 2, 0.77), _s('Barking', 4, 6, 0.72), _p('Playful', 2, 5, 0.66)]),
        slot: 'dog_calm_or_playful',
      ),
      DemoCheck(
        20,
        _dog([('Likely upset', 0.57), ('Likely happy or playful', 0.24), ('Likely calm', 0.12), ('Likely sad or uneasy', 0.07)],
            [('Barking', 0.83), ('Growling', 0.14), ('Whimpering', 0.02)],
            [_p('Dog in view', 0, 8, 0.9), _s('Barking', 0, 8, 0.84)]),
        slot: 'dog_bark',
      ),
    ],
  ),
  DemoPet(
    id: 'demo-mochi',
    name: 'Mochi',
    species: Species.cat,
    breed: 'Domestic shorthair',
    weightKg: 4.2,
    ageDays: 6 * 365 + 100,
    neutered: true,
    portion: 'Half a can and 30 g dry',
    meals: 2,
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
        slot: 'cat_hiss',
      ),
      DemoCheck(
        9,
        _cat(const [], [('Purring', 0.82), ('Meowing', 0.08), ('Hissing', 0.02)],
            [_p('Cat in view', 0, 8, 0.95), _s('Purring', 0, 8, 0.82)]),
        slot: 'cat_purr',
      ),
    ],
  ),
  DemoPet(
    id: 'demo-pepper',
    name: 'Pepper',
    species: Species.dog,
    breed: 'Border Collie',
    weightKg: 7.6,
    ageDays: 129,
    neutered: false,
    portion: '1 cup puppy food',
    meals: 3,
    gainPerDay: 0.11,
    seed: 23,
    title: 'A happy, healthy puppy',
    subtitle: 'What a normal month looks like',
    checks: [
      DemoCheck(
        2,
        _dog([('Likely happy or playful', 0.86), ('Likely calm', 0.07), ('Likely upset', 0.05), ('Likely sad or uneasy', 0.02)],
            [('Barking', 0.83), ('Growling', 0.06), ('Whimpering', 0.03)],
            [_p('Dog in view', 0, 8, 0.97), _s('Barking', 1, 2, 0.83), _s('Barking', 3, 5, 0.79), _s('Barking', 6, 7, 0.7), _p('Playful', 1, 6, 0.71)]),
        slot: 'dog_bark',
      ),
      DemoCheck(
        6,
        _dog([('Likely calm', 0.72), ('Likely happy or playful', 0.18), ('Likely sad or uneasy', 0.06), ('Likely upset', 0.04)],
            [('Panting', 0.44), ('Barking', 0.1), ('Whimpering', 0.05)],
            [_p('Dog in view', 0, 8, 0.95), _p('Calm', 2, 8, 0.69), _s('Panting', 3, 6, 0.44)]),
        slot: 'dog_calm_or_playful',
      ),
      DemoCheck(
        10,
        _dog([('Likely upset', 0.55), ('Likely happy or playful', 0.25), ('Likely calm', 0.13), ('Likely sad or uneasy', 0.07)],
            [('Barking', 0.69), ('Whimpering', 0.19), ('Growling', 0.07)],
            [_p('Dog in view', 3, 8, 0.95), _s('Barking', 2, 4, 0.74), _s('Whimpering', 4, 5, 0.43)]),
        slot: 'dog_bark',
      ),
    ],
  ),
  DemoPet(
    id: 'demo-bean',
    name: 'Bean',
    species: Species.cat,
    breed: 'Ragdoll kitten',
    weightKg: 1.1,
    ageDays: 72,
    portion: '1 kitten pouch',
    meals: 4,
    gainPerDay: 0.015,
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
        slot: 'cat_meow',
      ),
      DemoCheck(
        3,
        _cat([('Likely stressed in a strange place', 0.85), ('Likely hungry', 0.1), ('Likely reacting to handling', 0.05)],
            [('Meowing', 0.55), ('Yowling', 0.34), ('Whimpering', 0.05)],
            [_p('Cat in view', 0, 8, 0.85), _s('Meowing', 6, 8, 0.61)]),
        slot: 'cat_meow',
      ),
    ],
  ),
];

/// Copies the bundled demo clips to a folder the video player can open, and returns it.
/// Null when none could be copied, so the demo checks show their moments only.
Future<String?> unpackDemoClips(List<DemoClip> clips) async {
  if (clips.isEmpty) return null;
  try {
    final dir = Directory('${Directory.systemTemp.path}/mypet_demo_clips');
    await dir.create(recursive: true);
    for (final c in clips) {
      final f = File('${dir.path}/${c.file}');
      if (await f.exists()) continue;
      final b = await rootBundle.load('assets/demo_clips/${c.file}');
      await f.writeAsBytes(b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes));
    }
    return dir.path;
  } catch (_) {
    return null;
  }
}

/// Adds the demo pets with their made-up logs, reminders and checks. [fixedIds] gives
/// them the ids above (used by the demo, which runs on its own data); otherwise they get
/// new ids, so adding them to a real account twice does not clash.
Future<void> addDemoPets(AppState s, {bool fixedIds = false, List<DemoClip> clips = const [], String? clipDir}) async {
  final today = s.today;
  // Real clips go to the checks that want their kind, each clip once; a puppy or kitten
  // clip goes to the young pet of its species.
  final left = [...clips];
  DemoClip? take(DemoPet d, String slot) {
    final young = d.breed.contains('kitten') || d.breed.contains('puppy') || d.id == 'demo-pepper';
    final c = left.where((c) => c.slot == slot && c.json['species'] == d.species.name).firstOrNull ??
        (young ? left.where((c) => c.slot == 'puppy_or_kitten' && c.json['species'] == d.species.name).firstOrNull : null);
    if (c != null) left.remove(c);
    return c;
  }

  for (final d in demoPets) {
    final first = today.addDays(1 - d.days);
    final pet = await s.addPet(
        id: fixedIds ? d.id : null,
        name: d.name,
        species: d.species,
        breed: d.breed,
        weightKg: d.weightOn(d.days - 1),
        birthDate: d.ageDays == null ? null : today.addDays(-d.ageDays!));
    await s.updatePet(pet.copyWith(neutered: d.neutered, portion: d.portion, mealsPerDay: d.meals));
    final id = pet.id;
    await _logs(s, d, id, first, today);
    await _breakfast(s, d, id, first);
    for (final c in d.checks) {
      final day = today.addDays(-c.daysAgo);
      final real = clipDir == null ? null : take(d, c.slot);
      final data = (real?.result ?? c.result).toEntryData(ms: 900, source: 'recording');
      if (real != null) {
        data['clip'] = real.file;
        data['credit'] = real.credit;
      }
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
          'ate': !(d.offFood && i == 2),
          // Off food: some on the first day, none on the last (Ate: All / Some / None).
          'ateAmount': !d.offFood || i == 1 ? 'all' : (i == 0 ? 'some' : 'none'),
          'energy': d.lowEnergy && i != 1 ? 1 : 4,
          'toiletingNormal': true,
          if (i == 2) 'weightKg': d.weightOn(0),
        }
      ),
  ];
  // Weigh-ins follow the demo pet's own weight (steady, or growing for the young ones).
  Map<String, dynamic> real(Day day, Map<String, dynamic> data) => {
        ...data,
        'ateAmount': data['ate'] == false ? 'none' : 'all',
        if (data['weightKg'] != null) 'weightKg': d.weightOn(today.difference(day)),
      };
  for (final e in [for (final h in history) (h.day, real(h.day, h.data)), ...last.where((l) => !l.$1.isBefore(first))]) {
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
