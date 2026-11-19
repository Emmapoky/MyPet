import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/care_entry.dart';
import '../models/pet.dart';
import '../models/schedule.dart';
import '../notify/reminder_notifications.dart';
import '../state/app_state.dart';
import '../util/day.dart';
import 'feedback.dart';
import 'home_shell.dart';
import 'pet_detail_screen.dart';
import 'pet_edit_screen.dart';
import 'quick_log_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/entry_tile.dart';
import 'widgets/flag_card.dart';
import 'widgets/logo.dart';
import 'widgets/pet_bar.dart';

/// The time the missed-day reminder fires if a pet is not logged (FR21; Figma "Due by 9:00 pm").
const dailyLogDueMinutes = ReminderNotifications.dailyLogMinutes;

/// Today (report Table 4.4 screen 2; Figma screens 02 and 04): pet, today's care with
/// missed items, Log now, timeline.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final pet = s.selectedPet;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: Tokens.space4,
        title: const Row(children: [
          LogoMark(size: 32),
          SizedBox(width: Tokens.space2),
          Text('MyPet'),
        ]),
        actions: const [SyncBadge(), LookToggle(), MoreMenu()],
      ),
      body: PageWash(child: pet == null ? const _NoPets() : _TodayBody(pet: pet)),
    );
  }
}

class _NoPets extends StatelessWidget {
  const _NoPets();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space4),
        children: [
          EmptyState(
            icon: Icons.pets_rounded,
            title: 'Add your cat or dog',
            body: 'Log a few taps a day. MyPet learns their normal.',
            action: FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PetEditScreen())),
              label: const Text('Add a pet'),
            ),
          ),
        ],
      );
}

enum _RowState { todo, done, missed }

class _CareRow {
  final String title;
  final _RowState state;
  final String detail;
  final VoidCallback? onTap;
  const _CareRow(this.title, this.state, this.detail, [this.onTap]);
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.pet});
  final Pet pet;

  List<_CareRow> _rows(BuildContext context, AppState s) {
    final now = s.now();
    final today = s.today;
    final tl = s.timelineOf(pet.id);
    final logs = tl.ofKind(EntryKind.dailyLog);
    String time(DateTime t) => DateFormat.jm().format(t.toLocal()).toLowerCase();
    String date(DateTime t) => DateFormat('EEE d MMM').format(t);

    final rows = <_CareRow>[];
    final todayLog = logs.where((e) => e.day == today).firstOrNull;
    final due = DateTime(now.year, now.month, now.day, dailyLogDueMinutes ~/ 60, dailyLogDueMinutes % 60);
    rows.add(todayLog != null
        ? _CareRow('Daily log', _RowState.done, time(todayLog.createdAt), () => _openLog(context, editing: todayLog))
        : _CareRow('Daily log', now.isAfter(due) ? _RowState.missed : _RowState.todo,
            'By ${time(due)}', () => _openLog(context)));

    // Days in the last week with no log, since the pet was added (FR21 shown on Today).
    final loggedDays = {for (final e in logs) e.day};
    final added = Day.of(pet.createdAt);
    final firstLog = logs.isEmpty ? null : logs.map((e) => e.day).reduce((a, b) => a.isBefore(b) ? a : b);
    final start = firstLog == null || added.isBefore(firstLog) ? added : firstLog;
    for (var i = 1; i <= Schedule.missedLookbackDays; i++) {
      final d = today.addDays(-i);
      if (d.isBefore(start)) break;
      if (!loggedDays.contains(d)) {
        rows.add(_CareRow('Daily log', _RowState.missed, 'Missed ${date(d.asDateTime)}',
            () => _openLog(context, day: d)));
      }
    }

    final done = {
      for (final e in tl.ofKind(EntryKind.taskDone))
        '${e.reminderId}@${e.occurrence?.toIso8601String()}': e,
    };
    final messenger = ScaffoldMessenger.of(context);
    // A wrong tap is easy to fix: Undo on the bar, or tap the done row again.
    void undoable(Future<CareEntry> made, String what) async {
      final e = await made;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(what),
          action: SnackBarAction(label: 'Undo', onPressed: () => s.deleteEntry(e)),
        ));
    }
    // Older missed tasks: the latest two here, the rest on the Reminders tab.
    final older = Schedule.missedBeforeToday(s.remindersOf(pet.id), tl, now);
    final occurrences = [
      ...Schedule.today(s.remindersOf(pet.id), tl, now),
      ...older.take(2),
    ];
    for (final o in occurrences) {
      final key = '${o.reminder.id}@${o.at.toIso8601String()}';
      void tick() => undoable(
          s.addEntry(pet.id, EntryKind.taskDone, {
            'reminderId': o.reminder.id,
            'occurrence': o.at.toIso8601String(),
            'title': o.reminder.title,
          }),
          '${o.reminder.title} done');
      rows.add(switch (o.state) {
        OccurrenceState.done => _CareRow(o.reminder.title, _RowState.done, time(done[key]!.createdAt), () {
            s.deleteEntry(done[key]!);
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text('${o.reminder.title} not done')));
          }),
        OccurrenceState.due => _CareRow(o.reminder.title, _RowState.todo, 'By ${time(o.at)}', tick),
        OccurrenceState.missed => _CareRow(
            o.reminder.title,
            _RowState.missed,
            DateUtils.isSameDay(o.at, now) ? 'Missed ${time(o.at)}' : 'Missed ${date(o.at)}',
            tick),
      });
    }
    if (older.length > 2) {
      rows.add(_CareRow('${older.length - 2} more missed', _RowState.missed, '', () => s.goToTab(4)));
    }
    return rows;
  }

  void _openLog(BuildContext context, {Day? day, CareEntry? editing}) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => QuickLogScreen(pet: pet, day: day, editing: editing)));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final timeline = s.timelineOf(pet.id);
    final logged = s.loggedToday(pet.id);
    final todayLog = timeline.lastDailyLog;
    final justSaved = logged &&
        todayLog != null &&
        s.now().difference(todayLog.createdAt.toLocal()).inMinutes.abs() < 10;
    final result = s.detectionOf(pet.id);
    final flags = result?.ready == true ? result!.flags : const [];
    final recent = timeline.current.take(6).toList();
    final rows = _rows(context, s);

    final pets = s.activePets;
    final loggedCount = pets.where((p) => s.loggedToday(p.id)).length;
    final tasks = rows.where((r) => r.state != _RowState.missed || r.detail.isNotEmpty).toList();
    final tasksDone = rows.where((r) => r.state == _RowState.done).length;
    final accent = c.petAccent(pet.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space5),
      children: [
        HeroCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_greeting(s.now()),
                      style: t.textTheme.headlineSmall!.copyWith(color: Colors.white)),
                  Text(DateFormat('EEEE d MMMM').format(s.now()),
                      style: t.textTheme.titleSmall!.copyWith(color: Colors.white)),
                ]),
              ),
              PetAvatar(pet: pet, size: 52, onHero: true),
            ]),
            const SizedBox(height: Tokens.space4),
            Row(children: [
              HeroStat(value: '$loggedCount/${pets.length}', caption: 'logged'),
              const SizedBox(width: Tokens.space2),
              HeroStat(value: '$tasksDone/${tasks.length}', caption: 'done'),
              const SizedBox(width: Tokens.space2),
              HeroStat(value: '${flags.length}', caption: 'to look at'),
            ]),
          ]),
        ),
        const SizedBox(height: Tokens.space4),
        if (pets.length > 1) ...[
          PetStrip(pets: pets, selected: pet.id),
          const SizedBox(height: Tokens.space4),
        ],
        for (final f in flags) ...[
          FlagCard(flag: f, pet: pet, compact: true, onTap: () => s.goToTab(3)),
          const SizedBox(height: Tokens.space4),
        ],
        if (logged)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4, vertical: Tokens.space3),
            decoration: BoxDecoration(
              color: c.loggedContainer,
              borderRadius: BorderRadius.circular(Tokens.radiusInput),
            ),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: c.loggedEdge),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Text(justSaved ? 'Saved' : '${pet.name} is logged',
                    style: t.textTheme.titleSmall!.copyWith(color: c.onLoggedContainer)),
              ),
            ]),
          )
        else
          FilledButton.icon(
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Log now'),
            onPressed: () => _openLog(context),
          ),
        const SizedBox(height: Tokens.space4),
        MyCard(
          title: "${pet.name}'s day",
          accent: accent,
          padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space4, Tokens.space4, Tokens.space2),
          child: Column(children: [for (final r in rows) _CareRowTile(row: r)]),
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
          Text('Nothing yet', style: t.textTheme.bodyMedium)
        else
          MyCard(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space3, vertical: Tokens.space2),
            child: Column(children: [
              for (final e in recent)
                EntryTile(entry: e, today: s.today, dot: accent, onTap: () => openEntrySheet(context, pet, e)),
            ]),
          ),
        if (logged) ...[
          const SizedBox(height: Tokens.space4),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Edit today'),
            onPressed: () => _openLog(context,
                editing: s.timelineOf(pet.id).ofKind(EntryKind.dailyLog).where((e) => e.day == s.today).firstOrNull),
          ),
        ],
      ],
    );
  }

  static String _greeting(DateTime now) => switch (now.hour) {
        >= 5 && < 12 => 'Good morning',
        >= 12 && < 18 => 'Good afternoon',
        _ => 'Good evening',
      };
}

class _CareRowTile extends StatelessWidget {
  const _CareRowTile({required this.row});
  final _CareRow row;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final (icon, color, label) = switch (row.state) {
      _RowState.todo => (Icons.radio_button_unchecked_rounded, t.colorScheme.outline, 'To do'),
      _RowState.done => (Icons.check_circle_rounded, c.loggedEdge, 'Done'),
      _RowState.missed => (Icons.error_outline_rounded, c.onChangeContainer, 'Missed'),
    };
    final detailColor = switch (row.state) {
      _RowState.todo => t.colorScheme.onSurfaceVariant,
      _RowState.done => c.onLoggedContainer,
      _RowState.missed => c.onChangeContainer,
    };
    return Semantics(
      label: '${row.title}, $label, ${row.detail}',
      button: row.onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: row.onTap == null ? null : () {
          Feel.tap();
          row.onTap!();
        },
        borderRadius: BorderRadius.circular(Tokens.radiusInput),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
            child: Row(children: [
              const SizedBox(width: Tokens.space2),
              Icon(icon, color: color),
              const SizedBox(width: Tokens.space4),
              Expanded(child: Text(row.title, style: t.textTheme.titleSmall)),
              if (row.detail.isNotEmpty)
                Text(row.detail, style: t.textTheme.bodySmall!.copyWith(color: detailColor)),
              const SizedBox(width: Tokens.space2),
            ]),
          ),
        ),
      ),
    );
  }
}
