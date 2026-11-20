import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/pet.dart';
import '../../state/app_state.dart';
import '../feedback.dart';
import 'pet_bar.dart';

/// What the photo sheet returned: a new photo file, back to the drawing, or nothing.
sealed class PhotoChoice {}

class NewPhoto extends PhotoChoice {
  NewPhoto(this.file);
  final String file;
}

class UseDrawing extends PhotoChoice {}

/// Take or choose a photo of the pet. It is resized and kept only in the app's folder on
/// this phone. Null when cancelled; [UseDrawing] when the person goes back to the drawing.
Future<PhotoChoice?> pickPetPhoto(BuildContext context, {required bool hasPhoto}) async {
  final dir = context.read<AppState>().photoDir;
  final messenger = ScaffoldMessenger.of(context);
  final src = await showModalBottomSheet<Object?>(
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
        if (hasPhoto)
          ListTile(
            leading: const Icon(Icons.hide_image_rounded),
            title: const Text('Use the drawing'),
            onTap: () => Navigator.pop(c, 'drawing'),
          ),
      ]),
    ),
  );
  if (src == 'drawing') return UseDrawing();
  if (src is! ImageSource || dir == null) return null;
  try {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (x == null) return null;
    final file = 'pet_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await Directory(dir).create(recursive: true);
    await File(x.path).copy('$dir/$file');
    return NewPhoto(file);
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not open photos. Allow access in Settings.')));
    return null;
  }
}

/// The pet's big picture with a camera badge: tap to add or change the photo.
class PetPhotoButton extends StatelessWidget {
  const PetPhotoButton({super.key, required this.pet, required this.onTap, this.size = 112});
  final Pet pet;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      button: true,
      label: pet.photo == null ? 'Add a photo of ${pet.name.isEmpty ? 'your pet' : pet.name}' : 'Change photo',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          Feel.tap();
          onTap();
        },
        child: Stack(clipBehavior: Clip.none, children: [
          PetAvatar(pet: pet, size: size),
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
    );
  }
}

/// Opens the photo sheet for a saved pet and saves the choice straight away.
Future<void> changePetPhoto(BuildContext context, Pet pet) async {
  final s = context.read<AppState>();
  final r = await pickPetPhoto(context, hasPhoto: pet.photo != null);
  switch (r) {
    case NewPhoto(:final file):
      await s.updatePet(pet.copyWith(photo: file));
    case UseDrawing():
      await s.updatePet(pet.copyWith(clearPhoto: true));
    case null:
      break;
  }
}
