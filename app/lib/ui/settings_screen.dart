import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/demo_data.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'wording.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
        const SectionTitle('What MyPet does'),
        const Card(child: AboutMyPet()),
        const SectionTitle('Account'),
        Card(
          child: Column(children: [
            ListTile(
              title: const Text('Data is kept'),
              subtitle: Text(s.backend.name),
            ),
            if (s.carer?.email != null)
              ListTile(title: const Text('Signed in as'), subtitle: Text(s.carer!.email!)),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                s.backend.signOut();
              },
            ),
          ]),
        ),
        const SectionTitle('Demo'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Add demo pets'),
            subtitle: const Text('Mochi and Biscuit with 30 days of made-up logs'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await addDemoPets(s);
              messenger.showSnackBar(const SnackBar(content: Text('Demo pets added')));
            },
          ),
        ),
        const SizedBox(height: Tokens.space4),
        Text('MyPet, FIT3162 team PCS-04, Monash University Malaysia',
            style: t.textTheme.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}

/// What MyPet does and does not do (vault, Pet Health Research section 6, point 3).
class AboutMyPet extends StatelessWidget {
  const AboutMyPet({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget row(IconData i, String text) => Padding(
          padding: const EdgeInsets.only(bottom: Tokens.space3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 20, color: t.colorScheme.primary),
            const SizedBox(width: Tokens.space3),
            Expanded(child: Text(text, style: t.textTheme.bodyMedium)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.all(Tokens.space4),
      child: Column(children: [
        row(Icons.touch_app_outlined, 'A daily log in about 3 taps: ate, energy, toileting.'),
        row(Icons.insights, 'After a week, MyPet learns what is normal for your pet and '
            'tells you when something changes, with the evidence.'),
        row(Icons.graphic_eq, 'A 10 second sound check gives a likely emotion. The sound '
            'is analysed on your phone and deleted straight away.'),
        row(Icons.money_off_outlined, 'Free. No collar, no hardware, no AI account.'),
        row(Icons.local_hospital_outlined, Wording.notDiagnosis),
      ]),
    );
  }
}
