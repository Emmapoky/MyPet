import 'package:material_ui/material_ui.dart';

import 'data/backend.dart';
import 'data/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await startBackend();
  runApp(MyPetApp(backend: backend));
}

class MyPetApp extends StatelessWidget {
  const MyPetApp({super.key, required this.backend});
  final Backend backend;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MyPet',
        home: Scaffold(body: Center(child: Text('MyPet (${backend.name})'))),
      );
}
