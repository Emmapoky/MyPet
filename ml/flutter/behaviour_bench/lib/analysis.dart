// The behaviour check's decision rules, shared by the Try it screen (and later the app).
//
// 1. Sound evidence first (CLAP zero-shot, report 4.2). If the sound does not
//    clearly come from the chosen animal, say so instead of guessing a feeling.
// 2. Cats: the feeling model was trained on meows only (CatMeows), so it only
//    answers when the sound is a meow. Purring or hissing is shown as evidence.
// 3. If the most likely feeling is below [unsureBelow], say "Not sure" and show
//    all the likelihoods. The cut-off comes from the held-out results (step 10).
import 'dart:convert';

import 'package:flutter/services.dart';

import 'test_library.dart' show Classifier, SoundEvidence, argmax;

class CheckResult {
  CheckResult(this.headline, this.reason, this.feelings, this.sounds);
  final String headline;
  final String? reason;
  final List<(String, double)> feelings;
  final List<(String, double)> sounds;
}

class Analysis {
  Analysis(this.clf, this.sound);
  final Map<String, Classifier> clf;
  final SoundEvidence sound;

  /// Below this, the top feeling is shown as "Not sure" (set in step 10 from held-out data).
  static const unsureBelow = 0.5;

  static Future<Analysis> load() async {
    const dir = 'assets/test_library';
    final c = jsonDecode(await rootBundle.loadString('$dir/classifiers.json')) as Map<String, dynamic>;
    final s = SoundEvidence(jsonDecode(await rootBundle.loadString('$dir/sound_evidence.json')));
    return Analysis(c.map((k, v) => MapEntry(k, Classifier(v))), s);
  }

  CheckResult check(List<double> emb, String species) {
    final ps = sound.probs(emb);
    final order = List.generate(ps.length, (i) => i)..sort((a, b) => ps[b].compareTo(ps[a]));
    final sounds = [for (final i in order) (sound.names[i], ps[i])];
    final animal = species == 'cat' ? 'cat' : 'dog';
    if (sound.speciesOf(ps) != species) {
      return CheckResult('Did not clearly hear a $animal',
          'The sound is closest to "${sound.names[order.first]}". Try again closer to your $animal, '
          'in a quieter spot.', const [], sounds);
    }
    final top = sound.keys[order.first];
    if (species == 'cat' && top != 'cat_meow') {
      return CheckResult('Heard: ${sound.names[order.first]}',
          'The feeling check is trained on meows, so it only answers for meows. '
          'The sound itself is shown as evidence.', const [], sounds);
    }
    final c = clf[species == 'cat' ? 'cat_context' : 'dog_report']!;
    final p = c.probs(emb);
    final k = argmax(p);
    final feelings = [for (final i in (List.generate(p.length, (i) => i)..sort((a, b) => p[b].compareTo(p[a])))) (c.names[i], p[i])];
    if (p[k] < unsureBelow) {
      return CheckResult('Not sure', 'No feeling stands out. The likelihoods are below.', feelings, sounds);
    }
    return CheckResult('${c.names[k]} (${(100 * p[k]).round()}%)', null, feelings, sounds);
  }
}
