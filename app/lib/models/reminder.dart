import '../util/day.dart';

enum ReminderKind { feeding, medication, grooming, vet, other }

/// A recurring care schedule (FR10): start date, end date and frequency.
class Reminder {
  final String id;
  final String petId;
  final String title;
  final ReminderKind kind;
  final Day start;
  final Day? end;

  /// 1 = every day, 7 = every week.
  final int everyDays;

  /// Times of day, in minutes after midnight.
  final List<int> times;

  /// Minutes before each occurrence to notify (FR11). 0 = at the time.
  final int notifyBefore;
  final bool active;

  const Reminder({
    required this.id,
    required this.petId,
    required this.title,
    this.kind = ReminderKind.other,
    required this.start,
    this.end,
    this.everyDays = 1,
    this.times = const [8 * 60],
    this.notifyBefore = 0,
    this.active = true,
  });

  bool occursOn(Day d) {
    if (!active || d.isBefore(start)) return false;
    if (end != null && d.isAfter(end!)) return false;
    return d.difference(start) % everyDays == 0;
  }

  /// Every occurrence from [from] to [to], both days included.
  List<DateTime> occurrences(Day from, Day to) {
    final out = <DateTime>[];
    for (var d = from; !d.isAfter(to); d = d.addDays(1)) {
      if (!occursOn(d)) continue;
      for (final m in times) {
        out.add(DateTime(d.year, d.month, d.dayOfMonth, m ~/ 60, m % 60));
      }
    }
    return out;
  }

  Reminder copyWith({
    String? title,
    ReminderKind? kind,
    Day? start,
    Day? end,
    bool clearEnd = false,
    int? everyDays,
    List<int>? times,
    int? notifyBefore,
    bool? active,
  }) =>
      Reminder(
        id: id,
        petId: petId,
        title: title ?? this.title,
        kind: kind ?? this.kind,
        start: start ?? this.start,
        end: clearEnd ? null : (end ?? this.end),
        everyDays: everyDays ?? this.everyDays,
        times: times ?? this.times,
        notifyBefore: notifyBefore ?? this.notifyBefore,
        active: active ?? this.active,
      );

  Map<String, dynamic> toMap() => {
        'petId': petId,
        'title': title,
        'kind': kind.name,
        'start': start.toString(),
        'end': end?.toString(),
        'everyDays': everyDays,
        'times': times,
        'notifyBefore': notifyBefore,
        'active': active,
      };

  factory Reminder.fromMap(String id, Map<String, dynamic> m) => Reminder(
        id: id,
        petId: m['petId'] as String,
        title: m['title'] as String,
        kind: ReminderKind.values.byName((m['kind'] as String?) ?? 'other'),
        start: Day.parse(m['start'] as String),
        end: m['end'] == null ? null : Day.parse(m['end'] as String),
        everyDays: (m['everyDays'] as num?)?.toInt() ?? 1,
        times: List<int>.from((m['times'] as List?) ?? const [480]),
        notifyBefore: (m['notifyBefore'] as num?)?.toInt() ?? 0,
        active: (m['active'] as bool?) ?? true,
      );
}
