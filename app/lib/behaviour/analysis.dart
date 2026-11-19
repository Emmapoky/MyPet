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

/// What the picture added to the result.
enum PictureUse {
  /// No picture model on this phone yet (ML step 11), or an audio-only file.
  none,

  /// The picture showed the pet and its feeling was combined with the sound.
  combined,

  /// The picture showed the pet (cats: no picture feeling model, so it only confirms).
  confirmed,

  /// The picture did not clearly show a dog or cat; the sound alone was used.
  notSeen,
}

class CheckOutcome {
  CheckOutcome({
    required this.kind,
    required this.species,
    required this.feelings,
    required this.sounds,
    this.picture = PictureUse.none,
  });
  final OutcomeKind kind;
  final Species species;
  final PictureUse picture;

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
        'picture': picture.name,
      };
}

/// The picture's reading of a clip: which species it saw, and (dogs) feeling likelihoods
/// in the same order as the sound classifier's names.
class PictureReading {
  PictureReading({required this.species, this.feelings});
  final String species;
  final List<double>? feelings;
}

/// Combines the sound's outcome with the picture's reading (ML step 11 rule:
/// p = w * sound + (1 - w) * picture, with w from photo_classifiers.json).
CheckOutcome combine(CheckOutcome sound, PictureReading? pic, {required double soundWeight, required List<String> names}) {
  if (pic == null) return sound;
  final seen = pic.species == sound.species.name;
  CheckOutcome withPicture(OutcomeKind k, List<(String, double)> f, PictureUse u) =>
      CheckOutcome(kind: k, species: sound.species, feelings: f, sounds: sound.sounds, picture: u);
  if (!seen) return withPicture(sound.kind, sound.feelings, PictureUse.notSeen);
  final pf = pic.feelings;
  if (pf == null) return withPicture(sound.kind, sound.feelings, PictureUse.confirmed);
  if (sound.kind == OutcomeKind.heardOnly) return withPicture(sound.kind, sound.feelings, PictureUse.confirmed);
  // Sound feelings by name (or none if the sound did not hold the pet).
  final bySound = {for (final (n, p) in sound.feelings) n: p};
  final w = bySound.isEmpty ? 0.0 : soundWeight;
  final mixed = [
    for (var i = 0; i < names.length; i++) (names[i], w * (bySound[names[i]] ?? 0) + (1 - w) * pf[i]),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  final kind = mixed.first.$2 < Analysis.unsureBelow ? OutcomeKind.notSure : OutcomeKind.feeling;
  return withPicture(kind, mixed, PictureUse.combined);
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
