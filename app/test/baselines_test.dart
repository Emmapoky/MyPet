import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/detection/change_detector.dart';
import 'package:mypet/models/care_entry.dart';
import 'package:mypet/models/life_stage.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/util/day.dart';

// The pet owner review's changes to how MyPet knows what is normal (docs/FIT3162 MyPet
// Pet Owner Review and Baselines.md, sections 5 and 7).

final start = Day(2027, 3, 1);
var _n = 0;

CareEntry log(int day, {String ate = 'all', int energy = 4, bool? toilet = true, double? w, Map<String, dynamic> more = const {}, String by = 't', int hour = 18}) =>
    CareEntry(
      id: 'e${_n++}',
      petId: 'p',
      kind: EntryKind.dailyLog,
      day: start.addDays(day),
      createdAt: start.addDays(day).asDateTime.add(Duration(hours: hour)),
      createdBy: by,
      data: {'ate': ate != 'none', 'ateAmount': ate, 'energy': energy, 'toiletingNormal': ?toilet, 'weightKg': ?w, ...more},
    );

CareEntry record(int day, String type, {String title = 'Vaccination', List<String>? measures}) => CareEntry(
      id: 'r${_n++}',
      petId: 'p',
      kind: EntryKind.healthRecord,
      day: start.addDays(day),
      createdAt: start.addDays(day).asDateTime,
      createdBy: 't',
      data: {'type': type, 'title': title, 'measures': ?measures},
    );

void main() {
  const d = ChangeDetector();

  group('change 3: Ate All / Some / None', () {
    test('"some" on 2 of 3 days is flagged for a pet that always finishes', () {
      final e = [for (var i = 0; i < 20; i++) log(i), log(20, ate: 'some'), log(21, ate: 'some')];
      final f = d.run(e, start.addDays(21)).flags.single;
      expect(f.measure, Measure.ate);
      expect(f.recent.map((r) => r.value), [0, 0.5, 0.5]);
    });

    test('a pet that often leaves some is only flagged when it eats none', () {
      final e = [for (var i = 0; i < 20; i++) log(i, ate: i.isEven ? 'some' : 'all')];
      expect(d.run([...e, log(20, ate: 'some'), log(21, ate: 'some')], start.addDays(21)).flags, isEmpty);
      final f = d.run([...e, log(20, ate: 'none'), log(21, ate: 'none')], start.addDays(21)).flags.single;
      expect(f.measure, Measure.ate);
    });
  });

  group('change 4: day-1 facts', () {
    test('did not eat 2 days in a row shows on day 2', () {
      final r = d.run([log(0, ate: 'none'), log(1, ate: 'none')], start.addDays(1));
      expect(r.ready, isFalse);
      expect(r.flags.single.confidence, Confidence.fact);
      expect(r.flags.single.measure, Measure.ate);
    });

    test('one bad day, or a gap, is not two days running', () {
      expect(d.run([log(0, ate: 'none'), log(1)], start.addDays(1)).flags, isEmpty);
      expect(d.run([log(0, ate: 'none'), log(2, ate: 'none')], start.addDays(2)).flags, isEmpty);
    });
  });

  group('change 7: vet days and "Something changed"', () {
    test('quiet days after a vaccination are left out of the baseline and noted', () {
      final e = [
        for (var i = 0; i < 20; i++) log(i, energy: (i >= 10 && i <= 12) ? 1 : 4),
        record(10, 'vaccination'),
        log(20, energy: 2),
        log(21, energy: 2),
      ];
      final f = d.run(e, start.addDays(21)).flags.single;
      expect(f.usual, 4);
      expect(f.baselineLoggedDays, 16);
    });

    test('a flag within 2 days of a vet visit says so', () {
      final e = [for (var i = 0; i < 20; i++) log(i), record(20, 'vetVisit', title: 'Vet visit'), log(20, energy: 1), log(21, energy: 1)];
      final f = d.run(e, start.addDays(21)).flags.firstWhere((f) => f.measure == Measure.energy);
      expect(f.notes.single.title, 'Vet visit');
      expect(f.notes.single.fresh, isFalse);
    });

    test('"Something changed" starts a fresh baseline for that measure', () {
      final e = [
        for (var i = 0; i < 20; i++) log(i, energy: i < 12 ? 5 : 3),
        record(12, 'change', title: 'New home', measures: ['energy']),
        log(20, energy: 3),
        log(21, energy: 3),
      ];
      expect(d.run(e, start.addDays(21)).flags, isEmpty);
      // Without the tag, the old usual of 5 would make 3 look low.
      final without = e.where((x) => x.kind == EntryKind.dailyLog).toList();
      expect(d.run(without, start.addDays(21)).flags, isNotEmpty);
    });
  });

  group('change 1 and 6: weight as a trend', () {
    test('slow loss over a month is caught though no single day drops much', () {
      // A senior cat losing about 0.2 kg a week: 4.6 kg down to 4.0 kg.
      final e = [for (var i = 0; i <= 28; i++) log(i, w: i % 4 == 0 ? 4.6 - i * 0.021 : null)];
      final f = d.run(e, start.addDays(28)).flags.single;
      expect(f.measure, Measure.weight);
      expect(f.trend!.kind, WeightKind.drift);
      expect(f.up, isFalse);
    });

    test('a growing puppy gaining weight every week is not flagged', () {
      final e = [for (var i = 0; i <= 28; i += 7) log(i, w: 6 + i * 0.1)];
      expect(d.run(e, start.addDays(28), pet: const PetFacts(growing: true)).flags, isEmpty);
    });

    test('a growing puppy that stops gaining for 2 weeks is noted', () {
      final e = [log(0, w: 6), log(7, w: 6.7), log(14, w: 7.4), log(21, w: 7.4), log(28, w: 7.4)];
      final f = d.run(e, start.addDays(28), pet: const PetFacts(growing: true)).flags.single;
      expect(f.trend!.kind, WeightKind.stall);
    });

    test('a 60 kg dog on a bathroom scale is not flagged for 0.5 kg of noise', () {
      final e = [for (var i = 0; i <= 28; i += 4) log(i, w: 60 + (i % 8 == 0 ? 0.5 : -0.5))];
      expect(d.run(e, start.addDays(28)).flags, isEmpty);
    });
  });

  group('change 9: household', () {
    test('a "None" from one carer is kept when another logs "All" later', () {
      final e = [
        for (var i = 0; i < 20; i++) log(i),
        log(20, ate: 'none', by: 'a', hour: 8),
        log(20, ate: 'all', by: 'b', hour: 20),
        log(21, ate: 'none'),
      ];
      expect(d.run(e, start.addDays(21)).flags.single.measure, Measure.ate);
    });
  });

  group('change 10: extra checks', () {
    test('drinking more on 2 of 3 days is flagged when it is rare', () {
      final e = [
        for (var i = 0; i < 20; i++) log(i, more: {'drinkingMore': false}),
        log(20, more: {'drinkingMore': true}),
        log(21, more: {'drinkingMore': true}),
      ];
      expect(d.run(e, start.addDays(21)).flags.single.measure, Measure.drinking);
    });
  });

  group('change 5 and 6: life stage from the profile', () {
    Pet pet(Species sp, Day? born, {String breed = '', double? kg, bool? neutered}) =>
        Pet(id: 'x', name: 'X', species: sp, breed: breed, birthDate: born, weightKg: kg, neutered: neutered, carerIds: const [], createdAt: DateTime(2027));
    final now = Day(2027, 6, 1);

    test('a 5-month Labrador is growing and young; a 10-year Great Dane is senior', () {
      final lab = lifeStageOf(pet(Species.dog, Day(2027, 1, 1), breed: 'Labrador'), now);
      expect(lab.size, SizeClass.large);
      expect(lab.growing, isTrue);
      expect(lab.young, isTrue);
      expect(lifeStageOf(pet(Species.dog, Day(2017, 1, 1), breed: 'Great Dane'), now).senior, isTrue);
      expect(lifeStageOf(pet(Species.cat, Day(2020, 1, 1)), now).stage, LifeStage.adult);
    });

    test('energy guide: 4 kg neutered cat about 240 to 280 kcal (AAHA RER x 1.2 to 1.4)', () {
      final (lo, hi) = dailyEnergyNeed(pet(Species.cat, Day(2020, 1, 1), kg: 4, neutered: true), now)!;
      expect(lo, inInclusiveRange(230, 250));
      expect(hi, inInclusiveRange(270, 290));
    });
  });
}
