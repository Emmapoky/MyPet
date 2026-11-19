/// Recording -> CLAP model input for MyPet (port of ml/reference/clap_features.py).
///
/// Input: mono PCM samples at 48 kHz, as doubles in [-1, 1].
/// Output: Float32List of 1001 * 64 values (row-major, frame by mel bin),
/// to be fed to the ONNX input `input_features` with shape [1, 1, 1001, 64].
///
/// Steps (same as the Python reference):
/// 1. Exactly 480,000 samples: repeat a short clip whole as many times as
///    fit, then zero-pad; cut a long clip to its first 10 s.
/// 2. Mirror-pad 512 samples at each end.
/// 3. 1001 frames of 1024 samples, hop 480, periodic Hann window.
/// 4. Power spectrum |FFT|^2, first 513 bins.
/// 5. Multiply by the 513 x 64 Slaney mel filter bank (50 Hz - 14 kHz), floor 1e-10.
/// 6. 10 * log10.
library;

import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 48000;
const int nSamples = 480000;
const int nFft = 1024;
const int hop = 480;
const int nMels = 64;
const double fMin = 50.0;
const double fMax = 14000.0;
const int nFrames = 1 + nSamples ~/ hop; // 1001
const int nBins = nFft ~/ 2 + 1; // 513

double _hzToMel(double f) => f >= 1000.0
    ? 15.0 + math.log(f / 1000.0) * (27.0 / math.log(6.4))
    : 3.0 * f / 200.0;

double _melToHz(double m) => m >= 15.0
    ? 1000.0 * math.exp(math.log(6.4) / 27.0 * (m - 15.0))
    : 200.0 * m / 3.0;

/// 513 x 64 filter bank, row-major (bin, mel).
Float64List melFilterBank() {
  final fb = Float64List(nBins * nMels);
  final melLo = _hzToMel(fMin), melHi = _hzToMel(fMax);
  final hz = List<double>.generate(
      nMels + 2, (i) => _melToHz(melLo + (melHi - melLo) * i / (nMels + 1)));
  for (var m = 0; m < nMels; m++) {
    final lo = hz[m], mid = hz[m + 1], hi = hz[m + 2];
    final norm = 2.0 / (hi - lo);
    for (var k = 0; k < nBins; k++) {
      final f = (sampleRate / 2) * k / (nBins - 1);
      final up = (f - lo) / (mid - lo), down = (hi - f) / (hi - mid);
      final w = math.max(0.0, math.min(up, down));
      fb[k * nMels + m] = w * norm;
    }
  }
  return fb;
}

Float64List _fixLength(List<double> x) {
  final out = Float64List(nSamples);
  if (x.isEmpty) return out;
  if (x.length >= nSamples) {
    for (var i = 0; i < nSamples; i++) out[i] = x[i];
    return out;
  }
  final repeats = nSamples ~/ x.length;
  for (var r = 0; r < repeats; r++) {
    for (var i = 0; i < x.length; i++) out[r * x.length + i] = x[i];
  }
  return out; // rest stays zero
}

Float64List _reflectPad(Float64List x, int p) {
  final n = x.length;
  final out = Float64List(n + 2 * p);
  for (var i = 0; i < p; i++) out[i] = x[p - i]; // mirror, edge not repeated
  for (var i = 0; i < n; i++) out[p + i] = x[i];
  for (var i = 0; i < p; i++) out[p + n + i] = x[n - 2 - i];
  return out;
}

/// In-place iterative radix-2 FFT (n must be a power of two).
void _fft(Float64List re, Float64List im) {
  final n = re.length;
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; (j & bit) != 0; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) {
      var t = re[i]; re[i] = re[j]; re[j] = t;
      t = im[i]; im[i] = im[j]; im[j] = t;
    }
  }
  for (var len = 2; len <= n; len <<= 1) {
    final ang = -2 * math.pi / len;
    final wr = math.cos(ang), wi = math.sin(ang);
    for (var i = 0; i < n; i += len) {
      var cr = 1.0, ci = 0.0;
      for (var k = 0; k < len ~/ 2; k++) {
        final ar = re[i + k], ai = im[i + k];
        final br = re[i + k + len ~/ 2] * cr - im[i + k + len ~/ 2] * ci;
        final bi = re[i + k + len ~/ 2] * ci + im[i + k + len ~/ 2] * cr;
        re[i + k] = ar + br; im[i + k] = ai + bi;
        re[i + k + len ~/ 2] = ar - br; im[i + k + len ~/ 2] = ai - bi;
        final ncr = cr * wr - ci * wi;
        ci = cr * wi + ci * wr;
        cr = ncr;
      }
    }
  }
}

/// The model input for one recording: 1001 * 64 float32 values.
Float32List clapInputFeatures(List<double> samples, {Float64List? filterBank}) {
  final fb = filterBank ?? melFilterBank();
  final x = _reflectPad(_fixLength(samples), nFft ~/ 2);
  final win = Float64List.fromList(
      List.generate(nFft, (i) => 0.5 - 0.5 * math.cos(2 * math.pi * i / nFft)));
  final re = Float64List(nFft), im = Float64List(nFft);
  final power = Float64List(nBins);
  final out = Float32List(nFrames * nMels);
  for (var t = 0; t < nFrames; t++) {
    final start = t * hop;
    for (var i = 0; i < nFft; i++) {
      re[i] = x[start + i] * win[i];
      im[i] = 0.0;
    }
    _fft(re, im);
    for (var k = 0; k < nBins; k++) power[k] = re[k] * re[k] + im[k] * im[k];
    for (var m = 0; m < nMels; m++) {
      var s = 0.0;
      for (var k = 0; k < nBins; k++) s += power[k] * fb[k * nMels + m];
      out[t * nMels + m] = (10.0 * math.log(math.max(1e-10, s)) / math.ln10);
    }
  }
  return out;
}
