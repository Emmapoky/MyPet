import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../detection/change_detector.dart';
import '../models/care_entry.dart';
import '../models/pet.dart';
import '../util/day.dart';

/// Every sentence the app builds from data lives here, so the team can review the wording
/// in one place. No sentence names a disease or a probability of one (FR-N01).
/// A likelihood as shown to people: rounded to 5, and never above 90%, because a short clip
/// can never be that certain (pet owner review, "Trust in Check").
String showPct(double p) {
  final v = (p * 100 / 5).round() * 5;
  return v > 90 ? 'over 90%' : '$v%';
}

class Wording {
  static const notDiagnosis = 'Not a medical diagnosis. If you are worried, talk to your vet.';
  static const notDiagnosisBehaviour = 'Not a medical diagnosis. MyPet shows likely behaviour, not illness.';

  static String day(Day d, Day today) {
    final diff = today.difference(d);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE d MMM').format(d.asDateTime);
  }

  static String shortDate(Day d) => DateFormat('d MMM').format(d.asDateTime);

  static String energyWord(int e) => switch (e) {
        1 => 'very low',
        2 => 'low',
        3 => 'usual',
        4 => 'good',
        _ => 'high',
      };

  static String entrySummary(CareEntry e) => switch (e.kind) {
        EntryKind.dailyLog => logParts(e).join(', '),
        EntryKind.healthRecord => e.title,
        EntryKind.behaviourResult =>
          behaviourSummary(e).isEmpty ? 'Behaviour check' : 'Behaviour check: ${behaviourSummary(e)}',
        EntryKind.taskDone => (e.data['title'] as String?) ?? 'Task done',
      };

  /// Timeline row title (Figma: "Daily log", "Behaviour check", a task or record name).
  static String entryTitleOf(CareEntry e) => switch (e.kind) {
        EntryKind.healthRecord => e.title,
        EntryKind.taskDone => (e.data['title'] as String?) ?? 'Care task',
        _ => entryTitle(e.kind),
      };

  /// Timeline row detail: "Ate · Energy 4 of 5 · Toileting normal · 12.4 kg".
  static String entryDetail(CareEntry e) => switch (e.kind) {
        EntryKind.dailyLog => logParts(e).join(' · '),
        EntryKind.healthRecord => e.data['type'] == 'change' ? 'Something changed · fresh start' : 'Health record',
        EntryKind.behaviourResult => behaviourSummary(e),
        EntryKind.taskDone => 'Done',
      };

  /// "Ate some", "Energy 4 of 5", "Toileting normal", "Drank more", "12.4 kg".
  static List<String> logParts(CareEntry e) => [
        if (e.ateAmount != null)
          switch (e.ateAmount) {
            'all' => 'Ate all',
            'some' => 'Ate some',
            _ => 'Did not eat',
          },
        if (e.energy != null) 'Energy ${e.energy} of 5',
        if (e.toiletingNormal != null)
          e.toiletingNormal! ? 'Toileting normal' : 'Toileting not normal'
        else if (e.toiletingUnseen)
          "Toileting not seen",
        if (e.data['drinkingMore'] == true) 'Drinking more',
        if (e.data['accident'] == true) 'Accident indoors',
        if (e.data['vomited'] == true) 'Vomited',
        if (e.weightKg != null) '${e.weightKg!.toStringAsFixed(1)} kg',
      ];

  static String behaviourSummary(CareEntry e) {
    final heard = e.data['heard'] as String?;
    if (heard != null) return 'Heard: $heard';
    final top = e.topLabel;
    if (top == null) return '';
    final pct = showPct(e.likelihoods[top] ?? 0);
    return e.data['unsure'] == true ? 'Not sure · closest $top $pct' : '$top · $pct';
  }

  /// "Likely happy or playful" -> "Happy or playful" for the Result card's title (Figma 09).
  static String feelingHeadline(String label) {
    final rest = label.startsWith('Likely ') ? label.substring(7) : label;
    return rest.isEmpty ? label : rest[0].toUpperCase() + rest.substring(1);
  }

  /// "Likely sad or uneasy" -> "Sad or uneasy", for the one-line list of other feelings.
  static String feelingShort(String label) => feelingHeadline(label);

  static String entryTitle(EntryKind k) => switch (k) {
        EntryKind.dailyLog => 'Daily log',
        EntryKind.healthRecord => 'Health record',
        EntryKind.behaviourResult => 'Behaviour check',
        EntryKind.taskDone => 'Care task',
      };

  static String flagTitle(ChangeFlag f) => switch (f.confidence) {
        Confidence.fact => 'Two days running',
        Confidence.early => 'Early sign',
        Confidence.slow => 'Slow change',
        Confidence.normal => f.measure == Measure.weight ? 'Weight change' : 'Change noticed',
      };

  static String _kg(double x) => '${x.toStringAsFixed(x.abs() < 1 ? 2 : 1)} kg';
  static String _pctOf(double share) => '${(share.abs() * 100).round()}%';

  /// "all", "some" or "none" for eating; "yes" or "no" style words for the rest.
  static String readingWord(Measure m, double? v) {
    if (v == null) return 'not logged';
    return switch (m) {
      Measure.weight => '${v.toStringAsFixed(1)} kg',
      Measure.energy => v.toStringAsFixed(0),
      Measure.ate => v >= 1 ? 'none' : v > 0 ? 'some' : 'all',
      Measure.toileting => v >= 1 ? 'not normal' : 'normal',
      Measure.drinking => v >= 1 ? 'more' : 'usual',
      Measure.accidents || Measure.vomited => v >= 1 ? 'yes' : 'no',
    };
  }

  /// How often the concerning answer came up in the baseline, in words.
  static String _usualShare(ChangeFlag f) {
    final n = f.baselineLoggedDays;
    final k = (f.usual * n).round();
    return switch (f.measure) {
      Measure.ate => k == 0 ? 'Usually eats all of it' : 'Ate less than all on about $k of $n days',
      Measure.toileting => 'Toileting not normal on $k of $n days',
      Measure.drinking => 'Drinking more on $k of $n days',
      Measure.accidents => 'Accidents indoors on $k of $n days',
      Measure.vomited => 'Vomited on $k of $n days',
      _ => '',
    };
  }

  /// "Energy lower than Milo's usual on 2 of the last 3 days" (Figma, Change flag).
  static String flagBody(ChangeFlag f, Pet pet) {
    if (f.confidence == Confidence.fact) {
      return switch (f.measure) {
        Measure.ate => 'Did not eat 2 days in a row',
        Measure.energy => 'Energy 1 of 5 two days running',
        Measure.toileting => 'Toileting not normal 2 days running',
        _ => 'Vomited 2 days in a row',
      };
    }
    final tr = f.trend;
    if (f.measure == Measure.weight && tr != null) {
      final way = tr.change >= 0 ? 'heavier' : 'lighter';
      return switch (tr.kind) {
        WeightKind.jump => '${_kg(tr.change.abs())} $way than expected from earlier weigh-ins (${_pctOf(tr.share)})',
        WeightKind.drift => '${_kg(tr.change.abs())} $way than ${tr.days} days ago (${_pctOf(tr.share)})',
        WeightKind.stall => "${pet.name}'s weight has not gone up for ${(tr.days / 7).round()} weeks",
      };
    }
    final noneOnly = f.recent.where((r) => r.unusual).every((r) => (r.value ?? 0) >= 1);
    final what = switch (f.measure) {
      Measure.energy => "Energy lower than ${pet.name}'s usual",
      Measure.ate => noneOnly ? 'Did not eat' : "Ate less than ${pet.name}'s usual",
      Measure.toileting => 'Toileting not normal',
      Measure.drinking => 'Drinking more than usual',
      Measure.accidents => 'Accidents indoors',
      Measure.vomited => 'Vomited',
      Measure.weight => "Weight changed",
    };
    return '$what on ${f.unusualDays} of the last ${f.recent.length} days';
  }

  /// Notes on records near the flag, or a fresh start after "Something changed".
  static List<String> flagNotes(ChangeFlag f) => [
        for (final n in f.notes)
          n.fresh
              ? 'Fresh start after "${n.title.isEmpty ? 'Something changed' : n.title}" on ${shortDate(n.day)}'
              : 'Within 2 days of ${n.title.isEmpty ? 'a vet visit' : n.title} on ${shortDate(n.day)}, when pets are often quieter',
      ];

  /// One line with the measure's usual value, the recent values and the baseline window
  /// (FR15): "Usual 4 of 5 · last 3 days 2, 2, 4 · compared with the 28 days before".
  static String flagEvidenceLine(ChangeFlag f) {
    final notes = flagNotes(f).map((n) => ' · $n').join();
    if (f.confidence == Confidence.fact) {
      return 'Logged ${f.recent.map((r) => readingWord(f.measure, r.value)).join(', ')} · '
          'a count of what was logged, not a comparison$notes';
    }
    final tr = f.trend;
    if (tr != null) {
      return switch (tr.kind) {
        WeightKind.jump => 'Expected about ${tr.fromKg.toStringAsFixed(1)} kg · latest ${tr.toKg.toStringAsFixed(1)} kg'
            ' · from ${f.baselineLoggedDays} weigh-ins since ${shortDate(f.baselineFrom)}$notes',
        _ => '${tr.fromKg.toStringAsFixed(1)} kg on ${shortDate(f.baselineFrom)} · ${tr.toKg.toStringAsFixed(1)} kg now'
            ' · ${f.baselineLoggedDays} weigh-ins$notes',
      };
    }
    final usual = f.measure == Measure.energy ? 'Usual ${_trim(f.usual)} of 5' : _usualShare(f);
    return '$usual · last ${f.recent.length} days ${f.recent.map((r) => readingWord(f.measure, r.value)).join(', ')}'
        ' · compared with the ${f.baselineLoggedDays} logged days before$notes';
  }

  static String flagThinLine(ChangeFlag f) => f.measure == Measure.weight
      ? 'Only ${f.baselineLoggedDays} weigh-ins so far, so this is less certain'
      : 'Only ${f.baselineLoggedDays} days logged, so this is less certain';

  static String _trim(double x) => x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1);

  /// "Change noticed: energy lower than Milo's usual on 2 of the last 3 days."
  /// (vault, FIT3162 Pet Health Research, section 6)
  static String flagHeadline(ChangeFlag f, Pet pet) {
    final body = flagBody(f, pet);
    final lower = body.startsWith(pet.name) ? body : body[0].toLowerCase() + body.substring(1);
    return '${flagTitle(f)}: $lower.';
  }

  /// Which measure moved, its direction, by how much and over what period (FR15).
  static List<String> flagEvidence(ChangeFlag f) {
    final recent = f.recent.map((r) => '${shortDate(r.day)}: ${readingWord(f.measure, r.value)}').join(', ');
    if (f.confidence == Confidence.fact) {
      return [
        'Logged $recent',
        'A count of what was logged. It does not compare with the usual yet',
        ...flagNotes(f),
      ];
    }
    final tr = f.trend;
    if (tr != null) {
      return [
        'Latest weight: ${tr.toKg.toStringAsFixed(1)} kg',
        switch (tr.kind) {
          WeightKind.jump => 'Expected about ${tr.fromKg.toStringAsFixed(1)} kg from the line through the earlier weigh-ins',
          WeightKind.drift => '${tr.fromKg.toStringAsFixed(1)} kg ${tr.days} days ago, so ${_kg(tr.change.abs())} '
              '${tr.change >= 0 ? 'heavier' : 'lighter'} (${_pctOf(tr.share)})',
          WeightKind.stall => 'About ${tr.fromKg.toStringAsFixed(1)} kg ${tr.days} days ago and now, while still growing',
        },
        'Weigh-ins used: ${f.baselineLoggedDays}, ${shortDate(f.baselineFrom)} to ${shortDate(f.baselineTo)}',
        if (f.confidence == Confidence.early) 'Few weigh-ins so far, so this is an early sign only',
        if (f.confidence == Confidence.slow) 'A slow change over about 3 months, which can be missed day to day',
        ...flagNotes(f),
      ];
    }
    final usual = f.measure == Measure.energy ? 'Usual energy: ${f.usual.toStringAsFixed(1)} out of 5' : _usualShare(f);
    final size = f.measure == Measure.energy
        ? () {
            final lowest = f.recent.where((r) => r.unusual).map((r) => r.value!).reduce(math.min);
            return 'Down by up to ${(f.usual - lowest).toStringAsFixed(1)} points';
          }()
        : '${readingWord(f.measure, 1) == 'none' ? 'Less than usual' : 'Unusual'} on ${f.unusualDays} of the last ${f.recent.length} days';
    return [
      usual,
      size,
      'Last ${f.recent.length} days: $recent',
      'Compared with ${f.baselineLoggedDays} logged days, ${shortDate(f.baselineFrom)} to ${shortDate(f.baselineTo)}',
      if (f.confidence == Confidence.early) 'Fewer than 14 days to compare with, so this is an early sign only',
      ...flagNotes(f),
    ];
  }
}
