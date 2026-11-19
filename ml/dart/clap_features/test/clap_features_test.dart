import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clap_features/clap_features.dart';
import 'package:test/test.dart';

// Same formulas as test_signal() in ml/reference/clap_features.py
List<double> testSignal(String name) {
  const sr = sampleRate;
  if (name == 'short_tone') {
    return List.generate((1.5 * sr).toInt(), (i) {
      final t = i / sr;
      return 0.5 * math.sin(2 * math.pi * 440 * t) + 0.25 * math.sin(2 * math.pi * 1000 * t);
    });
  }
  if (name == 'chirp_10s') {
    return List.generate(nSamples, (i) {
      final t = i / sr;
      return 0.3 * math.sin(2 * math.pi * (100 * t + (12000 - 100) / (2 * 10) * t * t));
    });
  }
  if (name == 'long_12s') {
    return List.generate(12 * sr, (i) {
      final t = i / sr;
      return t < 6 ? 0.4 * math.sin(2 * math.pi * 300 * t) : 0.4 * math.sin(2 * math.pi * 2500 * t);
    });
  }
  throw ArgumentError(name);
}

Float32List loadF32(String file) {
  final bytes = File('../../reference/fixtures/$file').readAsBytesSync();
  return bytes.buffer.asByteData().let((b) => Float32List.fromList(
      List.generate(bytes.length ~/ 4, (i) => b.getFloat32(i * 4, Endian.little))));
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

void main() {
  test('mel filter bank matches the reference', () {
    final ours = melFilterBank();
    final ref = loadF32('mel_filters_513x64.f32.bin');
    var maxDiff = 0.0;
    for (var i = 0; i < ref.length; i++) {
      maxDiff = math.max(maxDiff, (ours[i] - ref[i]).abs());
    }
    print('filter bank max abs diff: $maxDiff');
    expect(maxDiff, lessThan(1e-7));
  });

  for (final name in ['short_tone', 'chirp_10s', 'long_12s']) {
    test('$name features match the reference within 0.01 dB', () {
      final sw = Stopwatch()..start();
      final ours = clapInputFeatures(testSignal(name));
      sw.stop();
      final ref = loadF32('$name.features.f32.bin');
      expect(ours.length, ref.length);
      var maxDiff = 0.0;
      for (var i = 0; i < ref.length; i++) {
        maxDiff = math.max(maxDiff, (ours[i] - ref[i]).abs());
      }
      print('$name: max abs diff ${maxDiff.toStringAsExponential(2)} dB, ${sw.elapsedMilliseconds} ms');
      expect(maxDiff, lessThan(0.01));
    });
  }
}
