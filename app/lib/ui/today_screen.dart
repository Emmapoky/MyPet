import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../config/thresholds.dart';
import '../models/care_entry.dart';
import '../models/pet.dart';
import '../models/schedule.dart';
import '../state/app_state.dart';
import '../util/day.dart';
import 'home_shell.dart';
import 'pet_detail_screen.dart';
import 'pet_edit_screen.dart';
import 'quick_log_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/entry_tile.dart';
import 'widgets/flag_card.dart';
import 'widgets/pet_bar.dart';

/// The time the missed-day reminder fires if a pet is not logged (FR21; Figma "Due by 9:00 pm").
const dailyLogDueMinutes = 21 * 60;

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
        title: const Text('Today'),
        actions: const [SyncBadge(), MoreMenu()],
      ),
      body: pet == null ? const _NoPets() : _TodayBody(pet: pet),
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
            body: 'MyPet keeps a quick daily log, learns what is normal for your pet, '
                'and tells you when something changes.',
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

  String _caption(AppState s) {
    final parts = <String>[pet.species == Species.cat ? 'Cat' : 'Dog'];
    final b = pet.birthDate;
    if (b != null) {
      final now = s.now();
      var months = (now.year - b.year) * 12 + now.month - b.month;
      if (now.day < b.dayOfMonth) months--;
      parts.add(months >= 24 ? '${months ~/ 12} years' : '$months months');
    }
    final logged = s.detectionOf(pet.id)?.loggedDays ?? 0;
    if (logged > 0) parts.add('day $logged of logging');
    return parts.join(' · ');
  }

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
        ? _CareRow('Daily log', _RowState.done, 'Logged ${time(todayLog.createdAt)}')
        : _CareRow('Daily log', now.isAfter(due) ? _RowState.missed : _RowState.todo,
            'Due by ${time(due)}', () => _openLog(context)));

    // Days in the last week with no log, since the pet was added (FR21 shown on Today).
    final loggedDays = {for (final e in logs) e.day};
    final added = Day.of(pet.createdAt);
    final firstLog = logs.isEmpty ? null : logs.map((e) => e.day).reduce((a, b) => a.isBefore(b) ? a : b);
    final start = firstLog == null || added.isBefore(firstLog) ? added : firstLog;
    for (var i = 1; i <= Schedule.missedLookbackDays; i++) {
      final d = today.addDays(-i);
      if (d.isBefore(start)) break;
      if (!loggedDays.contains(d)) {
        rows.add(_CareRow('Daily log', _RowState.missed, 'Missed · ${date(d.asDateTime)}'));
      }
    }

    final done = {
      for (final e in tl.ofKind(EntryKind.taskDone))
        '${e.reminderId}@${e.occurrence?.toIso8601String()}': e.createdAt,
    };
    // Older missed tasks: the latest two here, the rest on the Reminders tab.
    final older = Schedule.missedBeforeToday(s.remindersOf(pet.id), tl, now);
    final occurrences = [
      ...Schedule.today(s.remindersOf(pet.id), tl, now),
      ...older.take(2),
    ];
    for (final o in occurrences) {
      final key = '${o.reminder.id}@${o.at.toIso8601String()}';
      void tick() => s.addEntry(pet.id, EntryKind.taskDone, {
            'reminderId': o.reminder.id,
            'occurrence': o.at.toIso8601String(),
            'title': o.reminder.title,
          });
      rows.add(switch (o.state) {
        OccurrenceState.done =>
          _CareRow(o.reminder.title, _RowState.done, 'Logged ${time(done[key]!)}'),
        OccurrenceState.due => _CareRow(o.reminder.title, _RowState.todo, 'Due by ${time(o.at)}', tick),
        OccurrenceState.missed => _CareRow(
            o.reminder.title,
            _RowState.missed,
            DateUtils.isSameDay(o.at, now) ? 'Missed · ${time(o.at)}' : 'Missed · ${date(o.at)}',
            tick),
      });
    }
    if (older.length > 2) {
      rows.add(_CareRow('${older.length - 2} more missed', _RowState.missed,
          'See Reminders', () => s.goToTab(4)));
    }
    return rows;
  }

  void _openLog(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => QuickLogScreen(pet: pet)));

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space5),
      children: [
        if (logged) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4, vertical: Tokens.space3),
            decoration: BoxDecoration(
              color: c.loggedContainer,
              borderRadius: BorderRadius.circular(Tokens.radiusInput),
            ),
            child: Row(children: [
              Icon(Icons.check_circle_outline_rounded, color: c.onLoggedContainer),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Text('${justSaved ? 'Saved. ' : ''}${pet.name} is logged for today.',
                    style: t.textTheme.titleSmall!.copyWith(color: c.onLoggedContainer)),
              ),
            ]),
          ),
          const SizedBox(height: Tokens.space4),
        ],
        for (final f in flags) ...[
          FlagCard(flag: f, pet: pet, onTap: () => s.goToTab(3)),
          const SizedBox(height: Tokens.space4),
        ],
        if (!logged) ...[
          Row(children: [
            const PetAvatar(),
            const SizedBox(width: Tokens.space4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pet.name, style: t.textTheme.titleLarge),
                Text(_caption(s), style: t.textTheme.bodySmall),
              ]),
            ),
            IconButton.filledTonal(
                tooltip: 'Switch pet',
                style: IconButton.styleFrom(
                  backgroundColor: t.colorScheme.surfaceContainer,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.swap_horiz_rounded),
                onPressed: () => showPetSwitcher(context),
              ),
          ]),
          const SizedBox(height: Tokens.space4),
        ],
        MyCard(
          title: logged ? "${pet.name}'s care today" : "Today's care",
          padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space4, Tokens.space4, Tokens.space2),
          child: Column(children: [for (final r in rows) _CareRowTile(row: r)]),
        ),
        const SizedBox(height: Tokens.space4),
        if (!logged)
          FilledButton.icon(
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Log now'),
            onPressed: () => _openLog(context),
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
          for (final e in recent) EntryTile(entry: e, today: s.today),
        if (logged) ...[
          const SizedBox(height: Tokens.space4),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Log again'),
            onPressed: () => _openLog(context),
          ),
        ],
        if (result != null && !result.ready && result.loggedDays > 0) ...[
          const SizedBox(height: Tokens.space4),
          Text(
            'Insights unlock after ${Thresholds.minLoggedDays} logged days. '
            '${result.loggedDays} of ${Thresholds.minLoggedDays} so far.',
            style: t.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
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
      _RowState.done => (Icons.check_circle_outline_rounded, c.onLoggedContainer, 'Done'),
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
        onTap: row.onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusInput),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
            child: Row(children: [
              const SizedBox(width: Tokens.space2),
              Icon(icon, color: color),
              const SizedBox(width: Tokens.space4),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row.title, style: t.textTheme.titleSmall),
                  Text(row.detail, style: t.textTheme.bodySmall!.copyWith(color: detailColor)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
