import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../behaviour/engine.dart';
import '../data/local_backend.dart';
import '../models/care_entry.dart';
import '../state/app_state.dart';
import '../state/demo_data.dart';
import 'feedback.dart';
import 'home_shell.dart';
import 'theme.dart';
import 'widgets/pet_bar.dart';

/// First-run tour, told by Pip the guide dog. One bubble per tab.
List<GuideStep> tourSteps() => const [
      GuideStep(0, "Hi, I'm Pip! I'll show you around. Today is where you log your pet's day in three taps."),
      GuideStep(1, 'Pets holds each pet, with a photo and their records. Open a pet to share a PDF with your vet.'),
      GuideStep(2, 'Check films 5 to 10 seconds. Sound and picture are read on this phone, then the clip is deleted.'),
      GuideStep(3, "After 7 days of logs, Insights learns what's usual for your pet and points out changes."),
      GuideStep(4, "Reminders for food, medicine and walks. Anything missed shows on Today. That's it, have fun!"),
    ];

/// The story demo: Biscuit, a demo dog, tells what MyPet noticed when his energy dropped.
/// Runs on its own demo data, so the person's pets are never touched.
List<GuideStep> storySteps(AppState s) {
  final biscuit = s.activePets.where((p) => p.name == 'Biscuit').firstOrNull;
  final days = biscuit == null
      ? 0
      : {for (final e in s.timelineOf(biscuit.id).ofKind(EntryKind.dailyLog)) e.day}.length;
  return [
    const GuideStep(0, "Woof! I'm Biscuit. Every evening my carer logs 3 things: did I eat, my energy, my toilet. Three taps.",
        petName: 'Biscuit'),
    GuideStep(0,
        "They've logged $days days for me. MyPet needs at least 7 to learn what's usual for me. Before that it stays quiet.",
        petName: 'Biscuit'),
    const GuideStep(0,
        'Lately I had low energy on 2 of the last 3 days. MyPet shows it in amber: a change from my usual, not a diagnosis.',
        petName: 'Biscuit'),
    const GuideStep(3,
        'Insights compares me only with my own usual range, the shaded band. The low bars are my flat days.',
        petName: 'Biscuit'),
    const GuideStep(2,
        'My carer can film me for 10 seconds. My sounds and my picture are read separately, then combined.',
        petName: 'Biscuit'),
    const GuideStep(1,
        'Before the vet, they open my page and tap the PDF icon to share my record. Vet letters can be added too.',
        petName: 'Biscuit'),
    const GuideStep(4, "And I never miss dinner. That's my story! Now try it with your own pet.", petName: 'Biscuit'),
  ];
}

/// Opens the story demo on fresh demo data, over the app. Ends back where it started.
Future<void> startStory(BuildContext context) async {
  final engine = context.read<BehaviourEngine>();
  final nav = Navigator.of(context);
  final parent = context.read<AppState>();
  final demo = AppState(LocalBackend(), clock: parent.clock, detectInBackground: parent.detectInBackground);
  await demo.backend.signIn('', '');
  for (var i = 0; i < 50 && !demo.carerKnown; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  await addDemoPets(demo);
  for (var i = 0; i < 50 && demo.activePets.length < 2; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  demo.look = parent.look;
  demo.startGuide(Guide(steps: storySteps(demo), narrator: 'Biscuit', onDone: () => nav.pop()));
  await nav.push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (c) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: demo),
        Provider.value(value: engine),
      ],
      child: const HomeShell(),
    ),
  ));
  demo.dispose();
}

/// The speech bubble over the app, pointing at the tab it talks about.
class GuideOverlay extends StatelessWidget {
  const GuideOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final g = s.guide;
    if (g == null) return const SizedBox.shrink();
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final st = g.steps[g.at];
    final last = g.at == g.steps.length - 1;
    final narrator = g.narrator == null ? null : s.activePets.where((p) => p.name == g.narrator).firstOrNull;
    final width = MediaQuery.sizeOf(context).width;
    final bottom = MediaQuery.paddingOf(context).bottom + 96;
    final arrowX = ((st.tab + 0.5) / 5 * (width - 2 * Tokens.space3) + Tokens.space3).clamp(40.0, width - 40);
    return Stack(children: [
      // Light dim; taps outside the bubble do nothing during the walkthrough.
      Positioned.fill(child: ModalBarrier(color: Colors.black.withValues(alpha: 0.28), dismissible: false)),
      Positioned(
        left: arrowX - 10,
        bottom: bottom - 12,
        child: CustomPaint(size: const Size(20, 12), painter: _Arrow(t.colorScheme.surface)),
      ),
      Positioned(
        left: Tokens.space3,
        right: Tokens.space3,
        bottom: bottom,
        child: Semantics(
          liveRegion: true,
          container: true,
          child: Material(
            color: t.colorScheme.surface,
            elevation: 8,
            shadowColor: Colors.black38,
            borderRadius: BorderRadius.circular(Tokens.radiusHero),
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space4),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  narrator != null
                      ? PetAvatar(pet: narrator, size: 56)
                      : ClipOval(
                          child: Container(
                            width: 56,
                            height: 56,
                            color: c.brandContainer,
                            child: SvgPicture.asset('assets/illustrations/guide-dog.svg', fit: BoxFit.cover),
                          ),
                        ),
                  const SizedBox(width: Tokens.space3),
                  Expanded(child: Text(st.text, style: t.textTheme.bodyLarge)),
                ]),
                const SizedBox(height: Tokens.space3),
                Row(children: [
                  // Step dots
                  for (var i = 0; i < g.steps.length; i++)
                    Container(
                      width: i == g.at ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i == g.at ? c.brand : c.cardBorder,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  const Spacer(),
                  if (!last) TextButton(onPressed: s.endGuide, child: const Text('Skip')),
                  if (g.at > 0)
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () {
                        Feel.tap();
                        s.guideStep(-1);
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(96, Tokens.minTarget)),
                    onPressed: () {
                      Feel.tap();
                      s.guideStep(1);
                    },
                    child: Text(last ? 'Done' : 'Next'),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Arrow extends CustomPainter {
  _Arrow(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = colour);

  @override
  bool shouldRepaint(_Arrow old) => old.colour != colour;
}
