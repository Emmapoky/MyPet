import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../behaviour/engine.dart';
import '../state/app_state.dart';
import 'home_shell.dart';
import 'quick_log_screen.dart';
import 'short_log_screen.dart';
import 'sign_in_screen.dart';
import 'theme.dart';

/// Lets a notification open a screen from outside the widget tree.
final navigatorKey = GlobalKey<NavigatorState>();

class MyPetApp extends StatelessWidget {
  MyPetApp({super.key, required this.state, BehaviourEngine? engine})
      : engine = engine ?? PhoneBehaviourEngine();
  final AppState state;

  /// The on-phone behaviour check. Loaded the first time the Check tab opens.
  final BehaviourEngine engine;

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          Provider.value(value: engine),
        ],
        child: Selector<AppState, ThemeMode>(
          selector: (_, s) => s.look,
          builder: (_, look, _) => MaterialApp(
          title: 'MyPet',
          themeMode: look,
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: const _Gate(),
          // mypet://app/log?pet=ID (Flutter hands the Navigator "/log?pet=ID"), from the home and lock-screen widgets: the short form.
          onGenerateRoute: shortLogRoute,
          ),
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

/// The route for a deep link to the short form (mypet://app/log?pet=ID), or
/// null for any other link, which then just opens the app.
Route<void>? shortLogRoute(RouteSettings r) {
  final uri = Uri.tryParse(r.name ?? '');
  if (uri == null || (uri.path != '/log' && uri.host != 'log')) return null;
  return MaterialPageRoute<void>(settings: r, builder: (_) => ShortLogScreen(petId: uri.queryParameters['pet']));
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
