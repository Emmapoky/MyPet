import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/care_entry.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Quick log (report Table 4.4 screen 3): same as last entry, three taps, optional note, save.
/// A routine day takes 2 taps from Today: Log now, then Save (NFR01: 3 taps or fewer).
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

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    final source = widget.editing ?? s.timelineOf(widget.pet.id).lastDailyLog;
    if (widget.editing == null) last = source;
    if (source != null) {
      sameAsLast = widget.editing == null;
      _fill(source, withExtras: widget.editing != null);
    }
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

  bool get complete => ate != null && energy != null && toilet != null;

  Future<void> _save() async {
    final w = weight.text.trim().isEmpty
        ? null
        : double.tryParse(weight.text.trim().replaceAll(',', '.'));
    if (weight.text.trim().isNotEmpty && w == null) {
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
    final messenger = ScaffoldMessenger.of(context);
    if (widget.editing != null) {
      await s.editEntry(widget.editing!, data);
    } else {
      await s.addEntry(widget.pet.id, EntryKind.dailyLog, data);
    }
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text('Logged for ${widget.pet.name}')));
  }

  void _pick(VoidCallback f) => setState(() {
        f();
        if (last != null &&
            (ate != last!.ate || energy != last!.energy || toilet != last!.toiletingNormal)) {
          sameAsLast = false;
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final pet = widget.pet;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing == null ? 'Log ${pet.name}' : 'Edit log'),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
          if (last != null)
            Card(
              child: SwitchListTile(
                title: const Text('Same as last entry'),
                subtitle: const Text('Fills in the last answers. Turn off to start blank.'),
                value: sameAsLast,
                onChanged: _toggleSame,
              ),
            ),
          const SizedBox(height: Tokens.space4),
          ChoiceRow<bool>(
            number: 1,
            label: 'Ate today?',
            options: const [(true, 'Yes'), (false, 'No')],
            selected: ate,
            onSelected: (v) => _pick(() => ate = v),
          ),
          const SizedBox(height: Tokens.space5),
          ChoiceRow<int>(
            number: 2,
            label: 'Energy (1 very low, 5 high)',
            options: const [(1, '1'), (2, '2'), (3, '3'), (4, '4'), (5, '5')],
            selected: energy,
            onSelected: (v) => _pick(() => energy = v),
          ),
          const SizedBox(height: Tokens.space5),
          ChoiceRow<bool>(
            number: 3,
            label: 'Toileting normal?',
            options: const [(true, 'Yes'), (false, 'No')],
            selected: toilet,
            onSelected: (v) => _pick(() => toilet = v),
          ),
          const SizedBox(height: Tokens.space5),
          TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Weight in kg (optional)',
            ),
          ),
          const SizedBox(height: Tokens.space3),
          TextField(
            controller: note,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              helperText: 'Use the microphone on your keyboard to speak a note',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: Tokens.space3),
            Text(error!, style: TextStyle(color: t.colorScheme.error)),
          ],
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: FilledButton(
            onPressed: complete && !saving ? _save : null,
            child: Text(complete ? 'Save' : 'Answer 1, 2 and 3 to save'),
          ),
        ),
      ),
    );
  }
}
