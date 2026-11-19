// The behaviour check's decision rules, shared by the Try it screen (and later the app).
//
// 1. Sound evidence first (CLAP zero-shot, report 4.2). If the sound does not
//    clearly come from the chosen animal, say so instead of guessing a feeling.
// 2. Cats: the feeling model was trained on meows only (CatMeows), so it only
//    answers when the sound is a meow. Purring or hissing is shown as evidence.
// 3. Picture (step 11, when photo_classifiers.json is in assets): a free CLIP image model
//    checks a dog or cat is in view. For dogs it also reads the feeling, and the two are
//    combined as p = w * sound + (1 - w) * picture, with w from held-out scores.
// 4. If the most likely feeling is below [unsureBelow], say "Not sure" and show
//    all the likelihoods. The cut-off comes from the held-out results (step 10).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'test_library.dart' show Classifier, SoundEvidence, argmax;

class CheckResult {
  CheckResult(this.headline, this.reason, this.feelings, this.sounds, [this.picture]);
  final String headline;
  final String? reason;
  final List<(String, double)> feelings;
  final List<(String, double)> sounds;
  final String? picture;
}

/// The picture half (photo_classifiers.json from tool/build_photo_check.py).
class PhotoCheck {
  PhotoCheck(Map<String, dynamic> j)
      : gate = SoundEvidence(j['gate'] as Map<String, dynamic>),
        dog = Classifier(j['dog_photo'] as Map<String, dynamic>),
        soundWeight = ((j['combine'] as Map)['sound_weight'] as num).toDouble(),
        inputName = j['input_name'] as String? ?? 'pixel_values',
        outputName = j['output'] as String? ?? 'image_embeds',
        mean = (j['mean'] as List).map((v) => (v as num).toDouble()).toList(),
        std = (j['std'] as List).map((v) => (v as num).toDouble()).toList();
  final SoundEvidence gate;
  final Classifier dog;
  final double soundWeight;
  final String inputName, outputName;
  final List<double> mean, std;

  /// 224x224 RGB bytes -> model input [1, 3, 224, 224], channels first.
  Float32List toInput(Uint8List rgb) {
    const n = 224 * 224;
    final out = Float32List(3 * n);
    for (var i = 0; i < n; i++) {
      for (var c = 0; c < 3; c++) {
        out[c * n + i] = (rgb[3 * i + c] / 255.0 - mean[c]) / std[c];
      }
    }
    return out;
  }
}

class Analysis {
  Analysis(this.clf, this.sound, [this.photo]);
  final Map<String, Classifier> clf;
  final SoundEvidence sound;
  final PhotoCheck? photo;

  /// Below this, the top feeling is shown as "Not sure" (set in step 10 from held-out data).
  static const unsureBelow = 0.5;

  static Future<Analysis> load() async {
    const dir = 'assets/test_library';
    final c = jsonDecode(await rootBundle.loadString('$dir/classifiers.json')) as Map<String, dynamic>;
    final s = SoundEvidence(jsonDecode(await rootBundle.loadString('$dir/sound_evidence.json')));
    PhotoCheck? p;
    try {
      p = PhotoCheck(jsonDecode(await rootBundle.loadString('$dir/photo_classifiers.json')));
    } catch (_) {} // picture check not built yet: sound only
    return Analysis(c.map((k, v) => MapEntry(k, Classifier(v))), s, p);
  }

  CheckResult check(List<double> emb, String species, [List<double>? img]) {
    final r = _check(emb, species, img);
    if (img == null || photo == null) return r;
    final seen = photo!.gate.speciesOf(photo!.gate.probs(img));
    final note = seen == species
        ? 'Picture: a $species is in view.'
        : seen == 'other'
            ? 'Picture: could not clearly see a dog or cat.'
            : 'Picture: this looks like a $seen, not a $species.';
    return CheckResult(r.headline, r.reason, r.feelings, r.sounds, note);
  }

  CheckResult _check(List<double> emb, String species, List<double>? img) {
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
    var p = c.probs(emb);
    final ph = photo;
    if (species == 'dog' && img != null && ph != null && ph.gate.speciesOf(ph.gate.probs(img)) == 'dog') {
      final pp = ph.dog.probs(img); // same four labels, same order as dog_report
      p = [for (var i = 0; i < p.length; i++) ph.soundWeight * p[i] + (1 - ph.soundWeight) * pp[i]];
    }
    final k = argmax(p);
    final feelings = [for (final i in (List.generate(p.length, (i) => i)..sort((a, b) => p[b].compareTo(p[a])))) (c.names[i], p[i])];
    if (p[k] < unsureBelow) {
      return CheckResult('Not sure', 'No feeling stands out. The likelihoods are below.', feelings, sounds);
    }
    return CheckResult('${c.names[k]} (${(100 * p[k]).round()}%)', null, feelings, sounds);
  }
}
