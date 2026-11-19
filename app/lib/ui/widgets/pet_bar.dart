import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/pet.dart';
import '../../state/app_state.dart';
import '../pet_edit_screen.dart';

IconData speciesIcon(Species s) => Icons.pets;

/// Top bar title: the selected pet, with a menu to switch pets or add one.
class PetSwitcher extends StatelessWidget {
  const PetSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final pet = s.selectedPet;
    if (pet == null) return const Text('MyPet');
    return PopupMenuButton<String>(
      tooltip: 'Switch pet',
      onSelected: (id) {
        if (id == '+') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PetEditScreen()));
        } else {
          s.selectPet(id);
        }
      },
      itemBuilder: (_) => [
        for (final p in s.activePets)
          PopupMenuItem(value: p.id, child: Text('${p.name} (${p.species.name})')),
        const PopupMenuItem(value: '+', child: Text('Add a pet')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(pet.name, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.expand_more),
        ]),
      ),
    );
  }
}

/// Shown while changes made offline are waiting to reach the server (FR06).
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final waiting = context.select<AppState, bool>((s) => s.waitingToSync);
    if (!waiting) return const SizedBox.shrink();
    return const Tooltip(
      message: 'Saved on this phone, waiting to sync',
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Icon(Icons.cloud_upload_outlined, semanticLabel: 'Waiting to sync'),
      ),
    );
  }
}
