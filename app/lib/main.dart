import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'behaviour/analysis.dart' show ClipKeep;
import 'data/bootstrap.dart';
import 'notify/reminder_notifications.dart';
import 'state/app_state.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await startBackend();
  final state = AppState(backend);
  // Look (light by default): one word in a small file on the phone.
  try {
    final f = File('${(await getApplicationSupportDirectory()).path}/look.txt');
    if (await f.exists()) {
      final saved = (await f.readAsString()).trim();
      state.look = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.light);
    }
    state.onLookChanged = (m) => f.writeAsString(m.name);
    // First-run tour: shown once, remembered with a small file.
    final tour = File('${(await getApplicationSupportDirectory()).path}/tour.txt');
    state.tourSeen = await tour.exists();
    state.onTourSeen = () => tour.writeAsString('seen');
    // Pet photos and the clips of saved checks stay on this phone only.
    final docs = (await getApplicationDocumentsDirectory()).path;
    state.photoDir = '$docs/pet_photos';
    state.clipDir = '$docs/check_clips';
    // Saved clips: video, sound or none, remembered like the look.
    final keep = File('${(await getApplicationSupportDirectory()).path}/clips.txt');
    if (await keep.exists()) {
      final saved = (await keep.readAsString()).trim();
      state.clipKeep = ClipKeep.values.firstWhere((k) => k.name == saved, orElse: () => ClipKeep.video);
    }
    state.onClipKeepChanged = (k) => keep.writeAsString(k.name);
    // Quick-log doors switched on or off in Settings.
    final doors = File('${(await getApplicationSupportDirectory()).path}/doors.json');
    if (await doors.exists()) {
      try {
        state.doors = QuickDoors.fromMap(jsonDecode(await doors.readAsString()) as Map<String, dynamic>);
      } catch (_) {}
    }
    state.onDoorsChanged = (d) => doors.writeAsString(jsonEncode(d.toMap()));
    // Answers given on the daily notification while the app was closed wait here.
    state.notificationInbox = '${(await getApplicationSupportDirectory()).path}/notification_inbox.jsonl';
  } catch (_) {}
  runApp(MyPetApp(state: state));
  // Pet data arrives a moment after start; the first log opens once it is there.
  final notifications = ReminderNotifications(state, onLogNow: (petId) async {
    for (var i = 0; i < 20 && state.activePets.every((p) => p.id != petId); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    openQuickLog(state, petId);
  });
  await notifications.start();
  // Back in the app: add any notification answers given while it was in the background.
  AppLifecycleListener(onResume: () => notifications.drain());
}
