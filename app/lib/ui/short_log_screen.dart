import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/care_entry.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import 'app.dart';
import 'feedback.dart';
import 'quick_log_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// The short form the home and lock-screen widgets open (mypet://app/log?pet=ID): one big
/// "All normal" button, or three rows for what was different, then a confirmation with
/// Undo for 10 seconds. No clip, weight or note here; the full log has those.
class ShortLogScreen extends StatefulWidget {
  const ShortLogScreen({super.key, this.petId});

  /// The pet to log. Null picks the first pet not logged today, else the selected pet.
  final String? petId;

  @override
  State<ShortLogScreen> createState() => _ShortLogScreenState();
}

/// Energy on the short form is judged against the pet's own usual, then stored 1 to 5.
int shortEnergy(int usual, String pick) => switch (pick) {
      'low' => (usual - 1).clamp(1, 5),
      'high' => (usual + 1).clamp(1, 5),
      _ => usual,
    };

/// Which pet the short form opens on.
Pet? shortLogPet(AppState s, String? petId) {
  final pets = s.activePets;
  if (pets.isEmpty) return null;
  final asked = pets.where((p) => p.id == petId).firstOrNull;
  if (asked != null) return asked;
  return pets.where((p) => !s.loggedToday(p.id)).firstOrNull ??
      s.selectedPet ??
      pets.first;
}

class _ShortLogScreenState extends State<ShortLogScreen> {
  String? petId;
  String? ate;
  String? energy;
  int? toilet;
  bool saving = false;
  CareEntry? saved;
  Timer? undoTimer;
  int undoLeft = 0;

  @override
  void dispose() {
    undoTimer?.cancel();
    super.dispose();
  }

  bool get complete => ate != null && energy != null && toilet != null;

  Future<void> _save(AppState s, Pet pet, {required bool allNormal}) async {
    if (saving) return;
    setState(() => saving = true);
    final usual = s.usualEnergy(pet.id);
    final a = allNormal ? 'all' : ate!;
    final e = await s.addEntry(pet.id, EntryKind.dailyLog, {
      'ate': a != 'none',
      'ateAmount': a,
      'energy': allNormal ? usual : shortEnergy(usual, energy!),
      'toiletingNormal': allNormal ? true : (toilet == -1 ? null : toilet == 1),
      if (!allNormal && toilet == -1) 'toiletingSeen': false,
      'source': allNormal ? 'shortAllNormal' : 'short',
    });
    Feel.saved();
    if (!mounted) return;
    setState(() {
      saving = false;
      saved = e;
      undoLeft = 10;
    });
    undoTimer?.cancel();
    undoTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => undoLeft--);
      if (undoLeft <= 0) t.cancel();
    });
  }

  Future<void> _undo(AppState s) async {
    final e = saved;
    if (e == null) return;
    undoTimer?.cancel();
    await s.deleteEntry(e);
    if (!mounted) return;
    setState(() {
      saved = null;
      undoLeft = 0;
    });
  }

  void _next(Pet next) {
    undoTimer?.cancel();
    setState(() {
      petId = next.id;
      saved = null;
      undoLeft = 0;
      ate = null;
      energy = null;
      toilet = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context);
    if (!s.carerKnown) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pet = shortLogPet(s, petId ?? widget.petId);
    if (pet == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quick log'),
          leading: BackButton(onPressed: () => leaveToHome(context)),
        ),
        body: EmptyState(
          icon: Icons.pets_rounded,
          title: 'No pets yet',
          body: 'Add a pet first, then log here.',
          action: FilledButton(onPressed: () => leaveToHome(context), child: const Text('Go to MyPet')),
        ),
      );
    }
    petId ??= pet.id;
    // Short form switched off in Settings: links and widgets open the full daily log.
    if (!s.doors.shortForm) return QuickLogScreen(pet: pet);
    final pets = s.activePets;
    final done = pets.where((p) => s.loggedToday(p.id)).length;

    if (saved != null) {
      final next = pets.where((p) => !s.loggedToday(p.id)).firstOrNull;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quick log'),
          leading: BackButton(onPressed: () => leaveToHome(context)),
        ),
        body: PageWash(
          child: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
            HeroCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_rounded, size: 40),
                const SizedBox(height: Tokens.space2),
                Semantics(
                  liveRegion: true,
                  child: Text('${pet.name} is logged',
                      style: t.textTheme.headlineSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: Tokens.space1),
                Text('Today $done of ${pets.length} done', style: t.textTheme.bodyLarge!.copyWith(color: Colors.white)),
              ]),
            ),
            const SizedBox(height: Tokens.space4),
            if (undoLeft > 0)
              OutlinedButton.icon(
                onPressed: () => _undo(s),
                icon: const Icon(Icons.undo_rounded),
                label: Text('Undo ($undoLeft)'),
              ),
            const SizedBox(height: Tokens.space2),
            if (next != null)
              FilledButton(onPressed: () => _next(next), child: Text('Next: ${next.name}'))
            else
              FilledButton(onPressed: () => leaveToHome(context), child: const Text('Done')),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
          title: const Text('Quick log'),
          leading: BackButton(onPressed: () => leaveToHome(context)),
        ),
      body: PageWash(
        child: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
          if (pets.length > 1) ...[
            Wrap(spacing: Tokens.space2, runSpacing: Tokens.space2, children: [
                for (final p in pets)
                  IntrinsicWidth(
                    child: AnswerChip(
                      label: s.loggedToday(p.id) ? '${p.name} · done' : p.name,
                      semantic: 'Log ${p.name}${s.loggedToday(p.id) ? ', logged today' : ''}',
                      selected: p.id == pet.id,
                      onTap: () => setState(() => petId = p.id),
                    ),
                  ),
              ]),
            const SizedBox(height: Tokens.space4),
          ],
          Text("How was ${pet.name}'s day?", style: t.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: Tokens.space4),
          _AllNormalButton(
            name: pet.name,
            onPressed: saving ? null : () => _save(s, pet, allNormal: true),
          ),
          const SizedBox(height: Tokens.space5),
          Text('Or tell us what was different', style: t.textTheme.titleSmall),
          const SizedBox(height: Tokens.space3),
          ChoiceRow<String>(
            label: 'Ate',
            expand: true,
            options: const [('all', 'All'), ('some', 'Some'), ('none', 'None')],
            selected: ate,
            onSelected: (v) => setState(() => ate = v),
          ),
          const SizedBox(height: Tokens.space4),
          ChoiceRow<String>(
            label: 'Energy',
            expand: true,
            options: const [('low', 'Low'), ('usual', 'Usual'), ('high', 'High')],
            selected: energy,
            onSelected: (v) => setState(() => energy = v),
          ),
          const SizedBox(height: Tokens.space4),
          ChoiceRow<int>(
            label: 'Toileting normal',
            expand: true,
            options: const [(1, 'Yes'), (0, 'No'), (-1, "Didn't see")],
            selected: toilet,
            onSelected: (v) => setState(() => toilet = v),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space2),
          child: FilledButton(
            onPressed: complete && !saving ? () => _save(s, pet, allNormal: false) : null,
            child: Text(complete ? 'Save' : 'Answer all three to save'),
          ),
        ),
      ),
    );
  }
}

class _AllNormalButton extends StatelessWidget {
  const _AllNormalButton({required this.name, required this.onPressed});
  final String name;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = MyPetColors.of(context);
    final t = Theme.of(context);
    return Semantics(
      button: true,
      label: 'All normal for $name',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(gradient: c.heroGradient, borderRadius: BorderRadius.circular(Tokens.radiusHero)),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(Tokens.radiusHero),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4, vertical: Tokens.space4),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 32),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('All normal',
                        style: t.textTheme.titleLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    Text('Ate, played, toilet as usual', style: t.textTheme.bodyMedium!.copyWith(color: Colors.white)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
