import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../behaviour/analysis.dart';
import '../behaviour/engine.dart';
import '../models/care_entry.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import 'home_shell.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/pet_bar.dart';
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

  BehaviourEngine get _engine => context.read<BehaviourEngine>();

  @override
  void dispose() {
    _timer?.cancel();
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
    await s.addEntry(pet.id, EntryKind.behaviourResult,
        o.toEntryData(ms: _ms, source: _picked ? 'file' : 'recording'));
    _reset();
    s.goToTab(0);
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.tab == CheckScreen.tabIndex) _loadOnce();
    final pet = s.selectedPet;
    final onResult = _step == _Step.result && _outcome != null;
    return Scaffold(
      appBar: AppBar(
        leading: onResult ? BackButton(onPressed: _reset) : null,
        title: Text(onResult ? 'Result' : 'Check'),
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
    return _RecordView(
      camera: _cameraOn ? _engine.preview() : null,
      cameraAsked: _cameraAsked,
      pet: pet,
      step: _step,
      ready: _ready,
      left: _left,
      pets: s.activePets,
      onRecord: () => _record(pet),
      onStop: () => _stop(pet),
      onPick: () => _pick(pet),
    );
  }
}

String _speciesWord(Species s) => s == Species.cat ? 'cat' : 'dog';

class _RecordView extends StatelessWidget {
  const _RecordView({
    required this.camera,
    required this.cameraAsked,
    required this.pet,
    required this.step,
    required this.ready,
    required this.left,
    required this.pets,
    required this.onRecord,
    required this.onStop,
    required this.onPick,
  });
  final Widget? camera;
  final bool cameraAsked;
  final Pet pet;
  final _Step step;
  final bool ready;
  final int left;
  final List<Pet> pets;
  final VoidCallback onRecord, onStop, onPick;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final recording = step == _Step.recording;
    final checking = step == _Step.checking;
    final elapsed = recording ? CheckScreen.seconds - left : 0;
    final canStop = elapsed >= CheckScreen.minSeconds;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space4),
      children: [
        if (pets.length > 1 && step == _Step.record) ...[
          PetStrip(pets: pets, selected: pet.id, onSelect: () {}),
          const SizedBox(height: Tokens.space4),
        ],
        // Camera panel with viewfinder corners (the old app's Check screen).
        _Viewfinder(
          camera: camera,
          label: recording ? 'Recording · $left s' : 'Fit ${pet.name} in the frame',
          child: camera != null
              ? null
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.videocam_rounded, size: 56, color: Colors.white),
                  const SizedBox(height: Tokens.space2),
                  Text(checking ? 'Checking' : cameraAsked ? 'No camera here' : 'Opening camera',
                      style: t.textTheme.titleSmall!.copyWith(color: Colors.white)),
                ]),
        ),
        const SizedBox(height: Tokens.space4),
        MyCard(
          child: Row(children: [
            Expanded(
              child: Semantics(
                liveRegion: recording,
                child: Text('0:${elapsed.toString().padLeft(2, '0')} / 0:${CheckScreen.seconds}',
                    style: t.textTheme.titleSmall),
              ),
            ),
            checking
                ? const SizedBox(
                    width: 96, height: 96, child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
                : _BigButton(
                    recording: recording,
                    enabled: recording ? canStop : ready,
                    onPressed: recording ? onStop : onRecord,
                  ),
            Expanded(
              child: Text(
                checking
                    ? 'Checking'
                    : recording
                        ? (canStop ? 'Tap to stop' : '${CheckScreen.minSeconds - elapsed} s more')
                        : ready
                            ? '${CheckScreen.minSeconds} to ${CheckScreen.seconds} s'
                            : 'Getting ready',
                textAlign: TextAlign.end,
                style: t.textTheme.bodySmall,
              ),
            ),
          ]),
        ),
        const SizedBox(height: Tokens.space4),
        OutlinedButton.icon(
          onPressed: ready && step == _Step.record ? onPick : null,
          icon: const Icon(Icons.video_library_rounded),
          label: const Text('Choose a video'),
        ),
        const SizedBox(height: Tokens.space3),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: t.colorScheme.onSurfaceVariant),
          const SizedBox(width: Tokens.space1),
          Flexible(child: Text('Only when you tap. Deleted after the check.', style: t.textTheme.bodySmall)),
        ]),
      ],
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.label, this.child, this.camera});
  final String label;
  final Widget? child;
  final Widget? camera;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      height: 340,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusHero),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF232525), Color(0xFF1F6F6E)],
        ),
      ),
      child: CustomPaint(
        foregroundPainter: _Corners(),
        child: Stack(fit: StackFit.expand, children: [
          if (camera != null) ExcludeSemantics(child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: 300, height: 400, child: camera))),
          Positioned(
            top: Tokens.space4,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space3, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(Tokens.radiusButton),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.videocam_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: Tokens.space1),
                  Text(label, style: t.textTheme.labelLarge!.copyWith(color: Colors.white)),
                ]),
              ),
            ),
          ),
          if (child != null) Center(child: Padding(padding: const EdgeInsets.only(top: 40), child: child)),
        ]),
      ),
    );
  }
}

class _Corners extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const m = 20.0, l = 28.0;
    final w = size.width, h = size.height;
    for (final (x, y, dx, dy) in [(m, m, 1.0, 1.0), (w - m, m, -1.0, 1.0), (m, h - m, 1.0, -1.0), (w - m, h - m, -1.0, -1.0)]) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * l, y), p);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * l), p);
    }
  }

  @override
  bool shouldRepaint(_Corners old) => false;
}

/// The 96 px record button; becomes Stop with a ring while recording (Figma 07, 08).
class _BigButton extends StatelessWidget {
  const _BigButton({required this.recording, required this.enabled, required this.onPressed});
  final bool recording;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: enabled,
      label: recording ? 'Stop recording' : 'Record a clip',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: recording ? MyPetColors.of(context).brandContainer : Colors.transparent,
        ),
        child: Material(
          color: enabled ? MyPetColors.of(context).brandStrong : s.onSurface.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(recording ? Icons.stop_rounded : Icons.videocam_rounded,
                  size: 36, color: enabled ? Colors.white : s.onSurface.withValues(alpha: 0.38)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Result (Figma 09) and the other outcomes A, B and C (design README).
class ResultView extends StatelessWidget {
  const ResultView({
    super.key,
    required this.outcome,
    required this.pet,
    required this.ms,
    required this.onRetake,
    required this.onSave,
  });
  final CheckOutcome outcome;
  final Pet pet;
  final int ms;
  final VoidCallback onRetake;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final o = outcome;
    const gap = SizedBox(height: Tokens.space4);
    final notHeard = o.kind == OutcomeKind.notHeard;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space4),
      children: [
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
                ]),
              ),
              gap,
              MyCard(
                title: 'Other possibilities',
                child: Column(children: [for (final f in o.feelings.skip(1)) _FeelingRow(f)]),
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
                      Text('Closest sound: ${o.topSound}',
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
        if (!notHeard) ...[
          gap,
          MyCard(
            title: 'Sounds heard',
            child: Wrap(spacing: Tokens.space2, runSpacing: Tokens.space2, children: [
              for (final (n, _) in o.sounds.take(3)) _SoundChip(n),
            ]),
          ),
          if (o.kind == OutcomeKind.heardOnly) ...[
            const SizedBox(height: Tokens.space2),
            Text('Feelings are only read from meows.', style: t.textTheme.bodySmall),
          ],
        ],
        gap,
        _Note(icon: Icons.info_outline_rounded, text: Wording.notDiagnosisBehaviour, color: c.surfaceTint),
        gap,
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
                  PictureUse.none => 'From sound · picture check coming soon',
                },
                style: t.textTheme.bodySmall),
          ),
        ]),
        const SizedBox(height: Tokens.space1),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.delete_outline_rounded, size: 16, color: t.colorScheme.onSurfaceVariant),
          const SizedBox(width: Tokens.space1),
          Flexible(
            child: Text('Clip deleted · result took ${(ms / 1000).toStringAsFixed(1)} s',
                style: t.textTheme.bodySmall),
          ),
        ]),
      ],
    );
  }
}

String _pct(double p) => '${(100 * p).round()}%';

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
