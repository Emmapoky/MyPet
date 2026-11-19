import '../util/day.dart';
import 'care_entry.dart';
import 'reminder.dart';
import 'timeline.dart';

enum OccurrenceState { done, missed, due }

class Occurrence {
  final Reminder reminder;
  final DateTime at;
  final OccurrenceState state;
  const Occurrence(this.reminder, this.at, this.state);
}

/// Works out which care tasks are done, due or missed (FR10 to FR12).
class Schedule {
  /// How far back missed items are shown.
  static const missedLookbackDays = 7;

  static List<Occurrence> between(
      List<Reminder> reminders, Timeline timeline, Day from, Day to, DateTime now) {
    final done = <String>{
      for (final e in timeline.ofKind(EntryKind.taskDone))
        '${e.reminderId}@${e.occurrence?.toIso8601String()}',
    };
    final out = <Occurrence>[];
    for (final r in reminders) {
      for (final at in r.occurrences(from, to)) {
        final key = '${r.id}@${at.toIso8601String()}';
        final state = done.contains(key)
            ? OccurrenceState.done
            : at.isBefore(now)
                ? OccurrenceState.missed
                : OccurrenceState.due;
        out.add(Occurrence(r, at, state));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// Today's tasks: everything due today, done or not.
  static List<Occurrence> today(
          List<Reminder> reminders, Timeline timeline, DateTime now) =>
      between(reminders, timeline, Day.of(now), Day.of(now), now);

  /// Missed tasks from the last week, before today, newest first (FR12).
  static List<Occurrence> missedBeforeToday(
      List<Reminder> reminders, Timeline timeline, DateTime now) {
    final today = Day.of(now);
    return between(reminders, timeline, today.addDays(-missedLookbackDays),
            today.addDays(-1), now)
        .where((o) => o.state == OccurrenceState.missed)
        .toList()
        .reversed
        .toList();
  }
}
