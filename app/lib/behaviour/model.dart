// The behaviour check's small models, kept in step with
// ml/flutter/behaviour_bench/lib/test_library.dart (where they were tested on
// held-out clips and matched Python). Pure Dart, so they run in unit tests.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clap_features/clap_features.dart' show nSamples, sampleRate;

List<double> _softmax(List<double> z) {
  final m = z.reduce(math.max);
  final e = z.map((v) => math.exp(v - m)).toList();
  final s = e.reduce((a, b) => a + b);
  return e.map((v) => v / s).toList();
}

int argmax(List<double> v) {
  var best = 0;
  for (var i = 1; i < v.length; i++) {
    if (v[i] > v[best]) best = i;
  }
  return best;
}

/// CLAP zero-shot labels: the sound evidence (report 4.2, sound_evidence.json), and
/// the picture's "is it a dog or a cat" gate (photo_classifiers.json "gate").
class SoundEvidence {
  SoundEvidence(Map<String, dynamic> j)
      : names = List<String>.from(j['names'] ?? j['keys']),
        keys = List<String>.from(j['keys']),
        species = List<String>.from(j['species']),
        scale = (j['scale'] as num).toDouble(),
        t = (j['T'] as List).map((r) => (r as List).map((v) => (v as num).toDouble()).toList()).toList();
  final List<String> names, keys, species;
  final double scale;
  final List<List<double>> t;

  List<double> probs(List<double> x) => _softmax([
        for (final row in t)
          scale * List.generate(x.length, (i) => row[i] * x[i]).fold(0.0, (a, b) => a + b)
      ]);

  /// Which species the sound alone points to: the group with the most likelihood.
  String speciesOf(List<double> p) {
    final by = <String, double>{};
    for (var i = 0; i < p.length; i++) {
      by[species[i]] = (by[species[i]] ?? 0) + p[i];
    }
    return by.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

/// Logistic regression on the CLAP embedding, from classifiers.json.
class Classifier {
  Classifier(Map<String, dynamic> j)
      : classes = List<String>.from(j['classes']),
        names = List<String>.from(j['names']),
        w = (j['W'] as List).map((r) => (r as List).map((v) => (v as num).toDouble()).toList()).toList(),
        b = (j['b'] as List).map((v) => (v as num).toDouble()).toList();
  final List<String> classes, names;
  final List<List<double>> w;
  final List<double> b;

  List<double> probs(List<double> x) => _softmax(List.generate(b.length, (k) {
        var s = b[k];
        for (var i = 0; i < x.length; i++) {
          s += w[k][i] * x[i];
        }
        return s;
      }));
}

/// Reads a 16-bit PCM mono WAV into samples in [-1, 1).
List<double> readWav16(ByteData d) {
  var p = 12; // skip "RIFF" size "WAVE"
  while (p + 8 <= d.lengthInBytes) {
    final id = String.fromCharCodes(d.buffer.asUint8List(d.offsetInBytes + p, 4));
    final size = d.getUint32(p + 4, Endian.little);
    if (id == 'data') {
      final n = math.min(size, d.lengthInBytes - p - 8) ~/ 2;
      return List.generate(n, (i) => d.getInt16(p + 8 + 2 * i, Endian.little) / 32768.0);
    }
    p += 8 + size + (size & 1);
  }
  throw const FormatException('no data chunk');
}

/// For a picked file longer than 10 s, keep the 10 s with the most sound energy
/// (0.5 s steps), so a video that starts with talking or silence still holds the pet.
/// A 10 s recording made in the app is used as it is.
List<double> loudest10s(List<double> x) {
  if (x.length <= nSamples) return x;
  const step = sampleRate ~/ 2;
  final cum = List<double>.filled(x.length + 1, 0);
  for (var i = 0; i < x.length; i++) {
    cum[i + 1] = cum[i] + x[i] * x[i];
  }
  var best = 0;
  var bestE = -1.0;
  for (var s = 0; s + nSamples <= x.length; s += step) {
    final e = cum[s + nSamples] - cum[s];
    if (e > bestE) {
      bestE = e;
      best = s;
    }
  }
  return x.sublist(best, best + nSamples);
}

/// The picture side of the check (ML step 11, photo_classifiers.json).
class PictureModel {
  PictureModel(Map<String, dynamic> j)
      : inputName = j['input_name'] as String? ?? 'pixel_values',
        output = j['output'] as String? ?? 'image_embeds',
        size = (j['input'] as List?)?.last as int? ?? 224,
        mean = [for (final v in (j['mean'] as List)) (v as num).toDouble()],
        std = [for (final v in (j['std'] as List)) (v as num).toDouble()],
        frames = j['frames'] is int ? j['frames'] as int : 3,
        gate = SoundEvidence(j['gate'] as Map<String, dynamic>),
        dog = j['dog_photo'] == null ? null : Classifier(j['dog_photo'] as Map<String, dynamic>),
        cat = j['cat_photo'] == null ? null : Classifier(j['cat_photo'] as Map<String, dynamic>),
        soundWeight = ((j['combine'] as Map?)?['sound_weight'] as num?)?.toDouble() ?? 0.5;
  final String inputName, output;
  final int size, frames;
  final List<double> mean, std;
  final SoundEvidence gate;
  final Classifier? dog, cat;
  final double soundWeight;

  /// One frame of [size] x [size] RGB bytes -> normalised NCHW floats.
  Float32List pixels(Uint8List rgb) {
    final n = size * size;
    final out = Float32List(3 * n);
    for (var i = 0; i < n; i++) {
      for (var c = 0; c < 3; c++) {
        out[c * n + i] = (rgb[3 * i + c] / 255.0 - mean[c]) / std[c];
      }
    }
    return out;
  }
}

/// Averages embeddings and scales the result to length 1.
List<double> meanUnit(List<List<double>> xs) {
  final m = List<double>.filled(xs.first.length, 0);
  for (final x in xs) {
    for (var i = 0; i < m.length; i++) {
      m[i] += x[i];
    }
  }
  final n = math.sqrt(m.fold(0.0, (s, v) => s + v * v));
  return [for (final v in m) n == 0 ? 0.0 : v / n];
}
