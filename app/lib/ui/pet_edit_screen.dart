import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/pet.dart';
import '../state/app_state.dart';
import '../util/day.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Create or edit a pet profile (FR01): species, breed, birth date, weight.
class PetEditScreen extends StatefulWidget {
  const PetEditScreen({super.key, this.pet});
  final Pet? pet;

  @override
  State<PetEditScreen> createState() => _PetEditScreenState();
}

class _PetEditScreenState extends State<PetEditScreen> {
  late final name = TextEditingController(text: widget.pet?.name ?? '');
  late final breed = TextEditingController(text: widget.pet?.breed ?? '');
  late final weight =
      TextEditingController(text: widget.pet?.weightKg?.toString() ?? '');
  late Species? species = widget.pet?.species;
  late Day? birth = widget.pet?.birthDate;
  String? error;

  Future<void> _save() async {
    final n = name.text.trim();
    final w = weight.text.trim().isEmpty
        ? null
        : double.tryParse(weight.text.trim().replaceAll(',', '.'));
    if (n.isEmpty || species == null) {
      setState(() => error = 'Add a name and choose cat or dog.');
      return;
    }
    if (weight.text.trim().isNotEmpty && (w == null || w <= 0 || w > 120)) {
      setState(() => error = 'Weight must be a number between 0.1 and 120 kg.');
      return;
    }
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    if (widget.pet == null) {
      await s.addPet(
          name: n, species: species!, breed: breed.text.trim(), birthDate: birth, weightKg: w);
    } else {
      await s.updatePet(widget.pet!.copyWith(
        name: n,
        species: species,
        breed: breed.text.trim(),
        birthDate: birth,
        clearBirthDate: birth == null,
        weightKg: w,
        clearWeight: w == null,
      ));
    }
    nav.pop();
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      initialDate: birth?.asDateTime ?? DateTime(now.year - 2, now.month, now.day),
      helpText: 'Birth date (a guess is fine)',
    );
    if (d != null) setState(() => birth = Day.of(d));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.pet == null ? 'Add a pet' : 'Edit ${widget.pet!.name}')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: Tokens.space4),
          ChoiceRow<Species>(
            label: 'Cat or dog',
            options: const [(Species.cat, 'Cat'), (Species.dog, 'Dog')],
            selected: species,
            onSelected: (v) => setState(() => species = v),
          ),
          const SizedBox(height: Tokens.space4),
          TextField(
            controller: breed,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Breed (optional)'),
          ),
          const SizedBox(height: Tokens.space4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Birth date (optional)'),
            subtitle: Text(birth == null
                ? 'Not set'
                : DateFormat('d MMMM y').format(birth!.asDateTime)),
            trailing: birth == null
                ? const Icon(Icons.calendar_today_outlined)
                : IconButton(
                    tooltip: 'Clear birth date',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => birth = null),
                  ),
            onTap: _pickBirth,
          ),
          const SizedBox(height: Tokens.space2),
          TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight in kg (optional)'),
          ),
          if (error != null) ...[
            const SizedBox(height: Tokens.space3),
            Text(error!, style: TextStyle(color: t.colorScheme.error)),
          ],
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: FilledButton(onPressed: _save, child: const Text('Save')),
        ),
      ),
    );
  }
}
