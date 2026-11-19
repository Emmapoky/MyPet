import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../feedback.dart';

import 'package:provider/provider.dart';

import '../../models/pet.dart';
import '../../state/app_state.dart';
import '../pet_edit_screen.dart';
import '../theme.dart';
import 'pet_portrait.dart';

/// Pet picture: the carer's photo if they added one, otherwise a drawn cat or dog
/// face on the pet's own colour.
class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, this.pet, this.size = 56, this.onHero = false});
  final Pet? pet;
  final double size;

  /// White ring for use on the hero card.
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final c = MyPetColors.of(context);
    final p = pet;
    final Widget face;
    if (p == null) {
      face = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c.brandStrong, shape: BoxShape.circle),
        child: Icon(Icons.pets_rounded, color: Colors.white, size: size * 0.48),
      );
    } else {
      final file = petPhotoFile(context.read<AppState>(), p);
      face = file != null
          ? ClipOval(child: Image.file(file, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true))
          : PetPortrait.of(p, background: c.petAccent(p), size: size);
    }
    return ExcludeSemantics(
      child: onHero
          ? Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: face,
            )
          : face,
    );
  }
}

/// The pet's photo on this phone, if there is one.
File? petPhotoFile(AppState s, Pet p) {
  final dir = s.photoDir, name = p.photo;
  if (dir == null || name == null) return null;
  final f = File('$dir/$name');
  return f.existsSync() ? f : null;
}

/// Opens a sheet to switch to another pet or add one.
Future<void> showPetSwitcher(BuildContext context) {
  final s = context.read<AppState>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in s.activePets)
            ListTile(
              leading: PetAvatar(pet: p, size: 40),
              title: Text(p.name),
              subtitle: Text(p.species == Species.cat ? 'Cat' : 'Dog'),
              trailing: p.id == s.selectedPet?.id
                  ? const Icon(Icons.check_rounded)
                  : null,
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
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PetEditScreen()));
            },
          ),
          const SizedBox(height: Tokens.space2),
        ],
      ),
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
        child: Icon(
          Icons.cloud_upload_outlined,
          semanticLabel: 'Waiting to sync',
        ),
      ),
    );
  }
}

/// One coloured chip per pet; tap to switch (each pet keeps its colour everywhere).
class PetStrip extends StatelessWidget {
  const PetStrip({
    super.key,
    required this.pets,
    required this.selected,
    this.onSelect,
  });
  final List<Pet> pets;
  final String selected;

  /// Called after a pet is picked; also hides the add button when set.
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final s = context.read<AppState>();
    // Grows with large text (no fixed height); scrolls sideways when there are many pets.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final p in pets) ...[
            Semantics(
              selected: p.id == selected,
              button: true,
              label: p.name,
              excludeSemantics: true,
              child: Material(
                color: p.id == selected
                    ? c.petAccent(p)
                    : t.colorScheme.surface,
                shape: StadiumBorder(
                  side: BorderSide(color: c.petAccent(p), width: 1.5),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () {
                    Feel.tap();
                    s.selectPet(p.id);
                    onSelect?.call();
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: Tokens.minTarget,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Tokens.space1 + 2,
                        Tokens.space1,
                        Tokens.space4,
                        Tokens.space1,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PetAvatar(pet: p, size: 30, onHero: p.id == selected),
                          const SizedBox(width: Tokens.space2),
                          Text(
                            p.name,
                            style: t.textTheme.titleSmall!.copyWith(
                              color: p.id == selected
                                  ? MyPetColors.onAccent(c.petAccent(p))
                                  : t.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Tokens.space2),
          ],
          if (onSelect == null)
            IconButton(
              tooltip: 'Add a pet',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PetEditScreen())),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
    );
  }
}
