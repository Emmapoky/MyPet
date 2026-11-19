import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/care_entry.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import '../util/day.dart';
import 'theme.dart';

/// A dated health record against a pet (FR02), such as a vet visit or vaccination.
class HealthRecordScreen extends StatefulWidget {
  const HealthRecordScreen({super.key, required this.pet, this.editing});
  final Pet pet;
  final CareEntry? editing;

  @override
  State<HealthRecordScreen> createState() => _HealthRecordScreenState();
}

class _HealthRecordScreenState extends State<HealthRecordScreen> {
  late final title = TextEditingController(text: widget.editing?.title ?? '');
  late final note = TextEditingController(text: widget.editing?.note ?? '');
  late Day day = widget.editing?.day ?? context.read<AppState>().today;

  Future<void> _save() async {
    if (title.text.trim().isEmpty) return;
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    final data = {
      'title': title.text.trim(),
      if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
    };
    if (widget.editing != null) {
      await s.editEntry(widget.editing!, data, day: day);
    } else {
      await s.addEntry(widget.pet.id, EntryKind.healthRecord, data, day: day);
    }
    nav.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Health record')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
            TextField(
              controller: title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'What happened', hintText: 'Vet visit, vaccination, medicine given'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Tokens.space4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat('d MMMM y').format(day.asDateTime)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  initialDate: day.asDateTime,
                );
                if (d != null) setState(() => day = Day.of(d));
              },
            ),
            const SizedBox(height: Tokens.space2),
            TextField(
              controller: note,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space4),
            child: FilledButton(
              onPressed: title.text.trim().isEmpty ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ),
      );
}
