import 'dart:io';

import 'package:material_ui/material_ui.dart' show ImageProvider, FileImage;
import 'package:video_player/video_player.dart';

/// The picture in [f].
ImageProvider fileImage(File f) => FileImage(f);

/// A player for the clip at [path], or null if the file is gone.
VideoPlayerController? clipPlayer(String path) =>
    File(path).existsSync() ? VideoPlayerController.file(File(path)) : null;
