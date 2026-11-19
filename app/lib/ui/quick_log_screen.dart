import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/care_entry.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Quick log (report Table 4.4 screen 3; Figma screen 03): same as last entry, three
/// numbered questions, optional weight and voice note, Save. A routine day takes 2 taps
/// from Today, Log now then Save (NFR01: 3 taps or fewer).
class QuickLogScreen extends StatefulWidget {
  const QuickLogScreen({super.key, required this.pet, this.editing});
  final Pet pet;
  final CareEntry? editing;

  @override
  State<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickLogScreenState extends State<QuickLogScreen> {
  bool? ate;
  int? energy;
  bool? toilet;
  bool sameAsLast = false;
  CareEntry? last;
  final weight = TextEditingController();
  final note = TextEditingController();
  bool saving = false;
  String? error;

  final _speech = SpeechToText();
  bool _listening = false;
  String _noteBeforeVoice = '';

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    if (widget.editing != null) {
      _fill(widget.editing!, withExtras: true);
    } else {
      last = s.timelineOf(widget.pet.id).lastDailyLog;
      if (last != null) {
        sameAsLast = true;
        _fill(last!, withExtras: false);
      }
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  void _fill(CareEntry e, {required bool withExtras}) {
    ate = e.ate;
    energy = e.energy;
    toilet = e.toiletingNormal;
    if (withExtras) {
      weight.text = e.weightKg?.toString() ?? '';
      note.text = e.note;
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
        if (last != null &&
            (ate != last!.ate || energy != last!.energy || toilet != last!.toiletingNormal)) {
          sameAsLast = false;
        }
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
    final ok = await _speech.initialize(onStatus: (st) {
      if (st == 'done' || st == 'notListening') {
        if (mounted) setState(() => _listening = false);
      }
    });
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Voice notes need microphone and speech permission in Settings.')));
      return;
    }
    _noteBeforeVoice = note.text.trim();
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        final spoken = r.recognizedWords;
        note.text = [_noteBeforeVoice, spoken].where((x) => x.isNotEmpty).join(' ');
        note.selection = TextSelection.collapsed(offset: note.text.length);
      },
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
      'ate': ate,
      'energy': energy,
      'toiletingNormal': toilet,
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
      await s.addEntry(widget.pet.id, EntryKind.dailyLog, data);
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
        title: Text(widget.editing == null ? 'Log for ${pet.name}' : 'Edit log'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space4),
          children: [
            if (last != null) ...[
              Material(
                color: c.surfaceTint,
                borderRadius: BorderRadius.circular(Tokens.radiusInput),
                child: MergeSemantics(
                  child: SwitchListTile(
                    secondary: Icon(Icons.history_rounded, color: t.colorScheme.onPrimaryContainer),
                    title: Text('Same as last entry',
                        style: t.textTheme.titleSmall!.copyWith(color: t.colorScheme.onPrimaryContainer)),
                    value: sameAsLast,
                    onChanged: _toggleSame,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusInput)),
                  ),
                ),
              ),
              const SizedBox(height: Tokens.space4),
            ],
            ChoiceRow<bool>(
              number: 1,
              label: 'Ate today',
              expand: true,
              options: const [(true, 'Yes'), (false, 'No')],
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
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('very low', style: t.textTheme.bodySmall),
                Text('high', style: t.textTheme.bodySmall),
              ]),
            ),
            const SizedBox(height: Tokens.space3),
            ChoiceRow<bool>(
              number: 3,
              label: 'Toileting normal',
              expand: true,
              options: const [(true, 'Yes'), (false, 'No')],
              selected: toilet,
              onSelected: (v) => _pick(() => toilet = v),
            ),
            const SizedBox(height: Tokens.space4),
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              decoration: BoxDecoration(
                color: t.colorScheme.surface,
                border: Border.all(color: t.colorScheme.outline),
                borderRadius: BorderRadius.circular(Tokens.radiusInput),
              ),
              child: Row(children: [
                Text('Weight (optional)',
                    style: t.textTheme.bodyLarge!.copyWith(color: t.colorScheme.onSurfaceVariant)),
                Expanded(
                  child: TextField(
                    controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.end,
                    style: t.textTheme.titleSmall,
                    decoration: const InputDecoration.collapsed(hintText: '—', filled: false)
                        .copyWith(semanticCounterText: 'Weight in kilograms, optional'),
                  ),
                ),
                const SizedBox(width: Tokens.space1),
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
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(Tokens.space1),
                  child: IconButton.filledTonal(
                    tooltip: _listening ? 'Stop voice note' : 'Speak a note',
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FilledButton(
              onPressed: complete && !saving ? _save : null,
              child: Text(complete ? 'Save' : 'Answer 1, 2 and 3 to save'),
            ),
          ]),
        ),
      ),
    );
  }
}
