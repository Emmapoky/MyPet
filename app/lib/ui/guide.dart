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
import 'widgets/common.dart';
import 'widgets/pet_bar.dart';
import 'widgets/pet_portrait.dart';

/// First-run tour, told by Pip the guide dog. One bubble per tab.
List<GuideStep> tourSteps() => const [
      GuideStep(0, "Hi, I'm Pip! I'll show you around. Today is where you log your pet's day in three taps."),
      GuideStep(1, 'Pets holds each pet, with a photo and their records. Open a pet to share a PDF with your vet.'),
      GuideStep(2, 'Check films 5 to 10 seconds. Sound and picture are read on this phone, then the clip is deleted.'),
      GuideStep(3, "After 7 days of logs, Insights learns what's usual for your pet and points out changes."),
      GuideStep(4, "Reminders for food, medicine and walks. Anything missed shows on Today. That's it, have fun!"),
    ];

/// Story bubbles for one demo pet, told by the pet itself.
List<GuideStep> storySteps(AppState s, DemoPet d) {
  final pet = s.activePets.where((p) => p.name == d.name).firstOrNull;
  final days = pet == null
      ? 0
      : {for (final e in s.timelineOf(pet.id).ofKind(EntryKind.dailyLog)) e.day}.length;
  GuideStep step(int tab, String text) => GuideStep(tab, text, petName: d.name);
  return switch (d.id) {
    'demo-biscuit' => [
        step(0, "Woof! I'm Biscuit. Every evening my carer logs 3 things: did I eat, my energy, my toilet. Three taps."),
        step(0, "They've logged $days days for me. MyPet needs at least 7 to learn what's usual for me. Before that it stays quiet."),
        step(0, 'This week I had low energy on 2 of the last 3 days. MyPet shows it in amber: a change from my usual, not a diagnosis.'),
        step(3, 'Insights compares me only with my own usual range, the shaded band. The low bars are my flat days.'),
        step(1, 'My carer filmed me yesterday. On my page, tap the check to replay it and hear each howl MyPet found.'),
        step(1, 'Before the vet, they tap the PDF icon on my page to share my record. Vet letters can be added too.'),
        step(4, "And I never miss dinner. That's my story! Try another pet, or start with your own."),
      ],
    'demo-mochi' => [
        step(0, "Meow, I'm Mochi. I usually clear my bowl. This week I left my dinner on 2 of the last 3 days."),
        step(3, "For me that's rare, so MyPet points it out, with the days it saw. It's a change, not a diagnosis. A vet can tell why."),
        step(2, 'My carer filmed me hissing at the vacuum. Sound and picture are read on the phone, never uploaded.'),
        step(1, 'My page keeps every check. Tap one to replay my hiss, or my purr from last week.'),
        step(1, 'Settings decides what Save keeps: the video, only the sound, or just the results.'),
        step(4, "Reminders keep my meals on time. That's my story!"),
      ],
    'demo-pepper' => [
        step(0, "Hi, I'm Pepper, a puppy! $days days of logs, and everything looks normal for me, so Today stays calm."),
        step(3, 'Insights shows my usual range. My days sit inside the band, so there is nothing to flag.'),
        step(2, "Checks aren't only for worries. My carer films me barking at the gate, and MyPet finds each bark and when I'm in view."),
        step(1, 'My page keeps those clips, so we can replay my good days too.'),
        step(4, "Walks and meals are on Reminders. That's my story!"),
      ],
    _ => [
        step(0, "Mew, I'm Bean. I came home $days days ago, so I only have $days days of logs."),
        step(3, "MyPet needs 7 days to learn what's usual for me. Until then Insights waits, and says how many days are left."),
        step(2, 'Checks work from day one. My carer filmed me meowing on my first nights, and again at dinner.'),
        step(1, 'My page already has my first check and logs. In a few more days, MyPet can start spotting changes.'),
        step(4, "That's my story! Your pet's story starts with one log."),
      ],
  };
}

/// Opens one demo pet's story on fresh demo data, over the app. Your own pets are never
/// touched. Ends back where it started.
Future<void> startStory(BuildContext context, DemoPet pet) async {
  final engine = context.read<BehaviourEngine>();
  final nav = Navigator.of(context);
  final parent = context.read<AppState>();
  final demo = AppState(LocalBackend(), clock: parent.clock, detectInBackground: parent.detectInBackground);
  await demo.backend.signIn('', '');
  for (var i = 0; i < 50 && !demo.carerKnown; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  final clips = await loadDemoClips();
  final dir = await unpackDemoClips(clips);
  demo.clipDir = dir;
  await addDemoPets(demo, fixedIds: true, clips: clips, clipDir: dir);
  for (var i = 0; i < 50 && demo.activePets.length < demoPets.length; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  demo.look = parent.look;
  demo.clipKeep = parent.clipKeep;
  demo.startGuide(Guide(steps: storySteps(demo, pet), narrator: pet.name, onDone: () => nav.pop()));
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

/// "Try a demo": example pets, each with a month of logs and real clips, told as a story.
class DemoPickerScreen extends StatelessWidget {
  const DemoPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Try a demo')),
      body: PageWash(
        child: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
          Text('Example pets with a month of logs and real clips from Wikimedia Commons. Your own pets are not touched.',
              style: t.textTheme.bodyMedium!.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: Tokens.space4),
          for (final (i, d) in demoPets.indexed) ...[
            MyCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(Tokens.radiusCard),
                onTap: () {
                  Feel.tap();
                  startStory(context, d);
                },
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.space4),
                  child: Row(children: [
                    PetPortrait.of(d.pet, background: MyPetColors.of(context).petAccents[i], size: 64),
                    const SizedBox(width: Tokens.space4),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.title, style: t.textTheme.titleMedium),
                        const SizedBox(height: Tokens.space1),
                        Text(d.subtitle,
                            style: t.textTheme.bodyMedium!.copyWith(color: t.colorScheme.onSurfaceVariant)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: Tokens.space3),
          ],
        ]),
      ),
    );
  }
}

/// Keeps the guide's bubble on top of every page while a walkthrough runs, without
/// blocking the app: the person can tap around, open pages, and come back to it.
class GuideHost extends StatefulWidget {
  const GuideHost({super.key, required this.child});
  final Widget child;

  @override
  State<GuideHost> createState() => _GuideHostState();
}

class _GuideHostState extends State<GuideHost> {
  OverlayEntry? _entry;

  void _sync(AppState s) {
    if (!mounted) return;
    if (s.guide != null && _entry == null) {
      final nav = Navigator.of(context);
      final home = ModalRoute.of(context);
      final e = OverlayEntry(
        builder: (_) => ChangeNotifierProvider.value(
          value: s,
          // Next and Back show a tab, so first close any page opened on top of the tabs.
          child: GuideOverlay(backToTabs: () {
            if (home != null && !home.isCurrent) nav.popUntil((r) => r == home);
          }),
        ),
      );
      _entry = e;
      Overlay.of(context, rootOverlay: true).insert(e);
    } else if (s.guide == null && _entry != null) {
      _remove();
    }
  }

  void _remove() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync(s));
    return widget.child;
  }
}

/// The guide's speech bubble, pointing at the tab it talks about. It never blocks the app.
/// It can shrink to just the guide's face (tap the face to open it again) or be closed.
class GuideOverlay extends StatelessWidget {
  const GuideOverlay({super.key, this.backToTabs});
  final VoidCallback? backToTabs;

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
    final who = g.narrator ?? 'Pip';
    Widget face(double size) => narrator != null
        ? PetAvatar(pet: narrator, size: size)
        : ClipOval(
            child: Container(
              width: size,
              height: size,
              color: c.brandContainer,
              child: SvgPicture.asset('assets/illustrations/guide-dog.svg', fit: BoxFit.cover),
            ),
          );
    void step(int d) {
      Feel.tap();
      backToTabs?.call();
      s.guideStep(d);
    }

    if (g.collapsed) {
      // Just the guide's face in the corner, with how far along the story is.
      return Stack(children: [
        Positioned(
          right: Tokens.space4,
          bottom: bottom,
          child: Semantics(
            button: true,
            label: 'Open $who\'s guide, step ${g.at + 1} of ${g.steps.length}',
            excludeSemantics: true,
            child: Material(
              color: t.colorScheme.surface,
              shape: const CircleBorder(),
              elevation: 6,
              shadowColor: Colors.black38,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  Feel.tap();
                  s.setGuideCollapsed(false);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Stack(clipBehavior: Clip.none, children: [
                    face(56),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(10)),
                        child: Text('${g.at + 1}/${g.steps.length}',
                            style: t.textTheme.labelSmall!.copyWith(color: MyPetColors.onAccent(c.brand))),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]);
    }

    return Stack(children: [
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
              padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space2, Tokens.space3),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: Tokens.space2), child: face(48)),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: Tokens.space2),
                      child: Text(st.text, style: t.textTheme.bodyLarge),
                    ),
                  ),
                  Column(children: [
                    IconButton(
                      tooltip: 'Shrink the guide',
                      onPressed: () {
                        Feel.tap();
                        s.setGuideCollapsed(true);
                      },
                      icon: const Icon(Icons.close_fullscreen_rounded),
                    ),
                    // The tour just closes; a demo story closes by leaving the demo.
                    IconButton(
                      tooltip: g.onDone == null ? 'Close the guide' : 'Leave the demo',
                      onPressed: () {
                        Feel.tap();
                        backToTabs?.call();
                        s.endGuide();
                      },
                      icon: Icon(g.onDone == null ? Icons.close_rounded : Icons.logout_rounded),
                    ),
                  ]),
                ]),
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
                  if (g.at > 0)
                    IconButton(tooltip: 'Back', onPressed: () => step(-1), icon: const Icon(Icons.arrow_back_rounded)),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(96, Tokens.minTarget)),
                    onPressed: () => step(1),
                    child: Text(last ? 'Done' : 'Next'),
                  ),
                  const SizedBox(width: Tokens.space2),
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
