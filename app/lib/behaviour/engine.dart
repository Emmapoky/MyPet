// Runs the behaviour check on the phone (FR02, FR20, FR-N02, NFR03).
//
// Pipeline, the same one tested in ml/flutter/behaviour_bench (ML steps 3 to 10):
//   10 s WAV, 48 kHz mono -> clap_features (Dart, background isolate)
//   -> quantized CLAP ONNX -> 512 numbers scaled to length 1 -> Analysis rules.
// Only the sound is used. A picked video's soundtrack is extracted and the
// picture is never read. Every clip is deleted straight after the check.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:clap_features/clap_features.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/pet.dart';
import 'analysis.dart';
import 'model.dart';

const modelAsset = 'assets/models/clap_audio_quantized.onnx';
const classifiersAsset = 'assets/behaviour/classifiers.json';
const soundEvidenceAsset = 'assets/behaviour/sound_evidence.json';

/// Why a check could not run. These are plain problems, not results.
class CheckProblem implements Exception {
  const CheckProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What the Check tab needs. [PhoneBehaviourEngine] on the phone, a fake in tests.
abstract class BehaviourEngine {
  /// Loads the model once. Throws [CheckProblem] if the model files are missing.
  Future<void> load();
  Future<bool> micAllowed();
  Future<void> startRecording();

  /// Loudness from 0 to 1 while recording, for the live waveform.
  Stream<double> get level;

  /// Stops and returns the clip's path.
  Future<String> stopRecording();

  /// Lets the person pick a video or audio file and returns a WAV of its sound,
  /// or null if they cancelled.
  Future<String?> pickFile();

  /// Checks the clip and deletes it, whatever happens.
  Future<CheckOutcome> check(String wavPath, Species species, {required bool picked});

  Future<void> dispose();
}

Float32List _features(List<double> x) => clapInputFeatures(x);

class PhoneBehaviourEngine implements BehaviourEngine {
  late final _rec = AudioRecorder();
  Analysis? _analysis;
  OrtSession? _session;
  Future<void>? _loading;
  String? _recPath;

  @override
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final String c, s;
    try {
      c = await rootBundle.loadString(classifiersAsset);
      s = await rootBundle.loadString(soundEvidenceAsset);
      await rootBundle.load(modelAsset);
    } catch (_) {
      _loading = null;
      throw const CheckProblem('The behaviour model is not on this phone yet.');
    }
    final clf = (jsonDecode(c) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, Classifier(v as Map<String, dynamic>)));
    _analysis = Analysis(classifiers: clf, sound: SoundEvidence(jsonDecode(s) as Map<String, dynamic>));
    _session = await OnnxRuntime().createSessionFromAsset(modelAsset);
  }

  Future<String> _tmp(String name) async => '${(await getTemporaryDirectory()).path}/$name';

  @override
  Future<bool> micAllowed() => _rec.hasPermission();

  @override
  Future<void> startRecording() async {
    _recPath = await _tmp('check.wav');
    await _rec.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: sampleRate, numChannels: 1),
        path: _recPath!);
  }

  @override
  Stream<double> get level => _rec
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      // dBFS: -50 or quieter is flat, 0 is full height.
      .map((a) => ((a.current + 50) / 50).clamp(0.0, 1.0).toDouble());

  @override
  Future<String> stopRecording() async => (await _rec.stop()) ?? _recPath!;

  @override
  Future<String?> pickFile() async {
    final picked = await FilePicker.pickFiles(type: FileType.media);
    final src = picked.isEmpty ? null : picked.first.path;
    if (src == null) return null;
    // Any audio or video file -> 48 kHz mono 16-bit WAV (soundtrack only).
    final wav = await _tmp('picked.wav');
    final s = await FFmpegKit.execute('-y -i "$src" -vn -ac 1 -ar $sampleRate -c:a pcm_s16le "$wav"');
    if (!await File(wav).exists() || (await s.getReturnCode())?.isValueSuccess() != true) {
      throw const CheckProblem('Could not read any sound from that file. Try another video or audio file.');
    }
    return wav;
  }

  @override
  Future<CheckOutcome> check(String wavPath, Species species, {required bool picked}) async {
    try {
      await load();
      var x = readWav16(ByteData.sublistView(await File(wavPath).readAsBytes()));
      if (x.length < sampleRate) {
        throw const CheckProblem('The clip was under 1 second. Record a little longer.');
      }
      if (picked) x = loudest10s(x);
      final feats = await compute(_features, x);
      final input = await OrtValue.fromList(feats, [1, 1, nFrames, nMels]);
      final out = await _session!.run({'input_features': input});
      final e = (await out['audio_embeds']!.asFlattenedList()).map((v) => (v as num).toDouble()).toList();
      await input.dispose();
      for (final v in out.values) {
        await v.dispose();
      }
      final n = math.sqrt(e.fold(0.0, (s, v) => s + v * v));
      return _analysis!.check([for (final v in e) v / n], species);
    } finally {
      // The clip is never kept (FR-N02).
      try {
        await File(wavPath).delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    if (_recPath != null) await _rec.dispose();
    await _session?.close();
  }
}
