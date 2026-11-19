import 'package:intl/intl.dart';

import '../detection/change_detector.dart';
import '../models/care_entry.dart';
import '../models/pet.dart';
import '../util/day.dart';

/// Every sentence the app builds from data lives here, so the team can review the wording
/// in one place. No sentence names a disease or a probability of one (FR-N01).
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
        EntryKind.dailyLog => [
            if (e.ate != null) e.ate! ? 'Ate' : 'Did not eat',
            if (e.energy != null) 'energy ${e.energy}/5',
            if (e.toiletingNormal != null)
              e.toiletingNormal! ? 'toileting normal' : 'toileting not normal',
            if (e.weightKg != null) '${e.weightKg!.toStringAsFixed(1)} kg',
          ].join(', '),
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
        EntryKind.dailyLog => [
            if (e.ate != null) e.ate! ? 'Ate' : 'Did not eat',
            if (e.energy != null) 'Energy ${e.energy} of 5',
            if (e.toiletingNormal != null)
              e.toiletingNormal! ? 'Toileting normal' : 'Toileting not normal',
            if (e.weightKg != null) '${e.weightKg!.toStringAsFixed(1)} kg',
          ].join(' · '),
        EntryKind.healthRecord => 'Health record',
        EntryKind.behaviourResult => behaviourSummary(e),
        EntryKind.taskDone => 'Done',
      };

  static String behaviourSummary(CareEntry e) {
    final heard = e.data['heard'] as String?;
    if (heard != null) return 'Heard: $heard';
    final top = e.topLabel;
    if (top == null) return '';
    final pct = ((e.likelihoods[top] ?? 0) * 100).round();
    return e.data['unsure'] == true ? 'Not sure · closest $top $pct%' : '$top · $pct%';
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

  static String flagTitle(ChangeFlag f) =>
      f.confidence == Confidence.early ? 'Early sign' : 'Change noticed';

  /// "Energy lower than Milo's usual on 2 of the last 3 days" (Figma, Change flag).
  static String flagBody(ChangeFlag f, Pet pet) {
    final what = switch (f.measure) {
      Measure.energy => "Energy lower than ${pet.name}'s usual",
      Measure.weight => "Weight lower than ${pet.name}'s usual",
      Measure.ate => 'Did not eat',
      Measure.toileting => 'Toileting not normal',
    };
    return '$what on ${f.unusualDays} of the last ${f.recent.length} days';
  }

  /// One line with the measure's usual value, the recent values and the baseline window
  /// (FR15): "Usual 4 of 5 · last 3 days 2, 2, 4 · compared with the 28 days before".
  static String flagEvidenceLine(ChangeFlag f) {
    String v(double? x) => x == null
        ? 'none'
        : switch (f.measure) {
            Measure.weight => '${x.toStringAsFixed(1)} kg',
            Measure.energy => x.toStringAsFixed(0),
            _ => x == 1 ? 'no' : 'yes',
          };
    final usual = switch (f.measure) {
      Measure.energy => 'Usual ${_trim(f.usual)} of 5',
      Measure.weight => 'Usual ${f.usual.toStringAsFixed(1)} kg',
      _ => 'Usually "no" on ${(f.usual * f.baselineLoggedDays).round()} of ${f.baselineLoggedDays} days',
    };
    return '$usual · last ${f.recent.length} days ${f.recent.map((r) => v(r.value)).join(', ')}'
        ' · compared with the ${f.baselineLoggedDays} logged days before';
  }

  static String flagThinLine(ChangeFlag f) =>
      'Only ${f.baselineLoggedDays} days logged, so this is less certain';

  static String _trim(double x) => x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1);

  /// "Change noticed: energy lower than Milo's usual on 2 of the last 3 days."
  /// (vault, FIT3162 Pet Health Research, section 6)
  static String flagHeadline(ChangeFlag f, Pet pet) {
    final lead = f.confidence == Confidence.early ? 'Early sign' : 'Change noticed';
    final what = switch (f.measure) {
      Measure.energy => "energy lower than ${pet.name}'s usual",
      Measure.weight => "weight lower than ${pet.name}'s usual",
      Measure.ate => '${pet.name} did not eat',
      Measure.toileting => 'toileting not normal',
    };
    return '$lead: $what on ${f.unusualDays} of the last ${f.recent.length} days.';
  }

  /// Which measure moved, its direction, by how much and over what period (FR15).
  static List<String> flagEvidence(ChangeFlag f) {
    String v(double? x) => x == null
        ? 'not logged'
        : f.measure == Measure.weight
            ? '${x.toStringAsFixed(1)} kg'
            : f.measure == Measure.energy
                ? x.toStringAsFixed(0)
                : (x == 1 ? 'no' : 'yes');
    final recent = f.recent.map((r) => '${shortDate(r.day)}: ${v(r.value)}').join(', ');
    final usual = switch (f.measure) {
      Measure.energy => 'Usual energy: ${f.usual.toStringAsFixed(1)} out of 5',
      Measure.weight => 'Usual weight: ${f.usual.toStringAsFixed(1)} kg',
      _ =>
        'Usually "no" on ${(f.usual * f.baselineLoggedDays).round()} of ${f.baselineLoggedDays} days',
    };
    final size = switch (f.measure) {
      Measure.energy || Measure.weight => () {
          final vals = f.recent.where((r) => r.unusual).map((r) => r.value!);
          final lowest = vals.reduce((a, b) => a < b ? a : b);
          final drop = f.usual - lowest;
          return f.measure == Measure.weight
              ? 'Down by up to ${drop.toStringAsFixed(1)} kg (${(drop / f.usual * 100).toStringAsFixed(0)}%)'
              : 'Down by up to ${drop.toStringAsFixed(1)} points';
        }(),
      _ => '"No" on ${f.unusualDays} of the last ${f.recent.length} days',
    };
    return [
      usual,
      size,
      'Last ${f.recent.length} days: $recent',
      'Compared with ${f.baselineLoggedDays} logged days, ${shortDate(f.baselineFrom)} to ${shortDate(f.baselineTo)}',
      if (f.confidence == Confidence.early)
        'Fewer than 14 days to compare with, so this is an early sign only',
    ];
  }
}
