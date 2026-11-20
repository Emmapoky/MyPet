
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/life_stage.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import '../util/day.dart';
import 'theme.dart';
import 'feedback.dart';
import 'widgets/common.dart';
import 'widgets/pet_photo.dart';

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
  late int colour = widget.pet == null ? context.read<AppState>().nextColour() : petColourIndex(widget.pet!);
  late String? photo = widget.pet?.photo;
  late bool birthEstimated = widget.pet?.birthEstimated ?? false;
  late bool? neutered = widget.pet?.neutered;
  late SizeClass? adultSize = widget.pet?.adultSize;
  late final portion = TextEditingController(text: widget.pet?.portion ?? '');
  late int? meals = widget.pet?.mealsPerDay;
  late final Set<String> checks = {...?widget.pet?.checks};
  String? error;

  /// What the avatar at the top shows while editing.
  Pet get _draft => Pet(
        id: widget.pet?.id ?? 'new',
        name: name.text,
        species: species ?? Species.dog,
        carerIds: const [],
        createdAt: widget.pet?.createdAt ?? DateTime(2000),
        colour: colour,
        photo: photo,
      );

  /// Take or choose a photo; it is resized and kept only in the app's folder on this phone.
  Future<void> _photo() async {
    final r = await pickPetPhoto(context, hasPhoto: photo != null);
    if (!mounted) return;
    switch (r) {
      case NewPhoto(:final file):
        setState(() => photo = file);
      case UseDrawing():
        setState(() => photo = null);
      case null:
        break;
    }
  }

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
    Pet extras(Pet p) => p.copyWith(
          birthEstimated: birth != null && birthEstimated,
          neutered: neutered,
          clearNeutered: neutered == null,
          adultSize: adultSize,
          clearAdultSize: adultSize == null || species == Species.cat,
          portion: portion.text.trim(),
          mealsPerDay: meals,
          clearMeals: meals == null,
          checks: [for (final c in PetChecks.all) if (checks.contains(c)) c],
        );
    if (widget.pet == null) {
      final p = await s.addPet(
          name: n,
          species: species!,
          breed: breed.text.trim(),
          birthDate: birth,
          weightKg: w,
          colour: colour,
          photo: photo);
      final full = extras(p);
      if (full.toMap().toString() != p.toMap().toString()) await s.updatePet(full);
    } else {
      await s.updatePet(extras(widget.pet!).copyWith(
        name: n,
        species: species,
        breed: breed.text.trim(),
        birthDate: birth,
        clearBirthDate: birth == null,
        weightKg: w,
        clearWeight: w == null,
        colour: colour,
        photo: photo,
        clearPhoto: photo == null,
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
    if (d != null) {
      setState(() {
        birth = Day.of(d);
        birthEstimated = false;
      });
    }
  }

  /// Adopted pets: "about 3 years" sets a birth date marked as a guess.
  Future<void> _aboutAge() async {
    final years = TextEditingController();
    final r = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About how old?'),
        content: TextField(
          controller: years,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Years', hintText: 'For example 3, or 0.5 for 6 months'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(years.text.trim().replaceAll(',', '.'))),
            child: const Text('Use this'),
          ),
        ],
      ),
    );
    if (r == null || r < 0 || r > 30) return;
    setState(() {
      birth = Day.today().addDays(-(r * 365.25).round());
      birthEstimated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.pet == null ? 'Add a pet' : 'Edit ${widget.pet!.name}')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
          // Photo (or drawing) and the pet's colour.
          Center(
            child: PetPhotoButton(pet: _draft, onTap: _photo),
          ),
          const SizedBox(height: Tokens.space4),
          Wrap(alignment: WrapAlignment.center, spacing: Tokens.space1, children: [
            for (var i = 0; i < petColourCount; i++)
              Semantics(
                button: true,
                selected: colour == i,
                label: '${petColourNames[i]} colour',
                excludeSemantics: true,
                child: InkResponse(
                  onTap: () {
                    Feel.tap();
                    setState(() => colour = i);
                  },
                  radius: 24,
                  child: SizedBox.square(
                    dimension: Tokens.minTarget,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: colour == i ? 34 : 28,
                        height: colour == i ? 34 : 28,
                        decoration: BoxDecoration(
                          color: MyPetColors.of(context).petAccents[i],
                          shape: BoxShape.circle,
                          border: colour == i ? Border.all(color: t.colorScheme.onSurface, width: 2.5) : null,
                        ),
                        child: colour == i ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: Tokens.space4),
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
                : birthEstimated
                    ? 'About ${_ageWords(birth!)} (a guess)'
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _aboutAge, child: const Text('Not sure? Say about how old')),
          ),
          const SizedBox(height: Tokens.space2),
          TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight in kg (optional)'),
          ),
          const SizedBox(height: Tokens.space5),
          Semantics(header: true, child: Text('To get to know ${name.text.isEmpty ? 'your pet' : name.text} (optional)', style: t.textTheme.titleMedium)),
          const SizedBox(height: Tokens.space1),
          Text('Used for the starter guide and for how MyPet reads changes as your pet grows.',
              style: t.textTheme.bodySmall),
          const SizedBox(height: Tokens.space4),
          ChoiceRow<bool>(
            label: 'Neutered or spayed',
            options: const [(true, 'Yes'), (false, 'No')],
            selected: neutered,
            onSelected: (v) => setState(() => neutered = neutered == v ? null : v),
          ),
          if (species == Species.dog) ...[
            const SizedBox(height: Tokens.space4),
            ChoiceRow<SizeClass>(
              label: 'Size when grown (if the breed does not say)',
              options: [for (final c in SizeClass.values) (c, sizeClassName(c))],
              selected: adultSize,
              onSelected: (v) => setState(() => adultSize = adultSize == v ? null : v),
            ),
          ],
          const SizedBox(height: Tokens.space4),
          TextField(
            controller: portion,
            decoration: const InputDecoration(
                labelText: 'Usual portion', hintText: 'In your own units, like 60 g, 1 cup or half a can'),
          ),
          const SizedBox(height: Tokens.space4),
          ChoiceRow<int>(
            label: 'Meals a day',
            options: const [(1, '1'), (2, '2'), (3, '3'), (4, '4')],
            selected: meals,
            onSelected: (v) => setState(() => meals = meals == v ? null : v),
          ),
          const SizedBox(height: Tokens.space5),
          Semantics(header: true, child: Text('Extra daily questions (optional)', style: t.textTheme.titleMedium)),
          const SizedBox(height: Tokens.space1),
          Text('One more tap each on the daily log. Only switch on what helps this pet.', style: t.textTheme.bodySmall),
          for (final c in PetChecks.all)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(PetChecks.question(c)),
              subtitle: Text(PetChecks.why(c)),
              value: checks.contains(c),
              onChanged: (on) => setState(() => on ? checks.add(c) : checks.remove(c)),
            ),
          if (error != null) ...[
            const SizedBox(height: Tokens.space3),
            Semantics(liveRegion: true, child: Text(error!, style: TextStyle(color: t.colorScheme.error))),
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

String _ageWords(Day birth) {
  final m = Day.today().difference(birth) ~/ 30;
  return m < 24 ? '$m months' : '${m ~/ 12} years';
}
