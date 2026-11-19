import 'package:material_ui/material_ui.dart';

import 'data/bootstrap.dart';
import 'state/app_state.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await startBackend();
  runApp(MyPetApp(state: AppState(backend)));
}
