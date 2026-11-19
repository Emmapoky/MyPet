import 'dart:math' as math;

import '../config/thresholds.dart';
import '../models/care_entry.dart';
import '../util/day.dart';

/// What the detector watches. Each has one concerning direction (FR-N03).
enum Measure { ate, energy, toileting, weight }

extension MeasureText on Measure {
  String get label => switch (this) {
        Measure.ate => 'Eating',
        Measure.energy => 'Energy',
        Measure.toileting => 'Toileting',
        Measure.weight => 'Weight',
      };
}

enum Confidence {
  /// Baseline has at least [Thresholds.thinBaselineDays] logged days.
  normal,

  /// Thin baseline: the flag is shown as an early sign (FR16).
  early,
}

/// The value one measure had on one day, and how unusual it was.
class DayReading {
  final Day day;
  final double? value;
  final double? score;
  final bool unusual;

  const DayReading(this.day, this.value, this.score, this.unusual);
}

/// A change noticed in one measure, with its evidence (FR15).
class ChangeFlag {
  final Measure measure;

  /// The pet's usual value: the baseline median, or for yes/no the share of "no" days.
  final double usual;

  /// The last [Thresholds.recentDays] days, oldest first.
  final List<DayReading> recent;
  final int unusualDays;
  final Day baselineFrom;
  final Day baselineTo;
  final int baselineLoggedDays;
  final Confidence confidence;

  const ChangeFlag({
    required this.measure,
    required this.usual,
    required this.recent,
    required this.unusualDays,
    required this.baselineFrom,
    required this.baselineTo,
    required this.baselineLoggedDays,
    required this.confidence,
  });

  /// Direction in plain words. Every measure is only flagged in its concerning direction.
  String get direction => switch (measure) {
        Measure.ate => 'not eating',
        Measure.energy => 'lower',
        Measure.toileting => 'not normal',
        Measure.weight => 'lower',
      };
}

/// The result of one run of the detector for one pet.
class DetectionResult {
  final Day asOf;
  final int loggedDays;

  /// False below [Thresholds.minLoggedDays] logged days: no flags and no Insights (NFR07).
  final bool ready;
  final List<ChangeFlag> flags;

  const DetectionResult(this.asOf, this.loggedDays, this.ready, this.flags);

  int get daysUntilReady =>
      math.max(0, Thresholds.minLoggedDays - loggedDays);
}

/// Compares a pet's last 3 days with its own previous 28 days (report 4.1, FR13 to FR16).
///
/// Pure Dart with no Flutter imports, so it can run in a background isolate (NFR03) and
/// be tested on its own.
class ChangeDetector {
  const ChangeDetector();

  DetectionResult run(List<CareEntry> currentEntries, Day asOf) {
    final logs = <Day, CareEntry>{};
    for (final e in currentEntries) {
      if (e.kind != EntryKind.dailyLog || e.day.isAfter(asOf)) continue;
      final prev = logs[e.day];
      // One reading per day: the latest log of that day.
      if (prev == null || e.createdAt.isAfter(prev.createdAt)) logs[e.day] = e;
    }
    final loggedDays = logs.length;
    if (loggedDays < Thresholds.minLoggedDays) {
      return DetectionResult(asOf, loggedDays, false, const []);
    }

    final recentFrom = asOf.addDays(-(Thresholds.recentDays - 1));
    final baselineTo = recentFrom.addDays(-1);
    final baselineFrom = baselineTo.addDays(-(Thresholds.baselineDays - 1));

    final flags = <ChangeFlag>[];
    for (final m in Measure.values) {
      final baseline = <double>[];
      for (var d = baselineFrom; !d.isAfter(baselineTo); d = d.addDays(1)) {
        final v = _value(logs[d], m);
        if (v != null) baseline.add(v); // missed days stay missing, not zero (4.4)
      }
      if (baseline.isEmpty) continue;

      final recent = <(Day, double?)>[];
      for (var d = recentFrom; !d.isAfter(asOf); d = d.addDays(1)) {
        recent.add((d, _value(logs[d], m)));
      }

      final flag = _isYesNo(m)
          ? _yesNo(m, baseline, recent, baselineFrom, baselineTo)
          : _numeric(m, baseline, recent, baselineFrom, baselineTo);
      if (flag != null) flags.add(flag);
    }
    return DetectionResult(asOf, loggedDays, true, flags);
  }

  static bool _isYesNo(Measure m) => m == Measure.ate || m == Measure.toileting;

  /// Yes/no measures are stored as 1 for the concerning answer ("no") and 0 otherwise.
  static double? _value(CareEntry? e, Measure m) {
    if (e == null) return null;
    return switch (m) {
      Measure.ate => e.ate == null ? null : (e.ate! ? 0 : 1),
      Measure.toileting =>
        e.toiletingNormal == null ? null : (e.toiletingNormal! ? 0 : 1),
      Measure.energy => e.energy?.toDouble(),
      Measure.weight => e.weightKg,
    };
  }

  ChangeFlag? _numeric(Measure m, List<double> baseline,
      List<(Day, double?)> recent, Day from, Day to) {
    final med = median(baseline);
    final mad = median(baseline.map((x) => (x - med).abs()).toList());
    final minSpread = m == Measure.weight
        ? Thresholds.minWeightSpreadShare * med
        : Thresholds.minEnergySpread;
    final spread = math.max(Thresholds.madScale * mad, minSpread);

    final readings = <DayReading>[];
    var unusual = 0;
    for (final (d, v) in recent) {
      if (v == null) {
        readings.add(DayReading(d, null, null, false));
        continue;
      }
      final score = (v - med) / spread;
      // Only a fall is concerning for energy and weight (FR-N03).
      final isUnusual = score < -Thresholds.scoreCutoff;
      if (isUnusual) unusual++;
      readings.add(DayReading(d, v, score, isUnusual));
    }
    if (unusual < Thresholds.unusualDaysNeeded) return null;
    return _flag(m, med, readings, unusual, from, to, baseline.length);
  }

  ChangeFlag? _yesNo(Measure m, List<double> baseline,
      List<(Day, double?)> recent, Day from, Day to) {
    final share = baseline.reduce((a, b) => a + b) / baseline.length;
    final rare = share <= Thresholds.rareShare;
    final readings = <DayReading>[];
    var unusual = 0;
    for (final (d, v) in recent) {
      final isUnusual = rare && v == 1;
      if (isUnusual) unusual++;
      readings.add(DayReading(d, v, null, isUnusual));
    }
    if (unusual < Thresholds.unusualDaysNeeded) return null;
    return _flag(m, share, readings, unusual, from, to, baseline.length);
  }

  ChangeFlag _flag(Measure m, double usual, List<DayReading> readings,
          int unusual, Day from, Day to, int n) =>
      ChangeFlag(
        measure: m,
        usual: usual,
        recent: readings,
        unusualDays: unusual,
        baselineFrom: from,
        baselineTo: to,
        baselineLoggedDays: n,
        confidence: n < Thresholds.thinBaselineDays
            ? Confidence.early
            : Confidence.normal,
      );

  static double median(List<double> xs) {
    final s = [...xs]..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }
}
