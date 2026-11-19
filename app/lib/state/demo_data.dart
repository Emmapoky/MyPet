import '../detection/synthetic_logs.dart';
import '../models/care_entry.dart';
import '../models/pet.dart';
import '../models/reminder.dart';
import 'app_state.dart';

/// Adds two demo pets with 30 days of made-up logs, for demos and walkthroughs
/// (stack plan section 7: a seeded pet with one planted change). Biscuit's energy is 1
/// on 2 of the last 3 days, so Insights shows a flag; Mochi has none.
Future<void> addDemoPets(AppState s) async {
  final today = s.today;
  final first = today.addDays(-29);

  Future<void> one(String name, Species sp, String breed, double w, int seed, bool lowEnergyDemo) async {
    final pet = await s.addPet(name: name, species: sp, breed: breed, weightKg: w);
    var logs = SyntheticLogs(seed).pet(petId: pet.id, first: first, days: 27);
    // The last 3 days are written out so the demo always shows the same thing.
    for (var i = 0; i < 3; i++) {
      final d = today.addDays(i - 2);
      final low = lowEnergyDemo && i != 1;
      logs = [
        ...logs,
        CareEntry(
          id: 'x',
          petId: pet.id,
          kind: EntryKind.dailyLog,
          day: d,
          createdAt: d.asDateTime.add(const Duration(hours: 8)),
          createdBy: '',
          data: {'ate': true, 'energy': low ? 1 : 4, 'toiletingNormal': true},
        ),
      ];
    }
    for (final e in logs) {
      await s.backend.addEntry(CareEntry(
        id: s.backend.newId(),
        petId: pet.id,
        kind: EntryKind.dailyLog,
        day: e.day,
        createdAt: e.createdAt,
        createdBy: s.carer!.id,
        data: e.data,
      ));
    }
    await s.saveReminder(Reminder(
      id: s.backend.newId(),
      petId: pet.id,
      title: 'Breakfast',
      kind: ReminderKind.feeding,
      start: first,
      times: const [8 * 60],
    ));
  }

  await one('Mochi', Species.cat, 'Domestic shorthair', 4.2, 11, false);
  await one('Biscuit', Species.dog, 'Shiba Inu', 10.5, 7, true);
}
