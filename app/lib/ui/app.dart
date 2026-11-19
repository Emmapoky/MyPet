import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'home_shell.dart';
import 'quick_log_screen.dart';
import 'sign_in_screen.dart';
import 'theme.dart';

/// Lets a notification open a screen from outside the widget tree.
final navigatorKey = GlobalKey<NavigatorState>();

class MyPetApp extends StatelessWidget {
  const MyPetApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          title: 'MyPet',
          navigatorKey: navigatorKey,
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

/// Opens the quick log for a pet, from a notification's Log now.
void openQuickLog(AppState s, String petId) {
  final pet = s.activePets.where((p) => p.id == petId).firstOrNull;
  final nav = navigatorKey.currentState;
  if (pet == null || nav == null) return;
  s.selectPet(pet.id);
  s.goToTab(0);
  nav.popUntil((r) => r.isFirst);
  nav.push(MaterialPageRoute(builder: (_) => QuickLogScreen(pet: pet)));
}
