import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../export/vet_pdf.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import 'theme.dart';

/// Pick a date range and share the PDF (FR04): to Files, AirDrop, email or a printer.
Future<void> showVetExport(BuildContext context, Pet pet) async {
  final days = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.space4, 0, Tokens.space4, Tokens.space2),
          child: Text('Export ${pet.name}\'s record', style: Theme.of(c).textTheme.titleMedium),
        ),
        for (final d in const [7, 30, 90])
          ListTile(
            leading: const Icon(Icons.date_range_rounded),
            title: Text('Last $d days'),
            onTap: () => Navigator.pop(c, d),
          ),
        const SizedBox(height: Tokens.space2),
      ]),
    ),
  );
  if (days == null || !context.mounted) return;
  final s = context.read<AppState>();
  final box = context.findRenderObject() as RenderBox?;
  final to = s.today;
  final bytes = await buildVetPdf(
    pet: pet,
    timeline: s.timelineOf(pet.id),
    detection: s.detectionOf(pet.id),
    from: to.addDays(-(days - 1)),
    to: to,
    now: s.now(),
  );
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/MyPet ${pet.name} last $days days.pdf');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'application/pdf')],
    subject: 'MyPet record: ${pet.name}',
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  ));
}
