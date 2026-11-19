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

  /// Length of a recording (report Table 4.1).
  static const seconds = 10;

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
  final List<double> _levels = [];
  StreamSubscription<double>? _levelSub;
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
    _levelSub?.cancel();
    super.dispose();
  }

  // Load the model the first time the tab opens, not at app start and not after recording.
  void _loadOnce() {
    if (_loadStarted) return;
    _loadStarted = true;
    _engine.load().then((_) {
      if (mounted) setState(() => _ready = true);
    }, onError: (Object e) {
      if (mounted) setState(() => _problem = e is CheckProblem ? e.message : 'The model could not load.');
    });
  }

  Future<void> _record(Pet pet) async {
    if (!await _engine.micAllowed()) {
      _say('Microphone access is off. Turn it on in Settings, then try again.');
      return;
    }
    await _engine.startRecording();
    setState(() {
      _step = _Step.recording;
      _left = CheckScreen.seconds;
      _levels.clear();
    });
    _levelSub = _engine.level.listen((v) {
      if (!mounted) return;
      setState(() {
        _levels.add(v);
        if (_levels.length > _Wave.bars) _levels.removeAt(0);
      });
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
    unawaited(_levelSub?.cancel());
    _levelSub = null;
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
      _levels.clear();
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
        title: Text(onResult ? 'Result' : 'Behaviour check'),
        actions: const [MoreMenu()],
      ),
      body: SafeArea(child: _body(context, s, pet)),
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
      pet: pet,
      step: _step,
      ready: _ready,
      left: _left,
      levels: _levels,
      canSwitch: s.activePets.length > 1,
      onRecord: () => _record(pet),
      onStop: () => _stop(pet),
      onPick: () => _pick(pet),
    );
  }
}

String _speciesWord(Species s) => s == Species.cat ? 'cat' : 'dog';

class _RecordView extends StatelessWidget {
  const _RecordView({
    required this.pet,
    required this.step,
    required this.ready,
    required this.left,
    required this.levels,
    required this.canSwitch,
    required this.onRecord,
    required this.onStop,
    required this.onPick,
  });
  final Pet pet;
  final _Step step;
  final bool ready;
  final int left;
  final List<double> levels;
  final bool canSwitch;
  final VoidCallback onRecord, onStop, onPick;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final recording = step == _Step.recording;
    final checking = step == _Step.checking;
    final sounds = pet.species == Species.cat ? 'meowing' : 'barking, whining or growling';
    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space4),
      children: [
        Material(
          color: c.surfaceTint,
          borderRadius: BorderRadius.circular(Tokens.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.pets_rounded, size: 20, color: t.colorScheme.onPrimaryContainer),
                    const SizedBox(width: Tokens.space2),
                    Text('${pet.name} · ${_speciesWord(pet.species)}',
                        style: t.textTheme.titleSmall!.copyWith(color: t.colorScheme.onPrimaryContainer)),
                  ]),
                  const SizedBox(height: Tokens.space2),
                  Text(
                    recording
                        ? 'Keep the phone near ${pet.name}.'
                        : 'Record about ${CheckScreen.seconds} seconds of ${pet.name} $sounds.',
                    style: t.textTheme.bodyLarge,
                  ),
                ]),
              ),
              if (canSwitch && step == _Step.record)
                IconButton(
                  tooltip: 'Switch pet',
                  onPressed: () => showPetSwitcher(context),
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
            ]),
          ),
        ),
        const SizedBox(height: Tokens.space6),
        _Wave(levels: recording ? levels : const [], live: recording),
        const SizedBox(height: Tokens.space4),
        Semantics(
          liveRegion: recording,
          child: Text(
            recording ? '$left s left' : checking ? 'Checking' : '${CheckScreen.seconds} s',
            textAlign: TextAlign.center,
            style: t.textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: Tokens.space5),
        Center(
          child: checking
              ? const SizedBox(width: 96, height: 96, child: Padding(
                  padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              : _BigButton(
                  recording: recording,
                  enabled: ready || recording,
                  onPressed: recording ? onStop : onRecord,
                ),
        ),
        const SizedBox(height: Tokens.space2),
        Text(
          recording ? 'Stop' : (ready ? 'Record' : 'Getting ready'),
          textAlign: TextAlign.center,
          style: t.textTheme.labelLarge,
        ),
        const SizedBox(height: Tokens.space6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lock_outline_rounded, size: 20, color: t.colorScheme.onSurfaceVariant),
          const SizedBox(width: Tokens.space2),
          Expanded(
            child: Text('Only records when you tap. The clip is checked on this phone and then deleted.',
                style: t.textTheme.bodySmall),
          ),
        ]),
        const SizedBox(height: Tokens.space4),
        OutlinedButton.icon(
          onPressed: ready && step == _Step.record ? onPick : null,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Choose a video or audio file'),
        ),
      ],
    );
  }
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
      label: recording ? 'Stop recording' : 'Record ${CheckScreen.seconds} seconds',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: recording ? s.primaryContainer : Colors.transparent,
        ),
        child: Material(
          color: enabled ? s.primary : s.onSurface.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              width: 96,
              height: 96,
              child: Icon(recording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 44, color: enabled ? s.onPrimary : s.onSurface.withValues(alpha: 0.38)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dot waveform: flat in outlineVariant before recording, live in primary while recording.
class _Wave extends StatelessWidget {
  const _Wave({required this.levels, required this.live});
  static const bars = 32;
  final List<double> levels;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final pad = List<double>.filled(bars - levels.length, 0) + levels;
    return ExcludeSemantics(
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final v in pad)
              Container(
                width: 4,
                height: 4 + 56 * v,
                decoration: BoxDecoration(
                  color: live ? s.primary : s.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
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
