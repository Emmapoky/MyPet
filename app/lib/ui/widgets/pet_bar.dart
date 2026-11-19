import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/pet.dart';
import '../../state/app_state.dart';
import '../pet_edit_screen.dart';
import '../theme.dart';

/// Pet avatar: apricot circle with a paw (Figma Today, pet row).
class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: s.secondary, shape: BoxShape.circle),
        child: Icon(Icons.pets_rounded, color: s.onSecondary, size: size * 0.45),
      ),
    );
  }
}

/// Opens a sheet to switch to another pet or add one.
Future<void> showPetSwitcher(BuildContext context) {
  final s = context.read<AppState>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final p in s.activePets)
          ListTile(
            leading: const PetAvatar(size: 40),
            title: Text(p.name),
            subtitle: Text(p.species == Species.cat ? 'Cat' : 'Dog'),
            trailing: p.id == s.selectedPet?.id ? const Icon(Icons.check_rounded) : null,
            onTap: () {
              s.selectPet(p.id);
              Navigator.pop(c);
            },
          ),
        ListTile(
          leading: const Icon(Icons.add_rounded),
          title: const Text('Add a pet'),
          onTap: () {
            Navigator.pop(c);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PetEditScreen()));
          },
        ),
        const SizedBox(height: Tokens.space2),
      ]),
    ),
  );
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
