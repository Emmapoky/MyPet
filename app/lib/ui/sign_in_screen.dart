import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/local_backend.dart';
import '../state/app_state.dart';
import 'settings_screen.dart';
import 'theme.dart';

/// Email sign in (Firebase Auth, free on Spark). With the on-phone backend there is no
/// account, so this only shows what MyPet does and a Start button.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool creating = false;
  bool busy = false;
  String? error;

  Future<void> _go() async {
    final b = context.read<AppState>().backend;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (creating) {
        await b.signUp(email.text.trim(), password.text);
      } else {
        await b.signIn(email.text.trim(), password.text);
      }
    } catch (e) {
      setState(() => error = creating
          ? 'Could not create the account. Use a real email and a password of 6 or more characters.'
          : 'Email or password not recognised.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final local = context.read<AppState>().backend is LocalBackend;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Tokens.space5), children: [
          const SizedBox(height: Tokens.space5),
          Icon(Icons.pets, size: 56, color: t.colorScheme.primary),
          const SizedBox(height: Tokens.space3),
          Text('MyPet', style: t.textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: Tokens.space2),
          Text('Know your pet\'s normal. Notice changes early.',
              style: t.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: Tokens.space5),
          const Card(child: AboutMyPet()),
          const SizedBox(height: Tokens.space5),
          if (!local) ...[
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: Tokens.space3),
            TextField(
              controller: password,
              obscureText: true,
              autofillHints: [creating ? AutofillHints.newPassword : AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (error != null) ...[
              const SizedBox(height: Tokens.space3),
              Text(error!, style: TextStyle(color: t.colorScheme.error)),
            ],
            const SizedBox(height: Tokens.space4),
          ],
          FilledButton(
            onPressed: busy ? null : _go,
            child: Text(local ? 'Start' : (creating ? 'Create account' : 'Sign in')),
          ),
          if (!local)
            TextButton(
              onPressed: () => setState(() => creating = !creating),
              child: Text(creating ? 'I already have an account' : 'Create an account'),
            ),
        ]),
      ),
    );
  }
}
