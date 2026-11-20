import 'dart:math' as math;

import '../config/thresholds.dart';
import '../models/care_entry.dart';
import '../models/life_stage.dart';
import '../util/day.dart';

export '../models/life_stage.dart' show PetFacts;

/// What the detector watches. Weight is judged both ways (as a neutral fact); every other
/// measure only in its concerning direction (FR-N03).
enum Measure { ate, energy, toileting, weight, drinking, accidents, vomited }

extension MeasureText on Measure {
  String get label => switch (this) {
        Measure.ate => 'Eating',
        Measure.energy => 'Energy',
        Measure.toileting => 'Toileting',
        Measure.weight => 'Weight',
        Measure.drinking => 'Drinking',
        Measure.accidents => 'Accidents indoors',
        Measure.vomited => 'Vomiting',
      };
}

enum Confidence {
  /// Baseline has at least [Thresholds.thinBaselineDays] logged days.
  normal,

  /// Thin baseline: the flag is shown as an early sign (FR16).
  early,

  /// A plain count of what was logged ("did not eat 2 days in a row"). Needs no baseline,
  /// so it can show from day 1 (review layer 4).
  fact,

  /// A slow change over 90 days, for senior pets (review layer 3).
  slow,
}

/// How a weight flag was found.
enum WeightKind {
  /// The newest reading is far from the line through the earlier ones.
  jump,

  /// The line itself has moved a lot over 30 (or 90) days.
  drift,

  /// A growing pet whose weight has not gone up for 2 weeks.
  stall,
}

/// Weight from [fromKg] to [toKg] over [days] days.
class WeightTrend {
  final WeightKind kind;
  final double fromKg, toKg;
  final int days;
  const WeightTrend(this.kind, this.fromKg, this.toKg, this.days);
  double get change => toKg - fromKg;
  double get share => fromKg == 0 ? 0 : change / fromKg;
}

/// A record near a flagged day, or a "Something changed" tag that restarted the baseline.
class FlagNote {
  final Day day;
  final String title;

  /// True for a "Something changed" tag, false for a vet visit or vaccination.
  final bool fresh;
  const FlagNote(this.day, this.title, {this.fresh = false});
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

  /// The pet's usual value: the baseline median, the expected weight, or for yes/no the
  /// share of concerning answers.
  final double usual;

  /// The last [Thresholds.recentDays] days, oldest first.
  final List<DayReading> recent;
  final int unusualDays;
  final Day baselineFrom;
  final Day baselineTo;
  final int baselineLoggedDays;
  final Confidence confidence;

  /// Only weight can go up.
  final bool up;
  final WeightTrend? trend;
  final List<FlagNote> notes;

  const ChangeFlag({
    required this.measure,
    required this.usual,
    required this.recent,
    required this.unusualDays,
    required this.baselineFrom,
    required this.baselineTo,
    required this.baselineLoggedDays,
    required this.confidence,
    this.up = false,
    this.trend,
    this.notes = const [],
  });

  /// Direction in plain words.
  String get direction => switch (measure) {
        Measure.ate => 'eating less',
        Measure.energy => 'lower',
        Measure.toileting => 'not normal',
        Measure.weight => up ? 'higher' : 'lower',
        Measure.drinking => 'drinking more',
        Measure.accidents => 'accidents indoors',
        Measure.vomited => 'vomiting',
      };
}

/// The result of one run of the detector for one pet.
class DetectionResult {
  final Day asOf;
  final int loggedDays;

  /// False below [Thresholds.minLoggedDays] logged days: no baseline flags and no Insights
  /// (NFR07). Fact flags can still be in [flags].
  final bool ready;
  final List<ChangeFlag> flags;

  const DetectionResult(this.asOf, this.loggedDays, this.ready, this.flags);

  int get daysUntilReady => math.max(0, Thresholds.minLoggedDays - loggedDays);

  /// Flags that compare with the pet's own baseline (not plain counts).
  List<ChangeFlag> get baselineFlags => flags.where((f) => f.confidence != Confidence.fact).toList();
}

/// One day's answers, merged across every log of that day.
class _Day {
  final Map<Measure, double> v = {};
  DateTime? weightAt;
  final Set<String> by = {};
}

/// Compares a pet's last 3 days with its own previous 28 days (report 4.1, FR13 to FR16),
/// and follows weight as a trend (pet owner review, layers 2 to 4).
///
/// Pure Dart with no Flutter imports, so it can run in a background isolate (NFR03) and
/// be tested on its own.
class ChangeDetector {
  const ChangeDetector();

  static const _yesNoKeys = {
    Measure.drinking: 'drinkingMore',
    Measure.accidents: 'accident',
    Measure.vomited: 'vomited',
  };

  /// [entries] are the pet's daily logs, plus its health records (for vet days and
  /// "Something changed" tags).
  DetectionResult run(List<CareEntry> entries, Day asOf, {PetFacts pet = const PetFacts()}) {
    final days = <Day, _Day>{};
    final records = <CareEntry>[];
    for (final e in entries) {
      if (e.day.isAfter(asOf)) continue;
      if (e.kind == EntryKind.healthRecord) records.add(e);
      if (e.kind != EntryKind.dailyLog) continue;
      _merge(days.putIfAbsent(e.day, _Day.new), e);
    }

    // Days within 2 days of a vet visit, vaccination or procedure are left out of the
    // baseline (review change 7), and noted on any flag that touches them.
    final vetDays = <Day, FlagNote>{};
    final resets = <Measure, FlagNote>{};
    for (final r in records) {
      final type = r.data['type'] as String?;
      if (type == 'change') {
        final names = List<String>.from((r.data['measures'] as List?) ?? const []);
        final ms = names.isEmpty
            ? Measure.values
            : [for (final n in names) ?Measure.values.asNameMap()[n]];
        for (final m in ms) {
          final prev = resets[m];
          if (prev == null || r.day.isAfter(prev.day)) resets[m] = FlagNote(r.day, r.title, fresh: true);
        }
      } else if (type == null || const {'vaccination', 'vetVisit', 'surgery'}.contains(type)) {
        for (var i = 0; i <= Thresholds.vetDaysLeftOut; i++) {
          vetDays.putIfAbsent(r.day.addDays(i), () => FlagNote(r.day, r.title));
        }
      }
    }

    final loggedDays = days.length;
    final ready = loggedDays >= Thresholds.minLoggedDays;

    final recentFrom = asOf.addDays(-(Thresholds.recentDays - 1));
    final baselineTo = recentFrom.addDays(-1);
    final window = pet.young ? Thresholds.youngBaselineDays : Thresholds.baselineDays;

    final flags = <ChangeFlag>[];
    final judged = <Measure>{};
    for (final m in Measure.values) {
      if (m == Measure.weight) continue;
      final reset = resets[m];
      var from = baselineTo.addDays(-(window - 1));
      if (reset != null && reset.day.isAfter(from)) from = reset.day;
      final baseline = <double>[];
      for (var d = from; !d.isAfter(baselineTo); d = d.addDays(1)) {
        if (vetDays.containsKey(d)) continue;
        final v = days[d]?.v[m];
        if (v != null) baseline.add(v); // missed days stay missing, not zero (4.4)
      }
      final recent = <(Day, double?)>[
        for (var d = recentFrom; !d.isAfter(asOf); d = d.addDays(1)) (d, days[d]?.v[m]),
      ];
      if (ready && baseline.length >= Thresholds.minBaselineReadings) {
        judged.add(m);
        final notes = [
          if (reset != null && !reset.day.isBefore(from)) reset,
          ..._notesFor(recent.map((x) => x.$1), vetDays),
        ];
        final flag = m == Measure.energy
            ? _numeric(m, baseline, recent, from, baselineTo, notes)
            : _share(m, baseline, recent, from, baselineTo, notes);
        if (flag != null) flags.add(flag);
      }
    }

    flags.addAll(_weight(days, asOf, pet, resets[Measure.weight], vetDays));

    // Safety net from day 1: plain counts, only where no baseline judged the measure yet.
    for (final m in const [Measure.ate, Measure.energy, Measure.toileting, Measure.vomited]) {
      if (judged.contains(m)) continue;
      final f = _fact(m, days, asOf, vetDays);
      if (f != null) flags.add(f);
    }
    return DetectionResult(asOf, loggedDays, ready, flags);
  }

  /// Several logs on one day (two carers, or the notification after the app): any
  /// concerning answer is kept, energy takes the lowest, weight the latest (change 9).
  static void _merge(_Day day, CareEntry e) {
    day.by.add(e.createdBy);
    void worst(Measure m, double? x) {
      if (x == null) return;
      final prev = day.v[m];
      day.v[m] = prev == null ? x : math.max(prev, x);
    }

    worst(Measure.ate, switch (e.ateAmount) {
      'all' => 0.0,
      'some' => 0.5,
      'none' => 1.0,
      _ => null,
    });
    worst(Measure.toileting, e.toiletingNormal == null ? null : (e.toiletingNormal! ? 0 : 1));
    for (final k in _yesNoKeys.entries) {
      final b = e.data[k.value];
      if (b is bool) worst(k.key, b ? 1 : 0);
    }
    final en = e.energy?.toDouble();
    if (en != null) {
      final prev = day.v[Measure.energy];
      day.v[Measure.energy] = prev == null ? en : math.min(prev, en);
    }
    final w = e.weightKg;
    if (w != null && (day.weightAt == null || e.createdAt.isAfter(day.weightAt!))) {
      day.v[Measure.weight] = w;
      day.weightAt = e.createdAt;
    }
  }

  static List<FlagNote> _notesFor(Iterable<Day> ds, Map<Day, FlagNote> vetDays) {
    final out = <FlagNote>[];
    for (final d in ds) {
      final n = vetDays[d];
      if (n != null && !out.any((x) => x.day == n.day)) out.add(n);
    }
    return out;
  }

  ChangeFlag? _numeric(Measure m, List<double> baseline, List<(Day, double?)> recent, Day from,
      Day to, List<FlagNote> notes) {
    final med = median(baseline);
    final mad = median(baseline.map((x) => (x - med).abs()).toList());
    final spread = math.max(Thresholds.madScale * mad, Thresholds.minEnergySpread);

    final readings = <DayReading>[];
    var unusual = 0;
    for (final (d, v) in recent) {
      if (v == null) {
        readings.add(DayReading(d, null, null, false));
        continue;
      }
      final score = (v - med) / spread;
      // Only a fall in energy is concerning (FR-N03).
      final isUnusual = score < -Thresholds.scoreCutoff;
      if (isUnusual) unusual++;
      readings.add(DayReading(d, v, score, isUnusual));
    }
    if (unusual < Thresholds.unusualDaysNeeded) return null;
    return _flag(m, med, readings, unusual, from, to, baseline.length, notes);
  }

  /// Yes/no answers and "Ate: All / Some / None", scored 0, 0.5 and 1 (change 3). A day is
  /// unusual when answers at least that bad were rare in the baseline (report 4.1).
  ChangeFlag? _share(Measure m, List<double> baseline, List<(Day, double?)> recent, Day from,
      Day to, List<FlagNote> notes) {
    final mean = baseline.reduce((a, b) => a + b) / baseline.length;
    final readings = <DayReading>[];
    var unusual = 0;
    for (final (d, v) in recent) {
      var isUnusual = false;
      if (v != null && v > 0) {
        final asBad = baseline.where((x) => x >= v).length / baseline.length;
        isUnusual = asBad <= Thresholds.rareShare;
      }
      if (isUnusual) unusual++;
      readings.add(DayReading(d, v, null, isUnusual));
    }
    if (unusual < Thresholds.unusualDaysNeeded) return null;
    return _flag(m, mean, readings, unusual, from, to, baseline.length, notes);
  }

  /// "Did not eat 2 days in a row": the last two days both logged with the concerning
  /// answer (energy 1 for energy).
  ChangeFlag? _fact(Measure m, Map<Day, _Day> days, Day asOf, Map<Day, FlagNote> vetDays) {
    final ds = [asOf.addDays(-1), asOf];
    bool bad(double? v) => v != null && (m == Measure.energy ? v <= 1 : v >= 1);
    final vals = [for (final d in ds) days[d]?.v[m]];
    if (!vals.every(bad)) return null;
    return ChangeFlag(
      measure: m,
      usual: 0,
      recent: [for (var i = 0; i < 2; i++) DayReading(ds[i], vals[i], null, true)],
      unusualDays: 2,
      baselineFrom: ds.first,
      baselineTo: ds.first,
      baselineLoggedDays: 0,
      confidence: Confidence.fact,
      notes: _notesFor(ds, vetDays),
    );
  }

  /// Weight as a trend (change 1): every reading counts on its own, both directions are
  /// reported as facts, and the noise floor is max(1.5% of weight, 0.05 kg).
  List<ChangeFlag> _weight(Map<Day, _Day> days, Day asOf, PetFacts pet, FlagNote? reset,
      Map<Day, FlagNote> vetDays) {
    final look = pet.growing
        ? Thresholds.growingWeightDays
        : pet.senior
            ? Thresholds.slowWeightDays
            : Thresholds.weightDays;
    var from = asOf.addDays(-look);
    if (reset != null && reset.day.isAfter(from)) from = reset.day;
    final pts = <(Day, double)>[
      for (final e in days.entries)
        if (e.value.v[Measure.weight] != null && !e.key.isBefore(from)) (e.key, e.value.v[Measure.weight]!),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (pts.length < 3) return const [];
    final latest = pts.last;
    // Only judge when there is a new reading in the last 3 days.
    if (asOf.difference(latest.$1) >= Thresholds.recentDays) return const [];
    if (latest.$1.difference(pts.first.$1) < 7) return const [];

    double floor(double w) => math.max(Thresholds.minWeightSpreadShare * w, Thresholds.scaleResolutionKg);
    final recentFrom = asOf.addDays(-(Thresholds.recentDays - 1));
    final recent = [
      for (var d = recentFrom; !d.isAfter(asOf); d = d.addDays(1))
        DayReading(d, days[d]?.v[Measure.weight], null, d == latest.$1),
    ];
    final notes = [
      ?reset,
      ..._notesFor([latest.$1], vetDays),
    ];

    ChangeFlag make(WeightKind k, double usual, Day bFrom, Day bTo, int n, double fromKg, int span,
            {Confidence c = Confidence.normal}) =>
        ChangeFlag(
          measure: Measure.weight,
          usual: usual,
          recent: recent,
          unusualDays: 1,
          baselineFrom: bFrom,
          baselineTo: bTo,
          baselineLoggedDays: n,
          confidence: n < 3 ? Confidence.early : c,
          up: latest.$2 > fromKg,
          trend: WeightTrend(k, fromKg, latest.$2, span),
          notes: notes,
        );

    // 1. A jump: the newest reading against the line through the earlier ones.
    final earlier = pts.sublist(0, pts.length - 1);
    final line = _Line.fit(earlier);
    // Never extend the line further than the readings it came from.
    final reach = math.min(latest.$1.difference(earlier.last.$1), earlier.last.$1.difference(earlier.first.$1));
    final expected = line.at(earlier.last.$1.addDays(reach), earlier.first.$1);
    final mad = median([for (final p in earlier) (p.$2 - line.at(p.$1, earlier.first.$1)).abs()]);
    final spread = math.max(Thresholds.madScale * mad, floor(expected));
    final score = (latest.$2 - expected) / spread;
    if (score.abs() >= Thresholds.scoreCutoff) {
      return [make(WeightKind.jump, expected, earlier.first.$1, earlier.last.$1, earlier.length, expected,
          latest.$1.difference(earlier.last.$1))];
    }

    final all = _Line.fit(pts);
    double fitted(Day d) => all.at(d, pts.first.$1);

    // 2. Growing pets should gain: flag gently when 2 weeks pass with no gain.
    if (pet.growing) {
      final since = latest.$1.addDays(-Thresholds.growthStallDays);
      final lastTwoWeeks = pts.where((p) => !p.$1.isBefore(since.addDays(-3))).toList();
      if (lastTwoWeeks.length >= 3 && latest.$1.difference(lastTwoWeeks.first.$1) >= Thresholds.growthStallDays) {
        final l = _Line.fit(lastTwoWeeks);
        final start = l.at(lastTwoWeeks.first.$1, lastTwoWeeks.first.$1);
        final end = l.at(latest.$1, lastTwoWeeks.first.$1);
        if (end - start < floor(end)) {
          return [make(WeightKind.stall, start, lastTwoWeeks.first.$1, latest.$1, lastTwoWeeks.length, start,
              latest.$1.difference(lastTwoWeeks.first.$1))];
        }
      }
      return const [];
    }

    // 3. A slow drift over a month, and for seniors over 3 months (layer 3).
    for (final (span, c) in [
      (Thresholds.driftDays, Confidence.normal),
      if (pet.senior) (Thresholds.slowWeightDays, Confidence.slow),
    ]) {
      final startDay = pts.first.$1.isAfter(latest.$1.addDays(-span)) ? pts.first.$1 : latest.$1.addDays(-span);
      final length = latest.$1.difference(startDay);
      if (length < Thresholds.minDriftDays) continue;
      final a = fitted(startDay), b = fitted(latest.$1);
      if ((b - a).abs() >= Thresholds.scoreCutoff * floor(b)) {
        final used = pts.where((p) => !p.$1.isBefore(startDay)).length;
        return [make(WeightKind.drift, a, startDay, latest.$1, used, a, length, c: c)];
      }
    }
    return const [];
  }

  ChangeFlag _flag(Measure m, double usual, List<DayReading> readings, int unusual, Day from, Day to,
          int n, List<FlagNote> notes) =>
      ChangeFlag(
        measure: m,
        usual: usual,
        recent: readings,
        unusualDays: unusual,
        baselineFrom: from,
        baselineTo: to,
        baselineLoggedDays: n,
        confidence: n < Thresholds.thinBaselineDays ? Confidence.early : Confidence.normal,
        notes: notes,
      );

  static double median(List<double> xs) {
    final s = [...xs]..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }
}

/// A least-squares straight line through (day, kg) points, any spacing.
class _Line {
  final double a, b; // kg = a + b * days since origin
  const _Line(this.a, this.b);

  factory _Line.fit(List<(Day, double)> pts) {
    final o = pts.first.$1;
    final xs = [for (final p in pts) p.$1.difference(o).toDouble()];
    final ys = [for (final p in pts) p.$2];
    final n = xs.length;
    final mx = xs.reduce((x, y) => x + y) / n, my = ys.reduce((x, y) => x + y) / n;
    var sxy = 0.0, sxx = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += (xs[i] - mx) * (ys[i] - my);
      sxx += (xs[i] - mx) * (xs[i] - mx);
    }
    final b = sxx == 0 ? 0.0 : sxy / sxx;
    return _Line(my - b * mx, b);
  }

  double at(Day d, Day origin) => a + b * d.difference(origin);
}
