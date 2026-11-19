import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/care_entry.dart';
import '../../util/day.dart';
import '../theme.dart';
import '../wording.dart';

/// Timeline row: time column, a dot in the pet's colour, title, detail.
class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, required this.today, this.onTap, this.dot});
  final CareEntry entry;

  /// The pet's colour; teal when not given.
  final Color? dot;
  final Day today;
  final VoidCallback? onTap;

  String get _when {
    if (entry.day == today) return DateFormat.jm().format(entry.createdAt.toLocal()).toLowerCase();
    final diff = today.difference(entry.day);
    if (diff < 7) return DateFormat.E().format(entry.day.asDateTime);
    return DateFormat('d MMM').format(entry.day.asDateTime);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final detail = [
      Wording.entryDetail(entry),
      if (entry.note.isNotEmpty) entry.note,
    ].where((x) => x.isNotEmpty).join('\n');
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Tokens.minTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ConstrainedBox(
              // Grows with large text instead of cutting the time off.
              constraints: BoxConstraints(minWidth: 64 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0)),
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(_when, style: t.textTheme.bodySmall),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 7, right: Tokens.space3),
              child: ExcludeSemantics(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: dot ?? t.colorScheme.primary, shape: BoxShape.circle),
                ),
              ),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(Wording.entryTitleOf(entry), style: t.textTheme.titleSmall),
                if (detail.isNotEmpty) Text(detail, style: t.textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
