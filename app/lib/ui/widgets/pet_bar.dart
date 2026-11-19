import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/pet.dart';
import '../../state/app_state.dart';
import '../pet_edit_screen.dart';
import '../theme.dart';

/// Pet avatar: a paw in the pet's own colour, as in the SwiftUI app.
class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, this.pet, this.size = 56, this.onHero = false});
  final Pet? pet;
  final double size;

  /// White circle for use on the coral hero card.
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final c = MyPetColors.of(context);
    final accent = pet == null ? c.brandStrong : c.petAccent(pet!.id);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: onHero ? Colors.white : accent,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.pets_rounded, color: onHero ? accent : Colors.white, size: size * 0.48),
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
            leading: PetAvatar(pet: p, size: 40),
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

/// One coloured chip per pet; tap to switch (each pet keeps its colour everywhere).
class PetStrip extends StatelessWidget {
  const PetStrip({super.key, required this.pets, required this.selected, this.onSelect});
  final List<Pet> pets;
  final String selected;

  /// Called after a pet is picked; also hides the add button when set.
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final s = context.read<AppState>();
    return SizedBox(
      height: Tokens.minTarget,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final p in pets) ...[
          Semantics(
            selected: p.id == selected,
            button: true,
            label: p.name,
            excludeSemantics: true,
            child: Material(
              color: p.id == selected ? c.petAccent(p.id) : t.colorScheme.surface,
              shape: StadiumBorder(side: BorderSide(color: c.petAccent(p.id), width: 1.5)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () {
                  s.selectPet(p.id);
                  onSelect?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
                  child: Row(children: [
                    Icon(Icons.pets_rounded,
                        size: 18, color: p.id == selected ? Colors.white : c.petAccent(p.id)),
                    const SizedBox(width: Tokens.space2),
                    Text(p.name,
                        style: t.textTheme.titleSmall!
                            .copyWith(color: p.id == selected ? Colors.white : t.colorScheme.onSurface)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: Tokens.space2),
        ],
        if (onSelect == null)
        Center(
          child: IconButton(
            tooltip: 'Add a pet',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PetEditScreen())),
            icon: const Icon(Icons.add_rounded),
          ),
        ),
      ]),
    );
  }
}

