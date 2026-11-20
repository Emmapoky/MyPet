import '../util/io.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../behaviour/analysis.dart';
import '../behaviour/engine.dart';
import '../data/local_backend.dart';
import '../models/care_entry.dart';
import '../state/app_state.dart';
import '../state/demo_data.dart';
import 'feedback.dart';
import 'home_shell.dart';
import 'pet_detail_screen.dart';
import 'quick_log_screen.dart';
import 'settings_screen.dart';
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
  GuideStep step(int tab, String text, {String? target, GuideOpen open = GuideOpen.none}) =>
      GuideStep(tab, text, petName: d.name, target: target, open: open);
  return switch (d.id) {
    'demo-biscuit' => [
        step(0, "Woof! I'm Biscuit. Every evening my carer logs 3 things: did I eat, my energy, my toilet. Three taps.",
            target: 'log'),
        step(0, "They've logged $days days for me. MyPet needs 7 to learn what's usual for me. Before that it stays quiet.",
            target: 'stats'),
        step(0, 'This week I had low energy on 2 of the last 3 days. MyPet shows it in amber: a change from my usual, not a diagnosis.',
            target: 'flag'),
        step(3, 'Insights compares me only with my own usual range, the shaded band. The low bars are my flat days.',
            target: 'usual'),
        step(2, 'My carer just filmed me howling. Watch: MyPet reads the sound and the picture right here on the phone.',
            open: GuideOpen.check),
        step(1, 'My page keeps every check. Tap this one to replay it and hear each howl MyPet found.',
            open: GuideOpen.petPage, target: 'savedCheck'),
        step(1, 'Before the vet, my carer taps this PDF button to share my record. Vet letters can be added too.',
            open: GuideOpen.petPage, target: 'pdf'),
        step(4, "And I never miss dinner. That's my story! Try another pet, or start with your own."),
      ],
    'demo-mochi' => [
        step(0, "Meow, I'm Mochi. I usually clear my bowl. This week I ate only some, then none. MyPet noticed.",
            target: 'flag'),
        step(3, "For me that's rare, so MyPet points it out, with the days it saw. It's a change, not a diagnosis. A vet can tell why.",
            target: 'insightsFlag'),
        step(2, 'My carer filmed me hissing at the vacuum. Watch: sound and picture are read on the phone, never uploaded.',
            open: GuideOpen.check),
        step(1, 'My page keeps every check. Tap one to replay my hiss, or my purr from last week.',
            open: GuideOpen.petPage, target: 'savedCheck'),
        step(1, 'Settings decides what Save keeps: the video, only the sound, or just the results.',
            open: GuideOpen.settings, target: 'savedClips'),
        step(4, "Reminders keep my meals on time. That's my story!"),
      ],
    'demo-pepper' => [
        step(0, "Hi, I'm Pepper, a puppy! $days days of logs, and everything looks normal for me, so Today stays calm.",
            target: 'stats'),
        step(3, "I'm growing, so my weight goes up every week. MyPet expects that, and would only say something if it stopped.",
            target: 'weight'),
        step(3, 'My energy sits inside my usual band, so there is nothing to flag.', target: 'usual'),
        step(2, "Checks aren't only for worries. My carer filmed me barking at the gate. Watch MyPet find each bark.",
            open: GuideOpen.check),
        step(1, 'My page keeps those clips, so we can replay my good days too.',
            open: GuideOpen.petPage, target: 'savedCheck'),
        step(4, "Walks and meals are on Reminders. That's my story!"),
      ],
    _ => [
        step(0, "Mew, I'm Bean. I came home $days days ago, so I only have $days days of logs.", target: 'stats'),
        step(3, "MyPet needs 7 days to learn what's usual for me. Until then it shows what's typical for a kitten my age.",
            target: 'starter'),
        step(2, 'Checks work from day one. My carer filmed me meowing on my first night. Watch.', open: GuideOpen.check),
        step(1, 'My page already has my photo, my first check and my logs.', open: GuideOpen.petPage, target: 'photo'),
        step(4, "That's my story! Your pet's story starts with one log."),
      ],
  };
}

/// "Log while driving": Carl, a demo owner, answers the daily reminder by voice and the
/// log fills itself in as he speaks. Runs on Biscuit's demo data.
List<GuideStep> carlSteps() => const [
      GuideStep(0, "Meet Carl. He's driving home and remembers he hasn't logged Biscuit's day yet.",
          petName: 'Biscuit', open: GuideOpen.driving),
      GuideStep(0, "Hands on the wheel, so no tapping. MyPet's reminder pops up, and Carl just answers it by voice.",
          petName: 'Biscuit', open: GuideOpen.closeUp),
      GuideStep(0, "Listen. As Carl talks, MyPet fills in Biscuit's log. Watch 'Ate' change when he corrects himself.",
          petName: 'Biscuit', open: GuideOpen.voiceLog),
      GuideStep(0, 'All of it was understood on the phone, with no account and nothing uploaded. Once parked, Carl checks it and taps Save.',
          petName: 'Biscuit', stay: true, target: 'save'),
      GuideStep(0, "That's logging on the go. Try the mic on any daily log, or answer the evening reminder the same way.",
          petName: 'Biscuit'),
    ];

/// A full-screen scene for the driving demo: Carl in the car, then a close-up of Carl
/// with MyPet's reminder arriving.
class VoiceScene extends StatelessWidget {
  const VoiceScene({super.key, required this.closeUp, required this.petName});
  final bool closeUp;
  final String petName;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1E1B3A),
      body: Stack(fit: StackFit.expand, children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3B2F73), Color(0xFFE98A6B), Color(0xFF2B2740)],
              stops: [0, 0.55, 0.56],
            ),
          ),
        ),
        if (!closeUp) ...[
          const Positioned(left: 0, right: 0, bottom: 0, height: 260, child: _Road()),
          Align(
            alignment: const Alignment(0, 0.35),
            child: Semantics(
              label: 'Carl driving home',
              child: Icon(Icons.directions_car_filled_rounded, size: 150, color: c.brand),
            ),
          ),
        ] else
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CarerFace(name: 'Carl', size: 180),
              const SizedBox(height: Tokens.space4),
              Text('Carl', style: t.textTheme.headlineSmall!.copyWith(color: Colors.white)),
            ]),
          ),
        if (closeUp)
          Positioned(
            top: MediaQuery.paddingOf(context).top + Tokens.space3,
            left: Tokens.space3,
            right: Tokens.space3,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: -1, end: 0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => FractionalTranslation(translation: Offset(0, v), child: child),
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.space4),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 40,
                        height: 40,
                        color: c.brand,
                        child: const Icon(Icons.pets_rounded, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: Tokens.space3),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('MyPet · now', style: t.textTheme.labelMedium!.copyWith(color: Colors.black54)),
                        Text("How was $petName's day?",
                            style: t.textTheme.titleSmall!.copyWith(color: Colors.black87)),
                        Text('Hold to answer here, or tap to open.',
                            style: t.textTheme.bodySmall!.copyWith(color: Colors.black54)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// The road, with lane marks rushing past.
class _Road extends StatefulWidget {
  const _Road();
  @override
  State<_Road> createState() => _RoadState();
}

class _RoadState extends State<_Road> with SingleTickerProviderStateMixin {
  late final _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    // Endless only on a real device; a test would never settle.
    if (!const bool.fromEnvironment('FLUTTER_TEST') && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _move.repeat();
    }
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _move,
        builder: (_, _) => CustomPaint(painter: _RoadPainter(_move.value)),
      );
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.v);
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final road = Path()
      ..moveTo(size.width * 0.42, 0)
      ..lineTo(size.width * 0.58, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF3A3650));
    final mark = Paint()..color = const Color(0xFFF6E7B0);
    for (var i = 0; i < 6; i++) {
      final f = ((i + v) / 6);
      final y = f * f * size.height;
      final h = 6 + 30 * f;
      final w = 2 + 8 * f;
      canvas.drawRect(Rect.fromCenter(center: Offset(size.width / 2, y), width: w, height: h), mark);
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.v != v;
}

/// A demo owner's face: a friendly drawn person in the brand colours.
class CarerFace extends StatelessWidget {
  const CarerFace({super.key, required this.name, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = MyPetColors.of(context);
    return Semantics(
      label: name,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c.brandContainer, shape: BoxShape.circle),
        child: Icon(Icons.face_6_rounded, size: size * 0.8, color: c.brand),
      ),
    );
  }
}

/// The pet's newest saved check with a clip, copied so the demo can play and check it
/// as if it was just filmed (the bundled copy stays for replays).
Future<DemoCheckRun?> demoCheckFor(AppState s, String petId) async {
  final e = s.timelineOf(petId).ofKind(EntryKind.behaviourResult).where((e) => s.clipOf(e) != null).firstOrNull;
  final path = e == null ? null : s.clipOf(e);
  if (e == null || path == null || !File(path).existsSync()) return null;
  final ext = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '.mp4';
  final copy = '${Directory.systemTemp.path}/demo_check_${DateTime.now().millisecondsSinceEpoch}$ext';
  await File(path).copy(copy);
  return DemoCheckRun(petId, copy, outcomeFromEntry(e.data, clip: copy));
}

/// Opens one demo pet's story on fresh demo data, over the app. Your own pets are never
/// touched. Ends back where it started.
Future<void> startStory(BuildContext context, DemoPet pet, {List<GuideStep>? steps, String? narrator}) async {
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
  demo.demo = true;
  demo.look = parent.look;
  demo.clipKeep = parent.clipKeep;
  demo.startGuide(Guide(steps: steps ?? storySteps(demo, pet), narrator: narrator ?? pet.name, onDone: () => nav.pop()));
  await nav.push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (c) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: demo),
        Provider.value(value: engine),
      ],
      // A navigator of its own, so every page the demo opens (pet page, log, settings)
      // sits under the demo's AppState and finds the demo pets.
      child: const _DemoNavigator(),
    ),
  ));
  demo.dispose();
}

class _DemoNavigator extends StatefulWidget {
  const _DemoNavigator();

  @override
  State<_DemoNavigator> createState() => _DemoNavigatorState();
}

class _DemoNavigatorState extends State<_DemoNavigator> {
  final _key = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      onPopWithResult: (_) => _key.currentState?.maybePop(),
      child: Navigator(
        key: _key,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      ),
    );
  }
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
          MyCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(Tokens.radiusCard),
              onTap: () {
                Feel.tap();
                startStory(context, demoPets.first, steps: carlSteps(), narrator: 'Carl');
              },
              child: Padding(
                padding: const EdgeInsets.all(Tokens.space4),
                child: Row(children: [
                  const CarerFace(name: 'Carl', size: 64),
                  const SizedBox(width: Tokens.space4),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Log by voice while driving', style: t.textTheme.titleMedium),
                      const SizedBox(height: Tokens.space1),
                      Text("Carl tells MyPet about Biscuit's day, and the log fills itself in",
                          style: t.textTheme.bodyMedium!.copyWith(color: t.colorScheme.onSurfaceVariant)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
                ]),
              ),
            ),
          ),
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
  String? _stepKey;

  /// Shows the step: back to the tabs, then the page it opens, then its clip on Check.
  Future<void> _perform(AppState s, Guide g) async {
    final st = g.steps[g.at];
    if (st.stay) return;
    final nav = Navigator.of(context);
    final home = ModalRoute.of(context);
    if (home != null && !home.isCurrent) nav.popUntil((r) => r == home);
    final pet = s.activePets.where((p) => p.name == (st.petName ?? g.narrator)).firstOrNull;
    if (st.open != GuideOpen.check && s.demoCheck != null) s.runDemoCheck(null);
    switch (st.open) {
      case GuideOpen.petPage when pet != null:
        nav.push(MaterialPageRoute(builder: (_) => PetDetailScreen(petId: pet.id)));
      case GuideOpen.settings:
        nav.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      case GuideOpen.driving || GuideOpen.closeUp:
        nav.push(PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, _, _) => VoiceScene(closeUp: st.open == GuideOpen.closeUp, petName: pet?.name ?? 'Biscuit'),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ));
      case GuideOpen.voiceLog when pet != null:
        final script = await VoiceScript.load('carl_voice_log');
        if (identical(s.guide, g) && g.steps[g.at] == st) {
          nav.push(MaterialPageRoute(builder: (_) => QuickLogScreen(pet: pet, script: script)));
        }
      case GuideOpen.check when pet != null:
        final run = await demoCheckFor(s, pet.id);
        if (run != null && identical(s.guide, g) && g.steps[g.at] == st) s.runDemoCheck(run);
      default:
        break;
    }
  }

  void _sync(AppState s) {
    if (!mounted) return;
    final g = s.guide;
    final key = g == null ? null : '${identityHashCode(g)}:${g.at}';
    if (key != _stepKey) {
      _stepKey = key;
      if (g != null) _perform(s, g);
    }
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
        : g.narrator != null
            ? CarerFace(name: g.narrator!, size: size)
            : ClipOval(
            child: Container(
              width: size,
              height: size,
              color: c.brandContainer,
              child: SvgPicture.asset('assets/illustrations/guide-dog.svg', fit: BoxFit.cover),
            ),
          );
    void step(int d) {
      Feel.guideNext();
      s.guideStep(d);
    }

    // An off-white tinted with the brand colour, so the bubble stands out on white pages.
    final fill = Color.alphaBlend(c.brand.withValues(alpha: t.brightness == Brightness.dark ? 0.22 : 0.09), t.colorScheme.surface);
    void shrink() {
      Feel.tap();
      s.setGuideCollapsed(true);
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
        child: CustomPaint(size: const Size(20, 12), painter: _Arrow(fill)),
      ),
      Positioned(
        left: Tokens.space3,
        right: Tokens.space3,
        bottom: bottom,
        child: Semantics(
          liveRegion: true,
          container: true,
          child: Material(
            color: fill,
            elevation: 2,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusHero),
              side: BorderSide(color: c.brand.withValues(alpha: 0.45), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space2, Tokens.space3),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Tap the face to shrink the guide; a hint says so until it has been used once.
                  Padding(
                    padding: const EdgeInsets.only(top: Tokens.space2),
                    child: Column(children: [
                      Tooltip(
                        message: 'Tap me to shrink',
                        child: Semantics(
                          button: true,
                          label: 'Shrink the guide',
                          excludeSemantics: true,
                          child: InkResponse(
                            onTap: shrink,
                            radius: 30,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.brand, width: 2)),
                              child: face(48),
                            ),
                          ),
                        ),
                      ),
                      if (!s.guideHintSeen)
                        GestureDetector(
                          onTap: shrink,
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(8)),
                            child: Text('Tap me\nto shrink',
                                textAlign: TextAlign.center,
                                style: t.textTheme.labelSmall!.copyWith(color: MyPetColors.onAccent(c.brand), height: 1.1)),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: Tokens.space2),
                      child: Text(st.text, style: t.textTheme.bodyLarge),
                    ),
                  ),
                  Column(children: [
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
