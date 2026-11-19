import 'dart:math' as math;

import '../models/care_entry.dart';
import '../util/day.dart';
import 'change_detector.dart';

/// A planted change for testing the detector (report Table 3.2: synthetic logs with known
/// changes added).
class PlantedChange {
  final Measure measure;
  final Day onset;
  const PlantedChange(this.measure, this.onset);
}

/// Makes believable daily logs for one pet, with an optional planted change.
///
/// Assumptions, written down so the team can challenge them:
/// - the carer logs on 90% of days (missed days stay missing);
/// - energy sits at the pet's usual level on 60% of days, 1 point off on 30%, 2 off on 10%;
/// - "ate" and "toileting normal" are "no" on 3% of ordinary days;
/// - weight is logged once a week, within 1% of the usual weight.
/// After the onset of a planted change:
/// - energy: usual level minus 2, with the same day-to-day noise;
/// - eating or toileting: "no" on 80% of days.
class SyntheticLogs {
  SyntheticLogs(this.seed);
  final int seed;

  List<CareEntry> pet({
    required String petId,
    required Day first,
    required int days,
    PlantedChange? change,
    double logRate = 0.9,
  }) {
    final r = math.Random(seed);
    final usualEnergy = 3 + r.nextInt(2); // 3 or 4
    final usualWeight = 3.5 + r.nextDouble() * 25;
    final out = <CareEntry>[];
    for (var i = 0; i < days; i++) {
      final d = first.addDays(i);
      final changed = change != null && !d.isBefore(change.onset);
      if (r.nextDouble() > logRate) continue;

      final roll = r.nextDouble();
      final noise = roll < 0.6
          ? 0
          : roll < 0.9
              ? (r.nextBool() ? 1 : -1)
              : (r.nextBool() ? 2 : -2);
      var energy = usualEnergy + noise;
      if (changed && change.measure == Measure.energy) energy -= 2;
      energy = energy.clamp(1, 5);

      bool yes(Measure m) => changed && change.measure == m
          ? r.nextDouble() >= 0.8
          : r.nextDouble() >= 0.03;

      final data = <String, dynamic>{
        'ate': yes(Measure.ate),
        'energy': energy,
        'toiletingNormal': yes(Measure.toileting),
      };
      if (i % 7 == 0) {
        final w = usualWeight * (1 + (r.nextDouble() - 0.5) * 0.02);
        data['weightKg'] = double.parse(w.toStringAsFixed(2));
      }
      out.add(CareEntry(
        id: '$petId-$i',
        petId: petId,
        kind: EntryKind.dailyLog,
        day: d,
        createdAt: d.asDateTime.add(const Duration(hours: 19)),
        createdBy: 'synthetic',
        data: data,
      ));
    }
    return out;
  }
}
