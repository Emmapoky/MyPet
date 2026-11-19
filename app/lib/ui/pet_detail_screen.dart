import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/care_entry.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import 'health_record_screen.dart';
import 'pet_edit_screen.dart';
import 'quick_log_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/entry_tile.dart';

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

  void _openEntry(BuildContext context, Pet pet, CareEntry e) {
    final s = context.read<AppState>();
    final canEdit = e.kind == EntryKind.dailyLog || e.kind == EntryKind.healthRecord;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
            subtitle: const Text('Earlier versions are kept and can be recovered'),
            onTap: () {
              Navigator.pop(c);
              s.deleteEntry(e);
            },
          ),
        ]),
      ),
    );
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
      if (pet.weightKg != null) '${pet.weightKg} kg',
      if (!pet.isActive) pet.status.name,
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: Text(pet.name),
        actions: [
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
        Text(details, style: t.textTheme.bodyLarge),
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
          Card(
            child: Column(children: [
              for (final e in tl.current)
                EntryTile(
                  entry: e,
                  today: s.today,
                  onTap: () => _openEntry(context, pet, e),
                ),
            ]),
          ),
        const SizedBox(height: Tokens.space3),
        Text('Added ${DateFormat('d MMM y').format(pet.createdAt)}',
            style: t.textTheme.bodySmall),
      ]),
    );
  }
}
