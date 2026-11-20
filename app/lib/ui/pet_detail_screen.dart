import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/care_entry.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import 'check_screen.dart';
import 'widgets/guide_target.dart';
import 'widgets/clip_keep.dart';
import 'health_record_screen.dart';
import 'pet_edit_screen.dart';
import 'quick_log_screen.dart';
import 'widgets/starter_card.dart';
import 'theme.dart';
import 'vet_export.dart';
import 'widgets/common.dart';
import 'widgets/entry_tile.dart';
import 'widgets/pet_photo.dart';

/// A pet's profile and its one timeline across logs, care tasks, health records and
/// behaviour checks, newest first (FR03).
class PetDetailScreen extends StatelessWidget {
  const PetDetailScreen({super.key, required this.petId});
  final String petId;

  String _age(Pet p, DateTime now) {
    if (p.birthDate == null) return '';
    final b = p.birthDate!.asDateTime;
    var months = (now.year - b.year) * 12 + now.month - b.month;
    if (now.day < b.day) months--;
    return months >= 24 ? '${months ~/ 12} years' : '$months months';
  }

  Future<void> _setStatus(BuildContext context, Pet pet, PetStatus status) async {
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(switch (status) {
          PetStatus.archived => 'Archive ${pet.name}?',
          PetStatus.rehomed => 'Mark ${pet.name} as rehomed?',
          PetStatus.deceased => 'Mark ${pet.name} as passed away?',
          PetStatus.active => 'Make ${pet.name} active again?',
        }),
        content: const Text('The record is kept. Reminders for this pet stop.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;
    await s.updatePet(pet.copyWith(status: status));
    for (final r in s.remindersOf(pet.id)) {
      if (status != PetStatus.active && r.active) await s.saveReminder(r.copyWith(active: false));
    }
    if (status != PetStatus.active) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final pet = s.pets.where((p) => p.id == petId).firstOrNull;
    if (pet == null) return const Scaffold(body: SizedBox());
    final t = Theme.of(context);
    final tl = s.timelineOf(petId);
    final details = [
      pet.species == Species.cat ? 'Cat' : 'Dog',
      if (pet.breed.isNotEmpty) pet.breed,
      if (pet.birthDate != null) _age(pet, s.now()),
      if (s.currentWeight(pet) != null) '${s.currentWeight(pet)!.toStringAsFixed(1)} kg',
      if (!pet.isActive) statusWord(pet.status),
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: Text(pet.name),
        actions: [
          GuideTarget(id: 'pdf', child: IconButton(
            tooltip: 'Export for the vet',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () => showVetExport(context, pet),
          )),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) => switch (v) {
              'edit' => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PetEditScreen(pet: pet))),
              'archive' => _setStatus(context, pet, PetStatus.archived),
              'rehomed' => _setStatus(context, pet, PetStatus.rehomed),
              'deceased' => _setStatus(context, pet, PetStatus.deceased),
              _ => _setStatus(context, pet, PetStatus.active),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit profile')),
              if (pet.isActive) ...const [
                PopupMenuItem(value: 'archive', child: Text('Archive')),
                PopupMenuItem(value: 'rehomed', child: Text('Mark as rehomed')),
                PopupMenuItem(value: 'deceased', child: Text('Mark as passed away')),
              ] else
                const PopupMenuItem(value: 'active', child: Text('Make active again')),
            ],
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
        // The pet's photo: tap to add or change it (kept on this phone only).
        Center(child: GuideTarget(id: 'photo', child: PetPhotoButton(pet: pet, size: 120, onTap: () => changePetPhoto(context, pet)))),
        if (pet.photo == null)
          Center(
            child: TextButton(
              onPressed: () => changePetPhoto(context, pet),
              child: Text('Add a photo of ${pet.name}'),
            ),
          )
        else
          const SizedBox(height: Tokens.space3),
        Text(details, style: t.textTheme.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: Tokens.space4),
        if (pet.isActive)
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Daily log'),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => QuickLogScreen(pet: pet))),
              ),
            ),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.medical_information_outlined),
                label: const Text('Health record'),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => HealthRecordScreen(pet: pet))),
              ),
            ),
          ]),
        if (pet.isActive) ...[
          const SizedBox(height: Tokens.space2),
          Align(
            alignment: Alignment.centerLeft,
            child: GuideTarget(id: 'changed', child: TextButton.icon(
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Something changed'),
              onPressed: () => showSomethingChanged(context, pet),
            )),
          ),
          const SizedBox(height: Tokens.space2),
          StarterCard(
            pet: pet,
            today: s.today,
            weightKg: s.currentWeight(pet),
            learning: !(s.detectionOf(pet.id)?.ready ?? false),
            onEdit: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PetEditScreen(pet: pet))),
          ),
        ],
        SectionTitle('Timeline (${tl.current.length})'),
        if (tl.conflicts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space2),
            child: Text(
              '${tl.conflicts.length} entry was edited on two phones at once. '
              'The newest edit is shown; the other is kept.',
              style: t.textTheme.bodySmall,
            ),
          ),
        if (tl.current.isEmpty)
          Text('Nothing logged yet.', style: t.textTheme.bodyMedium)
        else
          MyCard(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4, vertical: Tokens.space2),
            child: Column(children: [
              for (final e in tl.current)
                () {
                  final tile = EntryTile(
                    entry: e,
                    today: s.today,
                    onTap: () => openEntrySheet(context, pet, e),
                  );
                  // The newest saved check, for the demo's "tap one to replay it".
                  final firstCheck = tl.current.firstWhere((x) => x.kind == EntryKind.behaviourResult, orElse: () => e);
                  return e.kind == EntryKind.behaviourResult && identical(e, firstCheck)
                      ? GuideTarget(id: 'savedCheck', child: tile)
                      : tile;
                }(),
            ]),
          ),
        const SizedBox(height: Tokens.space3),
        Text('Added ${DateFormat('d MMM y').format(pet.createdAt)}',
            style: t.textTheme.bodySmall),
      ]),
    );
  }
}

/// Edit or delete one entry (used by Today and the pet page). Delete can be undone.
void openEntrySheet(BuildContext context, Pet pet, CareEntry e) {
  final s = context.read<AppState>();
  if (e.kind == EntryKind.behaviourResult) {
    // A saved check opens as its result, to look back on or compare.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (c) => SavedCheckScreen(
        pet: pet,
        entry: e,
        onDelete: () {
          Navigator.pop(c);
          final messenger = ScaffoldMessenger.of(context);
          s.deleteEntry(e).then((gone) => messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: const Text('Deleted'),
              action: SnackBarAction(label: 'Undo', onPressed: () => s.editEntry(gone, e.data)),
            )).closed.then((why) {
              // Its kept clip goes too, unless the delete was undone.
              if (why != SnackBarClosedReason.action) deleteKeptClip(s, e);
            }));
        },
      ),
    ));
    return;
  }
  final canEdit = e.kind == EntryKind.dailyLog || (e.kind == EntryKind.healthRecord && e.data['type'] != 'change');
  // Who logged it (household, review change 9). Invites need the cloud stage, so for now
  // this is "you", the notification, or another carer on a shared phone.
  final by = e.data['source'] == 'notification'
      ? 'Logged by you from the notification'
      : e.createdBy == s.carer?.id
          ? 'Logged by you'
          : 'Logged by another carer';
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Text('$by, ${DateFormat('EEE d MMM, h:mm a').format(e.createdAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall),
        ),
        if (canEdit)
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(c);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => e.kind == EntryKind.dailyLog
                    ? QuickLogScreen(pet: pet, editing: e)
                    : HealthRecordScreen(pet: pet, editing: e),
              ));
            },
          ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Delete'),
                    onTap: () {
            Navigator.pop(c);
            final messenger = ScaffoldMessenger.of(context);
            s.deleteEntry(e).then((gone) => messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: const Text('Deleted'),
                // Writing the old version again brings it back (versions are kept, FR-N04).
                action: SnackBarAction(
                    label: 'Undo', onPressed: () => s.editEntry(gone, e.data)),
              )));
          },
        ),
      ]),
    ),
  );
}

/// "Something changed" (review change 7): new food, a move, medicine. One tap marks the day,
/// and MyPet starts a fresh baseline for the measures it affects, noted on any flag.
Future<void> showSomethingChanged(BuildContext context, Pet pet) async {
  const options = <(String, String, List<String>)>[
    ('New food or portion', 'Eating and weight', ['ate', 'weight']),
    ('Started or stopped a medicine', 'Everything', []),
    ('Moved house or a new routine', 'Energy, eating and toileting', ['energy', 'ate', 'toileting', 'accidents']),
    ('A new pet or person at home', 'Energy, eating and toileting', ['energy', 'ate', 'toileting', 'accidents']),
    ('Neutered or spayed', 'Everything', []),
    ('Something else', 'Everything', []),
  ];
  final s = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final pick = await showModalBottomSheet<(String, String, List<String>)>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.space4, 0, Tokens.space4, Tokens.space2),
          child: Text("What changed for ${pet.name}? MyPet starts learning ${pet.name}'s usual again from today "
              'for what it affects, so the change is not flagged.',
              style: Theme.of(c).textTheme.bodyMedium),
        ),
        for (final o in options)
          ListTile(
            title: Text(o.$1),
            subtitle: Text('Fresh start for: ${o.$2}'),
            onTap: () => Navigator.pop(c, o),
          ),
      ]),
    ),
  );
  if (pick == null) return;
  final e = await s.addEntry(pet.id, EntryKind.healthRecord, {
    'type': 'change',
    'title': pick.$1,
    'measures': pick.$3,
  });
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('Noted: ${pick.$1}'),
      action: SnackBarAction(label: 'Undo', onPressed: () => s.deleteEntry(e)),
    ));
}
