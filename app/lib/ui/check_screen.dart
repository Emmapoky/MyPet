import 'dart:async';
import '../util/media.dart';
import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../behaviour/analysis.dart';
import '../behaviour/engine.dart';
import '../util/check_timing.dart';
import '../models/care_entry.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import 'home_shell.dart';
import 'theme.dart';
import 'widgets/clip_keep.dart';
import 'widgets/clip_replay.dart';
import 'widgets/common.dart';
import 'widgets/pet_bar.dart';
import 'feedback.dart';
import 'wording.dart';

/// Behaviour check: Record (Figma 07), Recording (08) and Result (09, outcomes A to C).
/// Report Table 4.4 screens 4 and 5; FR02, FR20, FR-N01, FR-N02, NFR03.
class CheckScreen extends StatefulWidget {
  const CheckScreen({super.key});

  /// The Check tab's index in the bottom tabs.
  static const tabIndex = 2;

  /// Longest clip (report Table 4.1: 10 s; shorter clips are repeat-padded).
  static const seconds = 10;

  /// Shortest clip before Stop is allowed.
  static const minSeconds = 5;

  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

enum _Step { record, recording, checking, result }

class _CheckScreenState extends State<CheckScreen> {
  _Step _step = _Step.record;
  bool _loadStarted = false;
  bool _ready = false;
  String? _problem;
  int _left = CheckScreen.seconds;
  bool _cameraOn = false;
  bool _cameraAsked = false;
  Timer? _timer;
  CheckOutcome? _outcome;
  Pet? _checkedPet;
  int _ms = 0;
  bool _picked = false;
  bool _saved = false;

  late BehaviourEngine _engine;

  // The demo plays a pet's clip as if it was just filmed, then shows its saved result.
  DemoCheckRun? _demoRun;
  VideoPlayerController? _demoVideo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _engine = context.read<BehaviourEngine>();
  }

  void _maybeDemo(AppState s) {
    final r = s.demoCheck;
    if (r == null) {
      if (_demoRun != null && _demoVideo != null) _endDemo();
      return;
    }
    if (identical(r, _demoRun)) return;
    _demoRun = r;
    WidgetsBinding.instance.addPostFrameCallback((_) => _playDemo(s, r));
  }

  void _endDemo() {
    _timer?.cancel();
    final v = _demoVideo;
    _demoVideo = null;
    _demoRun = null;
    v?.dispose();
    if (mounted && _step != _Step.result) setState(() => _step = _Step.record);
  }

  Future<void> _playDemo(AppState s, DemoCheckRun r) async {
    final pet = s.pets.where((p) => p.id == r.petId).firstOrNull;
    if (!mounted || pet == null) return;
    _timer?.cancel();
    s.selectPet(pet.id);
    bool live() => mounted && identical(s.demoCheck, r);
    final v = clipPlayer(r.clip);
    if (v == null) {
      if (live()) _demoResult(s, r, pet);
      return;
    }
    try {
      await v.initialize();
    } catch (_) {
      await v.dispose();
      if (live()) _demoResult(s, r, pet);
      return;
    }
    if (!live()) return v.dispose();
    await Feel.recordStart();
    final secs = v.value.duration.inSeconds.clamp(CheckScreen.minSeconds, CheckScreen.seconds);
    setState(() {
      _demoVideo = v;
      _step = _Step.recording;
      _left = secs;
      _outcome = null;
    });
    await v.setVolume(1);
    await v.play();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!live()) return t.cancel();
      if (_left > 1) return setState(() => _left--);
      t.cancel();
      await v.pause();
      unawaited(Feel.recordStop());
      setState(() => _step = _Step.checking);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (live()) _demoResult(s, r, pet);
    });
  }

  void _demoResult(AppState s, DemoCheckRun r, Pet pet) {
    final v = _demoVideo;
    _demoVideo = null;
    v?.dispose();
    setState(() {
      _outcome = r.outcome;
      _checkedPet = pet;
      _ms = 900;
      _picked = false;
      _saved = false;
      _step = _Step.result;
    });
    Feel.result();
    s.runDemoCheck(null);
  }

  @override
  void dispose() {
    _demoVideo?.dispose();
    _timer?.cancel();
    _engine.discard(_outcome?.clip);
    super.dispose();
  }

  // Load the model the first time the tab opens, not at app start and not after recording.
  void _loadOnce() {
    if (_loadStarted) return;
    _loadStarted = true;
    _openCamera();
    _engine.load().then((_) {
      if (mounted) setState(() => _ready = true);
    }, onError: (Object e) {
      if (mounted) setState(() => _problem = e is CheckProblem ? e.message : 'The model could not load.');
    });
  }

  Future<void> _openCamera() async {
    final ok = await _engine.openCamera();
    if (mounted) {
      setState(() {
        _cameraOn = ok;
        _cameraAsked = true;
      });
    }
  }

  Future<void> _record(Pet pet) async {
    if (!_cameraOn) {
      await _openCamera();
      if (!_cameraOn) {
        _say('Camera or microphone access is off. Turn them on in Settings, or choose a video.');
        return;
      }
    }
    await Feel.recordStart();
    await Future<void>.delayed(const Duration(milliseconds: 300)); // keep the chime out of the clip
    await _engine.startRecording();
    setState(() {
      _step = _Step.recording;
      _left = CheckScreen.seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        _stop(pet);
      } else {
        setState(() => _left--);
      }
    });
  }

  Future<void> _stop(Pet pet) async {
    _timer?.cancel();
    if (_step != _Step.recording) return;
    final path = await _engine.stopRecording();
    unawaited(Feel.recordStop());
    await _check(pet, path, picked: false);
  }

  Future<void> _pick(Pet pet) async {
    try {
      final path = await _engine.pickFile();
      if (path == null) return;
      await _check(pet, path, picked: true);
    } on CheckProblem catch (e) {
      _say(e.message);
    }
  }

  Future<void> _check(Pet pet, String path, {required bool picked}) async {
    setState(() => _step = _Step.checking);
    final sw = Stopwatch()..start();
    try {
      final o = await _engine.check(path, pet.species, picked: picked);
      if (!mounted) return;
      setState(() {
        _outcome = o;
        _checkedPet = pet;
        _ms = sw.elapsedMilliseconds;
        _picked = picked;
        _saved = false;
        _step = _Step.result;
      });
    } on CheckProblem catch (e) {
      _reset();
      _say(e.message);
    } catch (_) {
      _reset();
      _say('Something went wrong while checking. The clip was deleted. Please try again.');
    }
  }

  void _reset() {
    if (!mounted) return;
    // A clip not saved is deleted now (FR-N02); Save already kept what Settings asks for.
    final clip = _outcome?.clip;
    if (clip != null) _engine.discard(clip);
    setState(() {
      _step = _Step.record;
      _outcome = null;
      _left = CheckScreen.seconds;
    });
  }

  Future<void> _save() async {
    final o = _outcome!, pet = _checkedPet!;
    if (_saved) return;
    _saved = true;
    final s = context.read<AppState>();
    unawaited(Feel.saved());
    final data = o.toEntryData(ms: _ms, source: _picked ? 'file' : 'recording');
    // Keep the video, its sound or nothing, as picked in Settings (on this phone only).
    final clip = o.clip, dir = s.clipDir;
    String? kept;
    if (clip != null && dir != null) {
      kept = await _engine.keep(clip, dir, s.backend.newId(), s.clipKeep);
      _outcome = o.withClip(clip: null, seconds: o.seconds, moments: o.moments);
    }
    if (kept != null) data['clip'] = kept;
    final e = await s.addEntry(pet.id, EntryKind.behaviourResult, data);
    _reset();
    // Stay on Check, ready for the next pet; Undo if it was a mistake.
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text("Saved to ${pet.name}'s timeline"),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            s.deleteEntry(e);
            deleteKeptClip(s, e);
          },
        ),
      ));
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.tab == CheckScreen.tabIndex) _loadOnce();
    _maybeDemo(s);
    final pet = s.selectedPet;
    final onResult = _step == _Step.result && _outcome != null;
    final dv = _demoVideo;
    if (dv != null && pet != null && !onResult) return _DemoFilming(video: dv, pet: pet, left: _left, checking: _step == _Step.checking);
    if (pet != null && _problem == null && !onResult) {
      // Full-screen camera, like a camera app: pets to swipe through by the record button.
      return Scaffold(
        backgroundColor: Colors.black,
        body: _CameraView(
          camera: _cameraOn ? _engine.preview() : null,
          cameraAsked: _cameraAsked,
          pet: pet,
          step: _step,
          ready: _ready,
          left: _left,
          pets: s.activePets,
          onPet: (p) => s.selectPet(p.id),
          onRecord: () => _record(pet),
          onStop: () => _stop(pet),
          onPick: () => _pick(pet),
          active: s.tab == CheckScreen.tabIndex,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: onResult ? BackButton(onPressed: _reset) : null,
        // The result names who was checked, so it is clear with several pets.
        title: onResult
            ? Row(children: [
                PetAvatar(pet: _checkedPet, size: 36),
                const SizedBox(width: Tokens.space3),
                Flexible(child: Text(_checkedPet!.name, overflow: TextOverflow.ellipsis)),
              ])
            : const Text('Check'),
        actions: const [MoreMenu()],
      ),
      body: PageWash(child: SafeArea(child: _body(context, s, pet))),
    );
  }

  Widget _body(BuildContext context, AppState s, Pet? pet) {
    const pad = EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space4);
    if (pet == null) {
      return ListView(padding: pad, children: [
        EmptyState(
          icon: Icons.pets_rounded,
          title: 'Add a pet first',
          body: 'The check reads your cat or dog\'s sounds, so it needs to know which pet it is.',
          action: FilledButton.icon(
            onPressed: () => s.goToTab(1),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add a pet'),
          ),
        ),
      ]);
    }
    if (_problem != null) {
      return ListView(padding: pad, children: [
        EmptyState(icon: Icons.downloading_rounded, title: 'Behaviour check not ready', body: _problem!),
      ]);
    }
    if (_step == _Step.result && _outcome != null) {
      return ResultView(
        outcome: _outcome!,
        pet: _checkedPet!,
        ms: _ms,
        onRetake: _reset,
        onSave: _save,
      );
    }
    return const SizedBox.shrink();
  }
}

/// The demo's "just filmed" view: the clip plays full screen with its sound and a REC
/// timer, then MyPet reads it, as a real check would on the phone.
class _DemoFilming extends StatelessWidget {
  const _DemoFilming({required this.video, required this.pet, required this.left, required this.checking});
  final VideoPlayerController video;
  final Pet pet;
  final int left;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final shot = (video.value.duration.inSeconds.clamp(CheckScreen.minSeconds, CheckScreen.seconds) - left + 1)
        .clamp(0, CheckScreen.seconds);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Center(child: AspectRatio(aspectRatio: video.value.aspectRatio, child: VideoPlayer(video))),
          Positioned(
            top: Tokens.space4,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                liveRegion: true,
                label: checking ? 'Reading the clip of ${pet.name}' : 'Filming ${pet.name}, $shot seconds',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Tokens.space4, vertical: Tokens.space2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (!checking) ...[
                      Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle)),
                      const SizedBox(width: Tokens.space2),
                      Text('Filming ${pet.name}  0:${shot.toString().padLeft(2, '0')}',
                          style: t.textTheme.titleSmall!.copyWith(color: Colors.white)),
                    ] else ...[
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: Tokens.space2),
                      Text('Reading sound and picture on this phone',
                          style: t.textTheme.titleSmall!.copyWith(color: Colors.white)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
          if (checking) Positioned.fill(child: ColoredBox(color: c.brand.withValues(alpha: 0.12))),
        ]),
      ),
    );
  }
}

String _speciesWord(Species s) => s == Species.cat ? 'cat' : 'dog';

/// Full-screen camera (Check). The picture fills the screen; along the bottom, the
/// carer's pets sit in a swipe row with the record ring in the middle, so changing
/// who is being checked is one swipe, like picking a lens in a camera app.
class _CameraView extends StatefulWidget {
  const _CameraView({
    required this.camera,
    required this.cameraAsked,
    required this.pet,
    required this.step,
    required this.ready,
    required this.left,
    required this.pets,
    required this.onPet,
    required this.onRecord,
    required this.onStop,
    required this.onPick,
    required this.active,
  });

  /// The Check tab is the one showing (spinners only animate then).
  final bool active;
  final Widget? camera;
  final bool cameraAsked;
  final Pet pet;
  final _Step step;
  final bool ready;
  final int left;
  final List<Pet> pets;
  final ValueChanged<Pet> onPet;
  final VoidCallback onRecord, onStop, onPick;

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  late final PageController _pages = PageController(
    viewportFraction: 0.24,
    initialPage: math.max(0, widget.pets.indexWhere((p) => p.id == widget.pet.id)),
  );

  @override
  void didUpdateWidget(_CameraView old) {
    super.didUpdateWidget(old);
    final i = widget.pets.indexWhere((p) => p.id == widget.pet.id);
    if (i >= 0 && _pages.hasClients && (_pages.page?.round() ?? i) != i) {
      _pages.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final w = widget;
    final recording = w.step == _Step.recording;
    final checking = w.step == _Step.checking;
    final elapsed = recording ? CheckScreen.seconds - w.left : 0;
    final canStop = elapsed >= CheckScreen.minSeconds;
    final white = t.textTheme.titleSmall!.copyWith(color: Colors.white);
    Widget pill(Widget child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space3, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(Tokens.radiusButton),
          ),
          child: child,
        );

    return Stack(fit: StackFit.expand, children: [
      // The picture, or a dark gradient when there is no camera.
      if (w.camera != null)
        ExcludeSemantics(
          child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: 300, height: 400, child: w.camera)),
        )
      else
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF232525), Color(0xFF2C2440)],
            ),
          ),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.videocam_rounded, size: 56, color: Colors.white),
              const SizedBox(height: Tokens.space2),
              Text(w.cameraAsked ? 'No camera here' : 'Opening camera', style: white),
            ]),
          ),
        ),
      // Soft dark fades so white text stays readable on any picture.
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.18, 0.62, 1],
              colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
            ),
          ),
        ),
      ),
      if (checking)
        Container(
          color: Colors.black.withValues(alpha: 0.4),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: Tokens.space3),
              Text('Checking', style: white),
            ]),
          ),
        ),
      SafeArea(
        child: Column(children: [
          // Top: what is happening, and a way to use a video instead.
          Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space2, 0),
            child: Row(children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: recording || checking
                      ? Semantics(
                          label: recording ? 'Recording' : null,
                          child: pill(Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.fiber_manual_record_rounded, size: 16, color: c.brand),
                            const SizedBox(width: Tokens.space1),
                            Text('0:${elapsed.toString().padLeft(2, '0')}', style: white),
                          ])),
                        )
                      // Who is being checked: tap to pick another pet (also swipe at the bottom).
                      : Semantics(
                          button: true,
                          label: 'Checking ${w.pet.name}. Change pet',
                          excludeSemantics: true,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: const StadiumBorder(),
                            child: InkWell(
                              customBorder: const StadiumBorder(),
                              onTap: () {
                                Feel.tap();
                                showPetSwitcher(context);
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, Tokens.space2, 4),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  PetAvatar(pet: w.pet, size: 36),
                                  const SizedBox(width: Tokens.space2),
                                  Flexible(child: Text(w.pet.name, style: white, overflow: TextOverflow.ellipsis)),
                                  const Icon(Icons.expand_more_rounded, color: Colors.white),
                                ]),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              if (!recording && !checking)
                IconButton(
                  tooltip: 'Choose a video',
                  onPressed: w.ready ? () { Feel.tap(); w.onPick(); } : null,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    minimumSize: const Size(Tokens.minTarget, Tokens.minTarget),
                  ),
                  icon: const Icon(Icons.video_library_rounded, color: Colors.white),
                ),
            ]),
          ),
          const Spacer(),
          // Bottom: pet row with the record ring in the middle.
          if (!checking) ...[
            Text(
              recording
                  ? (canStop ? 'Tap to stop' : 'Hold steady')
                  : '${w.pet.name} · ${_speciesWord(w.pet.species)}',
              style: white,
            ),
            const SizedBox(height: Tokens.space3),
            SizedBox(
              height: 104,
              child: Stack(alignment: Alignment.center, children: [
                if (!recording)
                  PageView.builder(
                    controller: _pages,
                    itemCount: w.pets.length,
                    onPageChanged: (i) {
                      Feel.tap();
                      w.onPet(w.pets[i]);
                    },
                    itemBuilder: (_, i) {
                      final p = w.pets[i];
                      final on = p.id == w.pet.id;
                      return Center(
                        child: Semantics(
                          button: true,
                          selected: on,
                          label: on ? (w.ready ? 'Record a clip of ${p.name}' : 'Getting ready') : 'Check ${p.name}',
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: () {
                              if (on) {
                                if (w.ready) w.onRecord();
                              } else {
                                _pages.animateToPage(i,
                                    duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                              }
                            },
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 200),
                              scale: on ? 1 : 0.72,
                              child: Stack(clipBehavior: Clip.none, children: [
                                PetAvatar(pet: p, size: 72, onHero: !on),
                                if (on && !w.ready && w.active)
                                  const Positioned.fill(
                                    child: Padding(
                                      padding: EdgeInsets.all(18),
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    ),
                                  ),
                                if (on && w.ready)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: c.brand,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.videocam_rounded, size: 16, color: Colors.white),
                                    ),
                                  ),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                // The ring: white around the chosen pet; while recording it fills as time passes.
                IgnorePointer(
                  ignoring: !recording,
                  child: Semantics(
                    button: recording,
                    enabled: canStop,
                    label: recording ? 'Stop recording' : null,
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: recording && canStop ? w.onStop : null,
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: Stack(alignment: Alignment.center, children: [
                          CircularProgressIndicator(
                            value: recording ? elapsed / CheckScreen.seconds : 1,
                            strokeWidth: 5,
                            color: recording ? c.brand : Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.35),
                            constraints: const BoxConstraints.tightFor(width: 96, height: 96),
                          ),
                          if (recording)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: canStop ? 34 : 28,
                              height: canStop ? 34 : 28,
                              decoration: BoxDecoration(
                                color: canStop ? c.brand : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: Tokens.space3),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_outline_rounded, size: 14, color: Colors.white),
              const SizedBox(width: Tokens.space1),
              Flexible(
                child: Text('Only when you tap. Deleted after the check.',
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodySmall!.copyWith(color: Colors.white)),
              ),
            ]),
            const SizedBox(height: Tokens.space3),
          ],
        ]),
      ),
    ]);
  }
}

/// Result (Figma 09) and the other outcomes A, B and C (design README).
class ResultView extends StatelessWidget {
  const ResultView({
    super.key,
    required this.outcome,
    required this.pet,
    required this.ms,
    this.onRetake,
    this.onSave,
  });
  final CheckOutcome outcome;
  final Pet pet;
  final int ms;

  /// Null when showing a saved check from the timeline (read only).
  final VoidCallback? onRetake;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final keep = context.watch<AppState>().clipKeep;
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final o = outcome;
    const gap = SizedBox(height: Tokens.space4);
    final notHeard = o.kind == OutcomeKind.notHeard;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space4),
      children: [
        ClipReplay(clip: o.clip, seconds: o.seconds, moments: o.moments),
        gap,
        ...switch (o.kind) {
          OutcomeKind.feeling => [
              MyCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Most likely', style: t.textTheme.labelLarge!.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: Tokens.space1),
                  Semantics(
                    label: 'Most likely: ${o.feelings.first.$1}, ${_pct(o.feelings.first.$2)}',
                    excludeSemantics: true,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: Text(Wording.feelingHeadline(o.feelings.first.$1), style: t.textTheme.titleLarge)),
                      Text(_pct(o.feelings.first.$2),
                          style: t.textTheme.displaySmall!.copyWith(color: t.colorScheme.primary)),
                    ]),
                  ),
                  const SizedBox(height: Tokens.space3),
                  _Bar(value: o.feelings.first.$2, height: 10, color: t.colorScheme.primary),
                  if (o.feelings.length > 1) ...[
                    const SizedBox(height: Tokens.space3),
                    Text(
                      [for (final (n, p) in o.feelings.skip(1)) '${Wording.feelingShort(n)} ${_pct(p)}'].join(' · '),
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ]),
              ),
            ],
          OutcomeKind.notSure => [
              MyCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.help_outline_rounded, color: t.colorScheme.onSurfaceVariant),
                    const SizedBox(width: Tokens.space2),
                    Text('Not sure', style: t.textTheme.titleLarge),
                  ]),
                  const SizedBox(height: Tokens.space2),
                  Text('No feeling stood out. Here is how likely each one is.', style: t.textTheme.bodyLarge),
                ]),
              ),
              gap,
              MyCard(child: Column(children: [for (final f in o.feelings) _FeelingRow(f)])),
            ],
          OutcomeKind.heardOnly => [
              MyCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Heard', style: t.textTheme.labelLarge!.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: Tokens.space1),
                  Text(o.topSound, style: t.textTheme.titleLarge),
                  const SizedBox(height: Tokens.space1),
                  Text(soundGuess(o.sounds), style: t.textTheme.bodySmall),
                ]),
              ),
            ],
          OutcomeKind.notHeard => [
              MyCard(
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: t.colorScheme.surfaceContainer, shape: BoxShape.circle),
                    child: Icon(Icons.hearing_rounded, color: t.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Did not clearly hear a ${_speciesWord(o.species)}', style: t.textTheme.titleLarge),
                      const SizedBox(height: Tokens.space1),
                      Text('Closest sound: ${soundGuess(o.sounds)}',
                          style: t.textTheme.bodyLarge!.copyWith(color: t.colorScheme.onSurfaceVariant)),
                    ]),
                  ),
                ]),
              ),
              gap,
              _Note(
                icon: Icons.tips_and_updates_rounded,
                text: 'Try again closer to your ${_speciesWord(o.species)}, in a quieter spot.',
                color: c.surfaceTint,
              ),
            ],
        },
        // The pills above already show each sound; this card is only for clips with none.
        if (!notHeard && !o.moments.any((m) => m.source == MomentSource.sound)) ...[
          gap,
          MyCard(
            title: 'Sounds heard',
            child: Wrap(spacing: Tokens.space2, runSpacing: Tokens.space2, children: [
              for (final (n, p) in o.sounds.take(3)) _SoundChip(p > 0 ? '$n ${_pct(p)}' : n),
            ]),
          ),
          if (o.kind == OutcomeKind.heardOnly) ...[
            const SizedBox(height: Tokens.space2),
            Text('Feelings are only read from meows.', style: t.textTheme.bodySmall),
          ],
        ],
        gap,
        _Note(icon: Icons.info_outline_rounded, text: Wording.notDiagnosisBehaviour, color: c.surfaceTint),
        if (onSave != null) checkTiming(context, clip: o.clip),
        gap,
        if (onSave != null) ...[
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onRetake,
              icon: Icon(notHeard ? Icons.close_rounded : Icons.replay_rounded),
              label: Text(notHeard ? 'Close' : 'Retake'),
            ),
          ),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: notHeard
                ? FilledButton.icon(
                    onPressed: onRetake, icon: const Icon(Icons.replay_rounded), label: const Text('Try again'))
                : FilledButton.icon(
                    onPressed: onSave, icon: const Icon(Icons.check_rounded), label: const Text('Save')),
          ),
        ]),
        const SizedBox(height: Tokens.space3),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(o.picture == PictureUse.combined ? Icons.videocam_rounded : Icons.graphic_eq_rounded,
              size: 16, color: t.colorScheme.onSurfaceVariant),
          const SizedBox(width: Tokens.space1),
          Flexible(
            child: Text(
                switch (o.picture) {
                  PictureUse.combined => 'From picture and sound',
                  PictureUse.confirmed => 'From sound · ${_speciesWord(o.species)} seen in picture',
                  PictureUse.notSeen => 'From sound · ${_speciesWord(o.species)} not clear in picture',
                  PictureUse.none => 'From sound',
                },
                style: t.textTheme.bodySmall),
          ),
        ]),
        const SizedBox(height: Tokens.space1),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(clipKeepIcon(keep), size: 16, color: t.colorScheme.onSurfaceVariant),
          const SizedBox(width: Tokens.space1),
          Flexible(child: Text(clipKeepOnSave(keep), style: t.textTheme.bodySmall)),
          TextButton(
            onPressed: () => showClipKeepSheet(context),
            child: Semantics(label: 'Change what Save keeps', excludeSemantics: true, child: const Text('Change')),
          ),
        ]),
        ],
      ],
    );
  }
}

/// A saved check, opened from the timeline: the same result, read only, with its kept
/// video or sound to replay (or just the moments' times when no clip was kept).
class SavedCheckScreen extends StatelessWidget {
  const SavedCheckScreen({super.key, required this.pet, required this.entry, this.onDelete});
  final Pet pet;
  final CareEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Row(children: [
            PetAvatar(pet: pet, size: 36),
            const SizedBox(width: Tokens.space3),
            Flexible(
              child: Text(DateFormat('EEE d MMM').format(entry.createdAt.toLocal()), overflow: TextOverflow.ellipsis),
            ),
          ]),
          actions: [
            if (onDelete != null)
              IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: onDelete),
          ],
        ),
        body: PageWash(
          child: SafeArea(
            child: Column(children: [
              Expanded(
                child: ResultView(
                  outcome: outcomeFromEntry(entry.data, clip: context.read<AppState>().clipOf(entry)),
                  pet: pet,
                  ms: 0,
                ),
              ),
              // Demo clips are free-licence videos from Wikimedia Commons, credited here.
              if (entry.data['credit'] is String)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Tokens.space4, 0, Tokens.space4, Tokens.space2),
                  child: Text('Clip: ${entry.data['credit']} (Wikimedia Commons)',
                      style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                ),
            ]),
          ),
        ),
      );
}

/// Shown confidence is capped: no short clip deserves "98%" (pet owner review, Trust in Check).
String _pct(double p) => showPct(p);

class _FeelingRow extends StatelessWidget {
  const _FeelingRow(this.f);
  final (String, double) f;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      label: '${f.$1}, ${_pct(f.$2)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(f.$1, style: t.textTheme.bodyLarge)),
            Text(_pct(f.$2), style: t.textTheme.bodyLarge),
          ]),
          const SizedBox(height: Tokens.space1),
          _Bar(value: f.$2, height: 8, color: t.colorScheme.outline),
        ]),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.height, required this.color});
  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: height,
          color: color,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        ),
      );
}

class _SoundChip extends StatelessWidget {
  const _SoundChip(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.space3, vertical: Tokens.space2),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusChip),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.graphic_eq_rounded, size: 16, color: t.colorScheme.onSurfaceVariant),
        const SizedBox(width: Tokens.space1),
        Text(name, style: t.textTheme.labelLarge),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Tokens.radiusInput)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: t.colorScheme.onPrimaryContainer),
        const SizedBox(width: Tokens.space2),
        Expanded(child: Text(text, style: t.textTheme.bodyLarge)),
      ]),
    );
  }
}
