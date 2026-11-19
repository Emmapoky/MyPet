import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/reminder.dart';
import '../models/schedule.dart';
import '../state/app_state.dart';
import 'home_shell.dart';
import 'reminder_edit_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/pet_bar.dart';

String everyText(Reminder r) => switch (r.everyDays) {
      1 => 'Every day',
      7 => 'Every week',
      final n => 'Every $n days',
    };

String timesText(Reminder r) => r.times
    .map((m) => DateFormat.jm().format(DateTime(2000, 1, 1, m ~/ 60, m % 60)))
    .join(', ');

/// Care schedules for the selected pet (FR10) and missed items (FR12).
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final pet = s.selectedPet;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          const SyncBadge(),
          const MoreMenu(),
        ],
      ),
      floatingActionButton: pet == null
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              icon: const Icon(Icons.add_alert_rounded),
              label: const Text('Add reminder'),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReminderEditScreen(pet: pet))),
            ),
      body: pet == null
          ? const SizedBox()
          : Builder(builder: (context) {
              final reminders = s.remindersOf(pet.id);
              final missed = Schedule.missedBeforeToday(
                  reminders, s.timelineOf(pet.id), s.now());
              return ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
                if (s.activePets.length > 1) ...[
                  PetStrip(pets: s.activePets, selected: pet.id, onSelect: () {}),
                  const SizedBox(height: Tokens.space4),
                ],
                if (reminders.isEmpty)
                  EmptyState(
                    icon: Icons.alarm,
                    title: 'No reminders for ${pet.name}',
                    body: 'Add feeding, medicine or grooming times. MyPet reminds you '
                        'and shows anything missed.',
                  )
                else
                  Card(
                    child: Column(children: [
                      for (final r in reminders)
                        ListTile(
                          leading: Icon(r.active ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
                          title: Text(r.title),
                          subtitle: Text([
                            everyText(r),
                            timesText(r),
                            if (!r.active) 'paused',
                          ].join(' · ')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ReminderEditScreen(pet: pet, reminder: r))),
                        ),
                    ]),
                  ),
                if (missed.isNotEmpty) ...[
                  const SectionTitle('Missed in the last week'),
                  Card(
                    child: Column(children: [
                      for (final o in missed)
                        ListTile(
                          leading: Icon(Icons.schedule, color: MyPetColors.of(context).onChangeContainer),
                          title: Text(o.reminder.title),
                          subtitle: Text(DateFormat('EEE d MMM, h:mm a').format(o.at)),
                        ),
                    ]),
                  ),
                ],
                const SizedBox(height: 80),
              ]);
            }),
    );
  }
}
