import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../logging/spoken_log.dart';

import '../models/care_entry.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import '../util/day.dart';
import 'feedback.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/guide_target.dart';
import 'widgets/pet_bar.dart';

/// Quick log (report Table 4.4 screen 3; Figma screen 03): same as last entry, three
/// numbered questions, optional weight and voice note, Save. A routine day takes 3 taps
/// from Today: Log now, energy, Save (NFR01: 3 taps or fewer).
class QuickLogScreen extends StatefulWidget {
  const QuickLogScreen({super.key, required this.pet, this.editing, this.day, this.heard, this.script});
  final Pet pet;
  final CareEntry? editing;

  /// A past day to fill in (tapped from a "Missed" row). Null means today.
  final Day? day;

  /// Answers already heard for this pet, when one voice log named several pets.
  final SpokenLog? heard;

  /// Demo only: a recorded voice note played as if spoken now, with its words timed, so
  /// the log fills in exactly as it would from the phone's speech recogniser.
  final VoiceScript? script;

  @override
  State<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickLogScreenState extends State<QuickLogScreen> {
  /// "all", "some" or "none" (review change 3: one tap, scored as a share).
  String? ate;
  int? energy;

  /// 1 normal, 0 not normal, -1 did not see (review change 8).
  int? toilet;

  /// Extra checks this pet has switched on, by daily log key. Null is not answered.
  final Map<String, bool?> checks = {};
  bool sameAsLast = false;
  CareEntry? last;
  final weight = TextEditingController();
  final note = TextEditingController();
  bool saving = false;
  String? error;

  /// The pet's usual energy, once it has some logs (energy words are relative to the pet).
  int? usualEnergy;

  static String _checkOf(String key) => PetChecks.all.firstWhere((c) => PetChecks.key(c) == key);

  final _speech = SpeechToText();
  bool _listening = false;
  String _noteBeforeVoice = '';

  /// What the voice log understood, per pet name (this pet and any others named).
  Map<String, SpokenLog> _heard = {};

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    if (s.timelineOf(widget.pet.id).ofKind(EntryKind.dailyLog).any((e) => e.energy != null)) {
      usualEnergy = s.usualEnergy(widget.pet.id);
    }
    for (final c in widget.pet.checks) {
      checks[PetChecks.key(c)] = null;
    }
    if (widget.editing != null) {
      _fill(widget.editing!, withExtras: true);
    } else {
      last = s.timelineOf(widget.pet.id).lastDailyLog;
      if (last != null) {
        sameAsLast = true;
        _fill(last!, withExtras: false);
      }
      if (widget.script != null) {
        // Start empty, so the demo shows every answer being filled in by voice.
        sameAsLast = false;
        ate = null;
        energy = null;
        toilet = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _playScript(widget.script!));
      }
      final h = widget.heard;
      if (h != null) {
        _heard = {widget.pet.name: h};
        _apply(h);
      }
    }
  }

  /// Fills in whatever the voice log understood; anything not said stays as it was.
  void _apply(SpokenLog h) {
    if (h.ateAmount != null) ate = h.ateAmount;
    if (h.energy != null) energy = h.energy;
    if (h.toiletingNormal != null) toilet = h.toiletingNormal! ? 1 : 0;
    for (final c in h.checks.entries) {
      if (checks.containsKey(c.key)) checks[c.key] = c.value;
    }
    if (h.weightKg != null) weight.text = h.weightKg!.toString();
    if (h.text.isNotEmpty) note.text = [_noteBeforeVoice, h.text].where((x) => x.isNotEmpty).join(' ');
    if (last != null && _differsFromLast) sameAsLast = false;
  }

  static int? _toiletOf(CareEntry e) =>
      e.toiletingNormal == null ? (e.toiletingUnseen ? -1 : null) : (e.toiletingNormal! ? 1 : 0);

  bool get _differsFromLast => ate != last!.ateAmount || toilet != _toiletOf(last!);

  AudioPlayer? _scriptPlayer;
  Timer? _scriptTimer;

  Future<void> _playScript(VoiceScript v) async {
    final s = context.read<AppState>();
    final names = s.activePets.map((p) => p.name).toList();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    s.setGuideCollapsed(true);
    setState(() => _listening = true);
    final player = _scriptPlayer = AudioPlayer();
    try {
      await player.play(AssetSource(v.audio));
    } catch (_) {}
    final sw = Stopwatch()..start();
    _scriptTimer = Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (!mounted) return t.cancel();
      final now = sw.elapsedMilliseconds / 1000;
      final heard = v.heardAt(now);
      setState(() {
        _heard = readSpokenLogs(heard, names, fallback: widget.pet.name);
        final mine = _heard[widget.pet.name];
        if (mine != null) _apply(mine);
      });
      if (now >= v.seconds) {
        t.cancel();
        setState(() => _listening = false);
        s.setGuideCollapsed(false);
      }
    });
  }

  @override
  void dispose() {
    _scriptTimer?.cancel();
    _scriptPlayer?.dispose();
    _speech.cancel();
    super.dispose();
  }

  void _fill(CareEntry e, {required bool withExtras}) {
    ate = e.ateAmount;
    // Energy is the change MyPet watches most, so a new log asks for it fresh.
    energy = withExtras ? e.energy : null;
    toilet = _toiletOf(e);
    if (withExtras) {
      weight.text = e.weightKg?.toString() ?? '';
      note.text = e.note;
      for (final k in checks.keys) {
        checks[k] = e.data[k] as bool?;
      }
    }
  }

  void _toggleSame(bool on) => setState(() {
    sameAsLast = on;
    if (on && last != null) {
      _fill(last!, withExtras: false);
    } else if (!on) {
      ate = null;
      energy = null;
      toilet = null;
    }
  });

  void _pick(VoidCallback f) => setState(() {
    f();
    if (last != null && _differsFromLast) sameAsLast = false;
  });

  bool get complete => ate != null && energy != null && toilet != null;

  /// Voice note (FR18) with the phone's own speech recogniser; on-device where the phone
  /// supports it. Free, no account.
  Future<void> _voice() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final names = context.read<AppState>().activePets.map((p) => p.name).toList();
    final ok = await _speech.initialize(
      onStatus: (st) {
        if (st == 'done' || st == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Voice notes need microphone and speech permission in Settings.')),
      );
      return;
    }
    _noteBeforeVoice = note.text.trim();
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) => setState(() {
        // "Mao ate well but was tired. Woof skipped dinner": fills Mao's answers now and
        // keeps Woof's for the next log.
        _heard = readSpokenLogs(r.recognizedWords, names, fallback: widget.pet.name);
        final mine = _heard[widget.pet.name];
        if (mine != null) {
          _apply(mine);
        } else {
          note.text = [_noteBeforeVoice, r.recognizedWords].where((x) => x.isNotEmpty).join(' ');
        }
        note.selection = TextSelection.collapsed(offset: note.text.length);
      }),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        onDevice: false,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        cancelOnError: true,
      ),
    );
  }

  Future<void> _save() async {
    final raw = weight.text.trim().replaceAll(',', '.').replaceAll('kg', '').trim();
    final w = raw.isEmpty ? null : double.tryParse(raw);
    if (raw.isNotEmpty && w == null) {
      setState(() => error = 'Weight must be a number, like 4.2');
      return;
    }
    final data = <String, dynamic>{
      'ate': ate != 'none',
      'ateAmount': ate,
      'energy': energy,
      'toiletingNormal': toilet == -1 ? null : toilet == 1,
      if (toilet == -1) 'toiletingSeen': false,
      for (final c in checks.entries)
        if (c.value != null) c.key: c.value,
      'weightKg': ?w,
      if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
    };
    final problem = LogRanges.checkDailyLog(data);
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() => saving = true);
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    if (_listening) await _speech.stop();
    if (widget.editing != null) {
      await s.editEntry(widget.editing!, data);
    } else {
      await s.addEntry(widget.pet.id, EntryKind.dailyLog, data, day: widget.day);
    }
    Feel.saved();
    // Several pets: go straight to the next one not logged today, so a household
    // logs everyone in a row (Save, Save, Save) instead of going back each time.
    final next = widget.editing == null && widget.day == null
        ? s.activePets.where((p) => p.id != widget.pet.id && !s.loggedToday(p.id)).firstOrNull
        : null;
    if (next != null) {
      s.selectPet(next.id);
      nav.pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuickLogScreen(pet: next, heard: _heard[next.name]),
        ),
      );
      return;
    }
    s.goToTab(0);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final pet = widget.pet;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            PetAvatar(pet: pet, size: 36),
            const SizedBox(width: Tokens.space3),
            Flexible(child: Text(widget.editing == null ? pet.name : 'Edit log', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          if (widget.day != null)
            Padding(
              padding: const EdgeInsets.only(right: Tokens.space4),
              child: Chip(
                avatar: const Icon(Icons.event_rounded, size: 18),
                label: Text(DateFormat('EEE d MMM').format(widget.day!.asDateTime)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space4),
          children: [
            _VoiceCard(petName: pet.name, listening: _listening, heard: _heard, onTap: _voice),
            const SizedBox(height: Tokens.space4),
            if (last != null) ...[
              Material(
                color: c.surfaceTint,
                borderRadius: BorderRadius.circular(Tokens.radiusInput),
                child: MergeSemantics(
                  child: SwitchListTile(
                    secondary: Icon(Icons.history_rounded, color: t.colorScheme.onPrimaryContainer),
                    title: Text(
                      'Same as last entry',
                      style: t.textTheme.titleSmall!.copyWith(color: t.colorScheme.onPrimaryContainer),
                    ),
                    value: sameAsLast,
                    onChanged: _toggleSame,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusInput)),
                  ),
                ),
              ),
              const SizedBox(height: Tokens.space4),
            ],
            ChoiceRow<String>(
              number: 1,
              label: 'Ate today',
              expand: true,
              options: const [('all', 'All'), ('some', 'Some'), ('none', 'None')],
              selected: ate,
              onSelected: (v) => _pick(() => ate = v),
            ),
            const SizedBox(height: Tokens.space4),
            ChoiceRow<int>(
              number: 2,
              label: 'Energy',
              expand: true,
              options: const [(1, '1'), (2, '2'), (3, '3'), (4, '4'), (5, '5')],
              selected: energy,
              onSelected: (v) => _pick(() => energy = v),
            ),
            Padding(
              padding: const EdgeInsets.only(top: Tokens.space1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('very low', style: t.textTheme.bodySmall),
                  if (usualEnergy != null)
                    Flexible(
                      child: Text(
                        'Usual for ${pet.name}: $usualEnergy',
                        textAlign: TextAlign.center,
                        style: t.textTheme.bodySmall,
                      ),
                    ),
                  Text('high', style: t.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: Tokens.space3),
            ChoiceRow<int>(
              number: 3,
              label: 'Toileting normal',
              expand: true,
              options: const [(1, 'Yes'), (0, 'No'), (-1, "Didn't see")],
              selected: toilet,
              onSelected: (v) => _pick(() => toilet = v),
            ),
            for (final k in checks.keys) ...[
              const SizedBox(height: Tokens.space4),
              ChoiceRow<bool>(
                label: PetChecks.question(_checkOf(k)),
                expand: true,
                options: const [(false, 'No'), (true, 'Yes')],
                selected: checks[k],
                onSelected: (v) => _pick(() => checks[k] = checks[k] == v ? null : v),
              ),
            ],
            const SizedBox(height: Tokens.space4),
            // One field, one border: label on the left, the number, then "kg" at the same
            // right inset as the mic circle below (Tokens.fieldEdge), never touching.
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.only(left: Tokens.fieldEdge, right: Tokens.fieldTrail),
              decoration: BoxDecoration(
                color: t.colorScheme.surface,
                border: Border.all(color: t.colorScheme.outline),
                borderRadius: BorderRadius.circular(Tokens.radiusInput),
              ),
              child: Row(children: [
                // Not Flexible: a Flexible next to an Expanded keeps half the row and leaves a
                // gap before "kg". Capped instead, so big text still fits.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.5),
                  child: Text('Weight (optional)',
                      style: t.textTheme.bodyLarge!.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: TextField(
                    controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.end,
                    style: t.textTheme.titleSmall,
                    // No box of its own: the row above is the field's only border.
                    decoration: const InputDecoration(
                      hintText: '—',
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: Tokens.space4),
                      semanticCounterText: 'Weight in kilograms, optional',
                    ),
                  ),
                ),
                const SizedBox(width: Tokens.space2),
                // Ends at the same inset as the mic circle in the note field below.
                Text('kg', style: t.textTheme.titleSmall),
              ]),
            ),
            const SizedBox(height: Tokens.space4),
            TextField(
              controller: note,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _listening ? 'Listening…' : 'Add a note (optional)',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Tokens.radiusInput),
                  borderSide: BorderSide(color: t.colorScheme.outline),
                ),
                contentPadding: const EdgeInsets.fromLTRB(Tokens.fieldEdge, Tokens.space4, Tokens.space2, Tokens.space4),
                suffixIcon: Padding(
                  padding: const EdgeInsets.fromLTRB(Tokens.space1, 6, Tokens.fieldTrail, 6),
                  child: IconButton.filledTonal(
                    tooltip: _listening ? 'Stop listening' : 'Tell us about ${pet.name}\'s day',
                    isSelected: _listening,
                    style: IconButton.styleFrom(
                      backgroundColor: t.colorScheme.primaryContainer,
                      foregroundColor: t.colorScheme.onPrimaryContainer,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_none_rounded),
                    onPressed: _voice,
                  ),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: Tokens.space3),
              Text(error!, style: TextStyle(color: t.colorScheme.error)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GuideTarget(
                id: 'save',
                child: FilledButton(
                  onPressed: complete && !saving ? _save : null,
                  child: Text(complete ? 'Save' : 'Answer 1, 2 and 3 to save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Tell us about Mao's day": speak instead of tapping. Shows what was understood, so the
/// person can check it before saving.
class _VoiceCard extends StatelessWidget {
  const _VoiceCard({required this.petName, required this.listening, required this.heard, required this.onTap});
  final String petName;
  final bool listening;
  final Map<String, SpokenLog> heard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final understood = [
      for (final e in heard.entries)
        if (!e.value.isEmpty) heard.length == 1 ? e.value.summary : '${e.key}: ${e.value.summary}',
    ];
    return Semantics(
      button: true,
      liveRegion: true,
      label: listening
          ? 'Listening. Tap to stop.'
          : understood.isEmpty
          ? "Tell us about $petName's day by voice"
          : 'Understood: ${understood.join('. ')}. Tap to speak again.',
      excludeSemantics: true,
      child: Material(
        color: listening ? c.brand : c.brandContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(Tokens.radiusCard),
          onTap: () {
            Feel.tap();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: listening ? Colors.white : c.brand,
                  child: Icon(
                    listening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: listening ? c.brand : MyPetColors.onAccent(c.brand),
                  ),
                ),
                const SizedBox(width: Tokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listening ? 'Listening…' : "Tell us about $petName's day",
                        style: t.textTheme.titleSmall!.copyWith(
                          color: listening ? MyPetColors.onAccent(c.brand) : t.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        understood.isEmpty
                            ? 'For example: "ate well, a bit tired, normal poo"'
                            : 'Understood: ${understood.join('\n')}',
                        style: t.textTheme.bodySmall!.copyWith(
                          color: listening ? MyPetColors.onAccent(c.brand) : t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A recorded voice note and when each sentence is said (assets/demo_voice).
class VoiceScript {
  VoiceScript(this.audio, this.seconds, this.segments);

  /// Asset path under assets/, for AssetSource.
  final String audio;
  final double seconds;
  final List<(double, double, String)> segments;

  static Future<VoiceScript> load(String name) async {
    final j = jsonDecode(await rootBundle.loadString('assets/demo_voice/$name.json')) as Map<String, dynamic>;
    return VoiceScript('demo_voice/$name.m4a', (j['seconds'] as num).toDouble(), [
      for (final s in j['segments'] as List)
        ((s['start'] as num).toDouble(), (s['end'] as num).toDouble(), s['text'] as String),
    ]);
  }

  /// The words heard by [t] seconds, revealed word by word through each sentence, the
  /// way a phone's live transcription shows them.
  String heardAt(double t) {
    final out = <String>[];
    for (final (a, b, text) in segments) {
      if (t < a) break;
      final words = text.split(' ');
      final n = t >= b ? words.length : (words.length * (t - a) / (b - a)).ceil().clamp(0, words.length);
      out.add(words.take(n).join(' '));
    }
    return out.join(' ');
  }
}
