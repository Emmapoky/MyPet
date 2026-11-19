import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/care_entry.dart';
import '../models/schedule.dart';
import '../state/app_state.dart';
import 'pet_detail_screen.dart';
import 'pet_edit_screen.dart';
import 'quick_log_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/entry_tile.dart';
import 'widgets/flag_card.dart';
import 'widgets/pet_bar.dart';

/// Today (report Table 4.4 screen 2): checklist, missed items, quick log button, timeline.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final pet = s.selectedPet;
    return Scaffold(
      appBar: AppBar(
        title: const PetSwitcher(),
        actions: [
          const SyncBadge(),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: pet == null ? const _NoPets() : _TodayBody(petId: pet.id),
    );
  }
}

class _NoPets extends StatelessWidget {
  const _NoPets();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(Tokens.space4),
        children: [
          EmptyState(
            icon: Icons.pets,
            title: 'Add your cat or dog',
            body: 'MyPet keeps a quick daily log, learns what is normal for your pet, '
                'and tells you when something changes.',
            action: FilledButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PetEditScreen())),
              child: const Text('Add a pet'),
            ),
          ),
        ],
      );
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.petId});
  final String petId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final pet = s.selectedPet!;
    final t = Theme.of(context);
    final timeline = s.timelineOf(petId);
    final reminders = s.remindersOf(petId);
    final now = s.now();
    final todayTasks = Schedule.today(reminders, timeline, now);
    final missed = Schedule.missedBeforeToday(reminders, timeline, now);
    final logged = s.loggedToday(petId);
    final flags = s.detectionOf(petId)?.flags ?? const [];
    final recent = timeline.current.take(5).toList();

    return ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
      Text(DateFormat('EEEE d MMMM').format(now), style: t.textTheme.bodyMedium),
      for (final f in flags) ...[
        const SizedBox(height: Tokens.space3),
        FlagCard(flag: f, pet: pet),
      ],
      SectionTitle('Today'),
      Card(
        child: Column(children: [
          if (todayTasks.isEmpty)
            const ListTile(
              title: Text('No care tasks today'),
              subtitle: Text('Add feeding or medicine times in Reminders.'),
            ),
          for (final o in todayTasks) _TaskTile(o: o, petId: petId),
          if (missed.isNotEmpty) ...[
            const Divider(height: 1),
            for (final o in missed) _TaskTile(o: o, petId: petId),
          ],
        ]),
      ),
      const SizedBox(height: Tokens.space4),
      if (logged)
        Container(
          margin: const EdgeInsets.only(bottom: Tokens.space3),
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space4, vertical: Tokens.space3),
          decoration: BoxDecoration(
            color: MyPetColors.of(context).loggedContainer,
            borderRadius: BorderRadius.circular(Tokens.radiusCard),
          ),
          child: Row(children: [
            Icon(Icons.check_circle, color: MyPetColors.of(context).onLoggedContainer, size: 20),
            const SizedBox(width: Tokens.space2),
            Expanded(
              child: Text('${pet.name} is logged for today',
                  style: t.textTheme.titleSmall!
                      .copyWith(color: MyPetColors.of(context).onLoggedContainer)),
            ),
          ]),
        ),
      FilledButton.icon(
        icon: const Icon(Icons.add),
        label: Text(logged ? 'Log again' : 'Log now'),
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => QuickLogScreen(pet: pet))),
      ),
      SectionTitle(
        'Timeline',
        trailing: TextButton(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PetDetailScreen(petId: pet.id))),
          child: const Text('See all'),
        ),
      ),
      if (recent.isEmpty)
        Text('Nothing logged yet.', style: t.textTheme.bodyMedium)
      else
        Card(
          child: Column(children: [
            for (final e in recent) EntryTile(entry: e, today: s.today),
          ]),
        ),
      const SizedBox(height: Tokens.space5),
    ]);
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.o, required this.petId});
  final Occurrence o;
  final String petId;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final c = MyPetColors.of(context);
    final time = DateFormat.jm().format(o.at);
    final missed = o.state == OccurrenceState.missed;
    final isToday = DateUtils.isSameDay(o.at, s.now());
    final when = isToday ? time : '${DateFormat('EEE d MMM').format(o.at)}, $time';
    return CheckboxListTile(
      value: o.state == OccurrenceState.done,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(o.reminder.title),
      subtitle: missed
          ? Row(children: [
              Icon(Icons.schedule, size: 16, color: c.onChangeContainer),
              const SizedBox(width: Tokens.space1),
              Flexible(child: Text('Missed · $when', style: TextStyle(color: c.onChangeContainer))),
            ])
          : Text(when),
      onChanged: o.state == OccurrenceState.done
          ? null
          : (_) => s.addEntry(petId, EntryKind.taskDone, {
                'reminderId': o.reminder.id,
                'occurrence': o.at.toIso8601String(),
                'title': o.reminder.title,
              }),
    );
  }
}
