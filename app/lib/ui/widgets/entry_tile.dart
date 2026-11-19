import 'package:material_ui/material_ui.dart';

import '../../models/care_entry.dart';
import '../wording.dart';
import '../../util/day.dart';

IconData entryIcon(EntryKind k) => switch (k) {
      EntryKind.dailyLog => Icons.edit_note,
      EntryKind.healthRecord => Icons.medical_information_outlined,
      EntryKind.behaviourResult => Icons.graphic_eq,
      EntryKind.taskDone => Icons.task_alt,
    };

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, required this.today, this.onTap});
  final CareEntry entry;
  final Day today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final note = entry.note;
    return ListTile(
      leading: Icon(entryIcon(entry.kind)),
      title: Text(Wording.entrySummary(entry)),
      subtitle: Text([
        '${Wording.entryTitle(entry.kind)} · ${Wording.day(entry.day, today)}',
        if (note.isNotEmpty) note,
      ].join('\n')),
      isThreeLine: note.isNotEmpty,
      onTap: onTap,
      minTileHeight: 56,
    );
  }
}
