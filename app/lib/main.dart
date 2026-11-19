import 'package:material_ui/material_ui.dart';

import 'data/bootstrap.dart';
import 'notify/reminder_notifications.dart';
import 'state/app_state.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await startBackend();
  final state = AppState(backend);
  runApp(MyPetApp(state: state));
  // Pet data arrives a moment after start; the first log opens once it is there.
  final notifications = ReminderNotifications(state, onLogNow: (petId) async {
    for (var i = 0; i < 20 && state.activePets.every((p) => p.id != petId); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    openQuickLog(state, petId);
  });
  await notifications.start();
}
