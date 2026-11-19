import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/detection/change_detector.dart';
import 'package:mypet/detection/synthetic_logs.dart';
import 'package:mypet/util/day.dart';

/// Report Table 3.2, FR13 and FR14: at least 80% of injected changes are flagged within
/// 7 days of onset, and no flag appears before 7 days of logs (NFR07).
void main() {
  test('synthetic evaluation: hit rate, false flags and the 7-day rule', () {
    const detector = ChangeDetector();
    final first = Day(2027, 1, 1);
    const days = 60;
    const petsPerGroup = 300;
    final measures = [Measure.ate, Measure.energy, Measure.toileting];
    final rng = math.Random(2027);

    var hits = 0,
        planted = 0,
        falseBefore = 0,
        controlFalse = 0,
        earlyFlags = 0;
    final hitsBy = {for (final m in measures) m: 0};
    final plantedBy = {for (final m in measures) m: 0};
    final delays = <int>[];
    var controlPetDays = 0;
    final controlPetsFlagged = <int>{};
    final falseBy = <String, int>{};

    for (var p = 0; p < petsPerGroup * 2; p++) {
      final changedPet = p < petsPerGroup;
      final change = changedPet
          ? PlantedChange(measures[p % 3], first.addDays(30 + rng.nextInt(21)))
          : null;
      final entries = SyntheticLogs(p)
          .pet(petId: 'pet$p', first: first, days: days, change: change);
      final loggedBefore = <Day>{};
      int? firstHit;
      for (var i = 0; i < days; i++) {
        final d = first.addDays(i);
        if (entries.any((e) => e.day == d)) loggedBefore.add(d);
        final r = detector.run(entries, d);
        if (loggedBefore.length < 7 && r.flags.isNotEmpty) earlyFlags++;
        if (!changedPet) {
          controlPetDays++;
          if (r.flags.isNotEmpty) {
            controlFalse++;
            controlPetsFlagged.add(p);
            for (final f in r.flags) {
              falseBy[f.measure.name] = (falseBy[f.measure.name] ?? 0) + 1;
            }
          }
          continue;
        }
        if (d.isBefore(change!.onset)) {
          if (r.flags.isNotEmpty) falseBefore++;
        } else if (firstHit == null &&
            d.difference(change.onset) < 7 &&
            r.flags.any((f) => f.measure == change.measure)) {
          firstHit = d.difference(change.onset);
        }
      }
      if (changedPet) {
        planted++;
        plantedBy[change!.measure] = plantedBy[change.measure]! + 1;
        if (firstHit != null) {
          hits++;
          hitsBy[change.measure] = hitsBy[change.measure]! + 1;
          delays.add(firstHit);
        }
      }
    }

    delays.sort();
    final result = {
      'pets_with_change': planted,
      'flagged_within_7_days': hits,
      'hit_rate': hits / planted,
      'hit_rate_by_measure': {
        for (final m in measures) m.name: hitsBy[m]! / plantedBy[m]!,
      },
      'median_days_to_flag': delays.isEmpty ? null : delays[delays.length ~/ 2],
      'control_pet_days': controlPetDays,
      'control_days_with_a_flag': controlFalse,
      'control_pets_ever_flagged': controlPetsFlagged.length,
      'control_flag_days_by_measure': falseBy,
      'false_flag_days_before_onset': falseBefore,
      'flags_before_7_logged_days': earlyFlags,
    };
    final out = File('test/results/synthetic_evaluation.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(result));

    expect(earlyFlags, 0);
    expect(hits / planted, greaterThanOrEqualTo(0.8));
  });
}
