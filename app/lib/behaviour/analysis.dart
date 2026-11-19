// The behaviour check's decision rules. Kept in step with
// ml/flutter/behaviour_bench/lib/analysis.dart (ML step 10).
//
// 1. Sound evidence first (CLAP zero-shot, report 4.2). If the sound does not
//    clearly come from the pet's species, say so instead of guessing a feeling.
// 2. Cats: the feeling model was trained on meows only (CatMeows), so it only
//    answers when the top sound is a meow. Purring or hissing is shown as evidence.
// 3. If the most likely feeling is below [Analysis.unsureBelow], say "Not sure"
//    and show every likelihood.
import '../models/pet.dart';
import 'model.dart';

enum OutcomeKind {
  /// A feeling stands out (screen 09).
  feeling,

  /// The sound is not clearly the pet's species (outcome A). Nothing is saved.
  notHeard,

  /// A cat sound that is not a meow, such as purring (outcome B).
  heardOnly,

  /// No feeling reaches the cut-off (outcome C).
  notSure,
}

class CheckOutcome {
  CheckOutcome({required this.kind, required this.species, required this.feelings, required this.sounds});
  final OutcomeKind kind;
  final Species species;

  /// Feeling names (report Table 4.2) and likelihoods, high to low. Empty for A and B.
  final List<(String, double)> feelings;

  /// Sound names and likelihoods, high to low.
  final List<(String, double)> sounds;

  String get topSound => sounds.first.$1;

  /// What a saved entry holds. The clip itself is never stored (FR-N02).
  Map<String, dynamic> toEntryData({required int ms, required String source}) => {
        'species': species.name,
        if (kind == OutcomeKind.heardOnly) 'heard': topSound,
        if (feelings.isNotEmpty) 'topLabel': feelings.first.$1,
        if (feelings.isNotEmpty) 'likelihoods': {for (final (n, p) in feelings) n: p},
        'unsure': kind == OutcomeKind.notSure,
        'soundEvidence': [for (final (n, _) in sounds.take(3)) n],
        'ms': ms,
        'source': source,
      };
}

class Analysis {
  Analysis({required this.classifiers, required this.sound});
  final Map<String, Classifier> classifiers;
  final SoundEvidence sound;

  /// Below this the top feeling is shown as "Not sure" (ML step 10, held-out results).
  static const unsureBelow = 0.5;

  /// [emb] is the CLAP audio embedding scaled to length 1.
  CheckOutcome check(List<double> emb, Species species) {
    final ps = sound.probs(emb);
    final order = List.generate(ps.length, (i) => i)..sort((a, b) => ps[b].compareTo(ps[a]));
    final sounds = [for (final i in order) (sound.names[i], ps[i])];
    if (sound.speciesOf(ps) != species.name) {
      return CheckOutcome(kind: OutcomeKind.notHeard, species: species, feelings: const [], sounds: sounds);
    }
    if (species == Species.cat && sound.keys[order.first] != 'cat_meow') {
      return CheckOutcome(kind: OutcomeKind.heardOnly, species: species, feelings: const [], sounds: sounds);
    }
    final c = classifiers[species == Species.cat ? 'cat_context' : 'dog_report']!;
    final p = c.probs(emb);
    final idx = List.generate(p.length, (i) => i)..sort((a, b) => p[b].compareTo(p[a]));
    final feelings = [for (final i in idx) (c.names[i], p[i])];
    return CheckOutcome(
      kind: p[idx.first] < unsureBelow ? OutcomeKind.notSure : OutcomeKind.feeling,
      species: species,
      feelings: feelings,
      sounds: sounds,
    );
  }
}
