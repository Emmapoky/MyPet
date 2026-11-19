import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/pet.dart';
import '../models/reminder.dart';
import '../state/app_state.dart';
import '../util/day.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Create or edit a recurring care schedule: start date, end date and frequency (FR10),
/// with a notification ahead of each time (FR11).
class ReminderEditScreen extends StatefulWidget {
  const ReminderEditScreen({super.key, required this.pet, this.reminder});
  final Pet pet;
  final Reminder? reminder;

  @override
  State<ReminderEditScreen> createState() => _ReminderEditScreenState();
}

class _ReminderEditScreenState extends State<ReminderEditScreen> {
  late final title = TextEditingController(text: widget.reminder?.title ?? '');
  late ReminderKind kind = widget.reminder?.kind ?? ReminderKind.feeding;
  late Day start = widget.reminder?.start ?? context.read<AppState>().today;
  late Day? end = widget.reminder?.end;
  late int every = widget.reminder?.everyDays ?? 1;
  late List<int> times = [...(widget.reminder?.times ?? const [8 * 60])];
  late int before = widget.reminder?.notifyBefore ?? 0;
  late bool active = widget.reminder?.active ?? true;

  String _t(int m) => DateFormat.jm().format(DateTime(2000, 1, 1, m ~/ 60, m % 60));

  Future<void> _addTime() async {
    final r = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
    if (r != null) setState(() => times = ({...times, r.hour * 60 + r.minute}.toList()..sort()));
  }

  Future<Day?> _pickDay(Day initial, {Day? first}) async {
    final d = await showDatePicker(
      context: context,
      firstDate: (first ?? Day(2020, 1, 1)).asDateTime,
      lastDate: DateTime(DateTime.now().year + 5),
      initialDate: initial.asDateTime,
    );
    return d == null ? null : Day.of(d);
  }

  Future<void> _save() async {
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    final r = Reminder(
      id: widget.reminder?.id ?? s.backend.newId(),
      petId: widget.pet.id,
      title: title.text.trim(),
      kind: kind,
      start: start,
      end: end,
      everyDays: every,
      times: times,
      notifyBefore: before,
      active: active,
    );
    await s.saveReminder(r);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final valid = title.text.trim().isNotEmpty && times.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(widget.reminder == null ? 'Add reminder' : 'Edit reminder')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
          TextField(
            controller: title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                labelText: 'What', hintText: 'Feed ${widget.pet.name}, give tablet'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Tokens.space4),
          ChoiceRow<ReminderKind>(
            label: 'Type',
            options: const [
              (ReminderKind.feeding, 'Feeding'),
              (ReminderKind.medication, 'Medicine'),
              (ReminderKind.grooming, 'Grooming'),
              (ReminderKind.vet, 'Vet'),
              (ReminderKind.other, 'Other'),
            ],
            selected: kind,
            onSelected: (v) => setState(() => kind = v),
          ),
          const SizedBox(height: Tokens.space4),
          ChoiceRow<int>(
            label: 'How often',
            options: const [(1, 'Every day'), (2, 'Every 2 days'), (7, 'Every week'), (30, 'Every 30 days')],
            selected: every,
            onSelected: (v) => setState(() => every = v),
          ),
          const SectionTitle('Times'),
          Wrap(spacing: Tokens.space2, runSpacing: Tokens.space2, children: [
            for (final m in times)
              InputChip(
                label: Text(_t(m)),
                onDeleted: times.length > 1 ? () => setState(() => times.remove(m)) : null,
                deleteButtonTooltipMessage: 'Remove ${_t(m)}',
              ),
            ActionChip(
              avatar: const Icon(Icons.add),
              label: const Text('Add time'),
              onPressed: _addTime,
            ),
          ]),
          const SizedBox(height: Tokens.space4),
          ChoiceRow<int>(
            label: 'Notify me',
            options: const [(0, 'At the time'), (15, '15 min before'), (60, '1 hour before')],
            selected: before,
            onSelected: (v) => setState(() => before = v),
          ),
          const SizedBox(height: Tokens.space3),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Starts'),
            subtitle: Text(DateFormat('d MMM y').format(start.asDateTime)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final d = await _pickDay(start);
              if (d != null) setState(() => start = d);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ends'),
            subtitle: Text(end == null ? 'No end date' : DateFormat('d MMM y').format(end!.asDateTime)),
            trailing: end == null
                ? const Icon(Icons.calendar_today_outlined)
                : IconButton(
                    tooltip: 'Remove end date',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => end = null),
                  ),
            onTap: () async {
              final d = await _pickDay(end ?? start.addDays(7), first: start);
              if (d != null) setState(() => end = d);
            },
          ),
          if (widget.reminder != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: active,
              onChanged: (v) => setState(() => active = v),
            ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: FilledButton(onPressed: valid ? _save : null, child: const Text('Save')),
        ),
      ),
    );
  }
}
