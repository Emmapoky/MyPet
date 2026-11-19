import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'home_shell.dart';
import 'sign_in_screen.dart';
import 'theme.dart';

class MyPetApp extends StatelessWidget {
  const MyPetApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          title: 'MyPet',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: const _Gate(),
        ),
      );
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.carerKnown) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return s.carer == null ? const SignInScreen() : const HomeShell();
  }
}
