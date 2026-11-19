import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/pet.dart';
import '../state/app_state.dart';
import 'pet_detail_screen.dart';
import 'pet_edit_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/pet_bar.dart';
import 'home_shell.dart';

/// All pets on the account (FR01: several pets per account, report Table 3.1).
class PetsScreen extends StatelessWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final active = s.activePets;
    final past = s.pets.where((p) => !p.isActive).toList();

    Widget tile(Pet p) => ListTile(
          leading: PetAvatar(pet: p, size: 44),
          title: Text(p.name, style: Theme.of(context).textTheme.titleSmall),
          subtitle: Text([
            p.species == Species.cat ? 'Cat' : 'Dog',
            if (p.breed.isNotEmpty) p.breed,
            if (!p.isActive) statusWord(p.status),
          ].join(' · ')),
          trailing: p.isActive && s.loggedToday(p.id)
              ? Icon(Icons.check_circle_rounded,
                  color: MyPetColors.of(context).loggedEdge, semanticLabel: 'Logged today')
              : const Icon(Icons.chevron_right),
          onTap: () {
            // Opening a pet also makes it the pet shown on Today, Check and Insights.
            if (p.isActive) context.read<AppState>().selectPet(p.id);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => PetDetailScreen(petId: p.id)));
          },
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Pets'), actions: const [MoreMenu()]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        icon: const Icon(Icons.add),
        label: const Text('Add a pet'),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const PetEditScreen())),
      ),
      body: PageWash(
        child: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
        if (active.isEmpty)
          const EmptyState(
            icon: Icons.pets,
            title: 'No pets yet',
            body: 'Add a cat or dog to start logging.',
          )
        else
          for (final p in active) ...[
            MyCard(
              accent: MyPetColors.of(context).petAccent(p),
              padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
              child: tile(p),
            ),
            const SizedBox(height: Tokens.space3),
          ],
        if (past.isNotEmpty) ...[
          const SectionTitle('Past pets'),
          Card(child: Column(children: [for (final p in past) tile(p)])),
        ],
        const SizedBox(height: 80),
        ]),
      ),
    );
  }
}
