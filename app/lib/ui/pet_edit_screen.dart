import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/pet.dart';
import '../state/app_state.dart';
import '../util/day.dart';
import 'theme.dart';
import 'feedback.dart';
import 'widgets/common.dart';
import 'widgets/pet_bar.dart';

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
    final s = context.read<AppState>();
    final dir = s.photoDir;
    final src = await showModalBottomSheet<ImageSource?>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Choose a photo'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
          if (photo != null)
            ListTile(
              leading: const Icon(Icons.hide_image_rounded),
              title: const Text('Use the drawing'),
              onTap: () {
                Navigator.pop(c);
                setState(() => photo = null);
              },
            ),
        ]),
      ),
    );
    if (src == null || dir == null) return;
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 600, maxHeight: 600, imageQuality: 85);
      if (x == null) return;
      final file = 'pet_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Directory(dir).create(recursive: true);
      await File(x.path).copy('$dir/$file');
      if (mounted) setState(() => photo = file);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not open photos. Allow access in Settings.');
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
    if (widget.pet == null) {
      await s.addPet(
          name: n,
          species: species!,
          breed: breed.text.trim(),
          birthDate: birth,
          weightKg: w,
          colour: colour,
          photo: photo);
    } else {
      await s.updatePet(widget.pet!.copyWith(
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
    if (d != null) setState(() => birth = Day.of(d));
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
            child: Semantics(
              button: true,
              label: photo == null ? 'Add a photo' : 'Change photo',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: _photo,
                child: Stack(clipBehavior: Clip.none, children: [
                  PetAvatar(pet: _draft, size: 112),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: t.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.colorScheme.surface, width: 3),
                      ),
                      child: Icon(Icons.photo_camera_rounded, size: 20, color: t.colorScheme.onPrimary),
                    ),
                  ),
                ]),
              ),
            ),
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
