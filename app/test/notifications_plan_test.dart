import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/local_backend.dart';
import 'package:mypet/models/care_entry.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/models/reminder.dart';
import 'package:mypet/notify/reminder_notifications.dart';
import 'package:mypet/state/app_state.dart';
import 'package:mypet/util/day.dart';

void main() {
  Future<AppState> make(DateTime now) async {
    final b = LocalBackend();
    final s = AppState(b, clock: () => now, detectInBackground: false);
    await b.signIn('', '');
    await Future<void>.delayed(Duration.zero);
    return s;
  }

  test('FR21: one "time to log" reminder a day, none today once every pet is logged', () async {
    final now = DateTime(2027, 3, 15, 10);
    final s = await make(now);
    final milo = await s.addPet(name: 'Milo', species: Species.dog);
    await s.addPet(name: 'Mochi', species: Species.cat);
    await Future<void>.delayed(Duration.zero);

    var daily = ReminderNotifications.plan(s).where((p) => p.daily).toList();
    expect(daily, hasLength(7));
    expect(daily.first.at, DateTime(2027, 3, 15, 21));
    expect(daily.first.title, "Time to log Milo and Mochi's day");
    expect(daily.first.body, 'Hold to answer here, or tap to open.');
    s.setDoors(s.doors.copyWith(reminderButtons: false));
    expect(ReminderNotifications.plan(s).firstWhere((p) => p.daily).body, 'Tap to log.');
    s.setDoors(s.doors.copyWith(reminderButtons: true));

    await s.addEntry(milo.id, EntryKind.dailyLog, {
      'ate': true,
      'energy': 4,
      'toiletingNormal': true,
    });
    await Future<void>.delayed(Duration.zero);
    daily = ReminderNotifications.plan(s).where((p) => p.daily).toList();
    expect(daily.first.title, "Time to log Mochi's day");
  });

  test(
    'FR11: a care task is notified ahead of its time, only in the future',
    () async {
      final now = DateTime(2027, 3, 15, 10);
      final s = await make(now);
      final milo = await s.addPet(name: 'Milo', species: Species.dog);
      await s.saveReminder(
        Reminder(
          id: 'r',
          petId: milo.id,
          title: 'Heartworm tablet',
          start: Day(2027, 3, 1),
          times: const [8 * 60, 18 * 60],
          notifyBefore: 15,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final tasks = ReminderNotifications.plan(s)
          .where((p) => !p.daily)
          .toList();
      expect(
        tasks.first.at,
        DateTime(2027, 3, 15, 17, 45),
      ); // 8:00 today is already past
      expect(tasks.first.title, 'Milo: Heartworm tablet');
      expect(tasks, hasLength(13)); // 6 more days x 2, plus 6 pm today
    },
  );
}
