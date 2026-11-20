import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/demo_data.dart';
import 'theme.dart';
import 'widgets/guide_target.dart';
import 'widgets/common.dart';
import 'widgets/clip_keep.dart';
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
        const SectionTitle('Look'),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
            ButtonSegment(value: ThemeMode.system, label: Text('Phone'), icon: Icon(Icons.phone_iphone_rounded)),
          ],
          selected: {s.look},
          onSelectionChanged: (v) => s.setLook(v.first),
        ),
        const SectionTitle('Saved clips'),
        const GuideTarget(id: 'savedClips', child: Card(child: ClipKeepChoices())),
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.space2, Tokens.space2, Tokens.space2, 0),
          child: Text('Clips stay on this phone and are never uploaded.', style: t.textTheme.bodySmall),
        ),
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
            subtitle: const Text('Example pets with a month of made-up logs and checks'),
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
        row(Icons.videocam_outlined, 'A 10 second clip gives a likely feeling. Sound and picture '
            'are read on your phone. You choose whether Save keeps the video, only the sound, or nothing.'),
        row(Icons.money_off_outlined, 'Free. No collar, no hardware, no AI account.'),
        row(Icons.local_hospital_outlined, Wording.notDiagnosis),
      ]),
    );
  }
}
