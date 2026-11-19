// Runs the behaviour check on the phone (FR02, FR20, FR-N02, NFR03).
//
// One tap records a short video clip (5 to 10 s, report FR02: "record a short
// video using phone on spot"), or the carer picks a video or audio file.
// The picture and the sound are read separately and combined into one result:
//   sound:   soundtrack -> 48 kHz mono WAV (ffmpeg) -> clap_features (isolate)
//            -> quantized CLAP ONNX -> Analysis rules (ML steps 3 to 10).
//   picture: frames from the clip -> CLIP image model (ML step 11); sound only
//            if its files are not on the phone.
// Each second is also read on its own, so the result can show when each sound or
// picture moment happened. The soundtrack is deleted straight away; the clip only
// stays for the replay on the result screen and is deleted on Save or Retake (FR-N02).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:clap_features/clap_features.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart' show Widget, SizedBox;

import '../models/pet.dart';
import 'analysis.dart';
import 'model.dart';

const modelAsset = 'assets/models/clap_audio_quantized.onnx';
const classifiersAsset = 'assets/behaviour/classifiers.json';
const soundEvidenceAsset = 'assets/behaviour/sound_evidence.json';

/// Picture side (ML step 11). Optional: without these the check uses sound only.
const visionModelAsset = 'assets/models/clip_vision_quantized.onnx';
const pictureAsset = 'assets/behaviour/photo_classifiers.json';

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

  /// Opens the back camera with sound. Returns false if there is no camera or no permission.
  Future<bool> openCamera();

  /// Live camera picture for the panel, once [openCamera] succeeded.
  Widget preview();

  Future<void> startRecording();

  /// Stops and returns the clip's path.
  Future<String> stopRecording();

  /// Lets the person pick a video or audio file and returns its path, or null if they cancelled.
  Future<String?> pickFile();

  /// Checks the clip (picture and sound). On success the clip is kept for the replay on
  /// the result screen and [CheckOutcome.clip] points to it; call [discard] when the result
  /// closes. If the check fails, the clip is deleted straight away.
  Future<CheckOutcome> check(String clipPath, Species species, {required bool picked});

  /// Deletes a clip kept for the result screen (FR-N02).
  Future<void> discard(String? clipPath);

  Future<void> dispose();
}

Float32List _features(List<double> x) => clapInputFeatures(x);
List<Float32List> _featuresMany(List<List<double>> xs) => [for (final x in xs) clapInputFeatures(x)];

/// Moments are read for at most this many seconds of a clip.
const maxMoments = 30;

class PhoneBehaviourEngine implements BehaviourEngine {
  CameraController? _camera;
  Analysis? _analysis;
  OrtSession? _session;
  PictureModel? _picture;
  OrtSession? _vision;
  Future<void>? _loading;

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
    try {
      _picture = PictureModel(jsonDecode(await rootBundle.loadString(pictureAsset)) as Map<String, dynamic>);
      await rootBundle.load(visionModelAsset);
      _vision = await OnnxRuntime().createSessionFromAsset(visionModelAsset);
    } catch (_) {
      _picture = null; // Picture model not on this phone yet: sound only.
    }
  }

  /// Length of the clip in seconds and whether it has pictures.
  Future<(double, bool)> _probe(String src) async {
    final info = (await FFprobeKit.getMediaInformation(src)).getMediaInformation();
    final hasVideo = info?.getStreams().any((s) => s.getType() == 'video') ?? false;
    return (double.tryParse(info?.getDuration() ?? '') ?? 0, hasVideo);
  }

  /// One frame per second (up to [maxMoments]), resized and centre-cropped, as RGB bytes.
  /// Frame k shows second k of the clip.
  Future<List<Uint8List>> _framesPerSecond(String src, int size) async {
    final raw = await _tmp('frames.rgb');
    await FFmpegKit.execute('-y -i "$src" -frames:v $maxMoments '
        '-vf "fps=1,scale=$size:$size:force_original_aspect_ratio=increase:flags=bicubic,crop=$size:$size" '
        '-f rawvideo -pix_fmt rgb24 "$raw"');
    final f = File(raw);
    if (!await f.exists()) return const [];
    final b = await f.readAsBytes();
    await f.delete();
    final one = size * size * 3;
    return [for (var k = 0; (k + 1) * one <= b.length; k++) Uint8List.sublistView(b, k * one, (k + 1) * one)];
  }

  Future<List<double>> _embedFrame(PictureModel m, OrtSession v, Uint8List f) async {
    final input = await OrtValue.fromList(m.pixels(f), [1, 3, m.size, m.size]);
    final out = await v.run({m.inputName: input});
    final e = (await out[m.output]!.asFlattenedList()).map((x) => (x as num).toDouble()).toList();
    await input.dispose();
    for (final o in out.values) {
      await o.dispose();
    }
    return e;
  }

  /// The picture side: the whole-clip reading (frames at 20%, 50% and 80%, as in the
  /// ML Lab) and one moment per second of what the picture showed.
  Future<(PictureReading?, List<Moment>)> _readPicture(String src, Species species, double dur) async {
    final m = _picture, v = _vision;
    if (m == null || v == null || dur <= 0) return (null, const <Moment>[]);
    final frames = await _framesPerSecond(src, m.size);
    if (frames.isEmpty) return (null, const <Moment>[]);
    final embs = [for (final f in frames) await _embedFrame(m, v, f)];
    final clf = species == Species.cat ? m.cat : m.dog;
    final moments = <Moment>[];
    for (var k = 0; k < embs.length; k++) {
      final e = meanUnit([embs[k]]);
      final seen = m.gate.speciesOf(m.gate.probs(e));
      List<(String, double)>? feel;
      if (clf != null && seen == species.name) {
        final p = clf.probs(e);
        final idx = List.generate(p.length, (i) => i)..sort((a, b) => p[b].compareTo(p[a]));
        feel = [for (final i in idx) (clf.names[i], p[i])];
      }
      final gp = m.gate.probs(e);
      final seenP = [for (var i = 0; i < gp.length; i++) if (m.gate.species[i] == seen) gp[i]].fold(0.0, (a, b) => a + b);
      final hit = pictureInFrame(seen, seenP: seenP, feelings: feel);
      if (hit != null) {
        moments.add(Moment(MomentSource.picture, hit.$1, k.toDouble(), math.min(k + 1.0, dur), p: hit.$2));
      }
    }
    // Whole clip: the frames nearest 20%, 50% and 80% through (or evenly spread for other counts).
    final n = m.frames;
    final pick = <int>{
      for (var i = 0; i < n; i++)
        (dur * (n == 1 ? 0.5 : 0.2 + 0.6 * i / (n - 1))).floor().clamp(0, embs.length - 1),
    };
    final e = meanUnit([for (final i in pick) embs[i]]);
    final seen = m.gate.speciesOf(m.gate.probs(e));
    return (PictureReading(species: seen, feelings: clf?.probs(e)), moments);
  }

  /// One moment per second of the pet sound heard there, each read from 2 s of sound
  /// centred on that second. Quiet seconds are skipped.
  Future<List<Moment>> _soundMoments(List<double> x, Species species) async {
    final secs = math.min((x.length / sampleRate).ceil(), maxMoments);
    final windows = <int, List<double>>{};
    for (var k = 0; k < secs; k++) {
      final a = math.max(0, ((k - 0.5) * sampleRate).round());
      final b = math.min(x.length, ((k + 1.5) * sampleRate).round());
      if (b - a < sampleRate ~/ 2) continue;
      final w = x.sublist(a, b);
      final rms = math.sqrt(w.fold(0.0, (s, v) => s + v * v) / w.length);
      if (rms >= 0.005) windows[k] = w;
    }
    if (windows.isEmpty) return const [];
    final feats = await compute(_featuresMany, windows.values.toList());
    final out = <Moment>[];
    final keys = windows.keys.toList();
    final dur = x.length / sampleRate;
    for (var i = 0; i < keys.length; i++) {
      final e = await _embed(feats[i]);
      final hit = soundInWindow(_analysis!.sound, _analysis!.sound.probs(e));
      if (hit != null) {
        out.add(Moment(MomentSource.sound, hit.$1, keys[i].toDouble(), math.min(keys[i] + 1.0, dur), p: hit.$2));
      }
    }
    return out;
  }

  /// CLAP audio embedding, scaled to length 1.
  Future<List<double>> _embed(Float32List feats) async {
    final input = await OrtValue.fromList(feats, [1, 1, nFrames, nMels]);
    final out = await _session!.run({'input_features': input});
    final e = (await out['audio_embeds']!.asFlattenedList()).map((v) => (v as num).toDouble()).toList();
    await input.dispose();
    for (final v in out.values) {
      await v.dispose();
    }
    final n = math.sqrt(e.fold(0.0, (s, v) => s + v * v));
    return [for (final v in e) v / n];
  }

  Future<String> _tmp(String name) async => '${(await getTemporaryDirectory()).path}/$name';

  @override
  Future<bool> openCamera() async {
    if (_camera?.value.isInitialized == true) return true;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return false;
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(back, ResolutionPreset.medium, enableAudio: true);
      await c.initialize();
      _camera = c;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget preview() => _camera?.value.isInitialized == true ? CameraPreview(_camera!) : const SizedBox.shrink();

  @override
  Future<void> startRecording() => _camera!.startVideoRecording();

  @override
  Future<String> stopRecording() async => (await _camera!.stopVideoRecording()).path;

  @override
  Future<String?> pickFile() async {
    final picked = await FilePicker.pickFiles(type: FileType.media);
    return picked.isEmpty ? null : picked.first.path;
  }

  /// Any audio or video file -> 48 kHz mono 16-bit WAV (soundtrack only).
  Future<String> _soundtrack(String src) async {
    final wav = await _tmp('check.wav');
    final s = await FFmpegKit.execute('-y -i "$src" -vn -ac 1 -ar $sampleRate -c:a pcm_s16le "$wav"');
    if (!await File(wav).exists() || (await s.getReturnCode())?.isValueSuccess() != true) {
      throw const CheckProblem('Could not hear any sound in that clip. Try another one.');
    }
    return wav;
  }

  @override
  Future<CheckOutcome> check(String clipPath, Species species, {required bool picked}) async {
    String? wav;
    var keep = false;
    try {
      await load();
      wav = await _soundtrack(clipPath);
      final all = readWav16(ByteData.sublistView(await File(wav).readAsBytes()));
      if (all.length < sampleRate) {
        throw const CheckProblem('The clip was under 1 second. Record a little longer.');
      }
      final x = picked ? loudest10s(all) : all;
      final sound = _analysis!.check(await _embed(await compute(_features, x)), species);
      final (dur0, hasVideo) = await _probe(clipPath);
      final dur = dur0 > 0 ? dur0 : all.length / sampleRate;
      final (pic, picMoments) = hasVideo ? await _readPicture(clipPath, species, dur) : (null, const <Moment>[]);
      final names = _analysis!.classifiers[species == Species.cat ? 'cat_context' : 'dog_report']!.names;
      final result = combine(sound, pic, soundWeight: _picture?.soundWeight ?? 1, names: names);
      final moments = mergeMoments([...await _soundMoments(all, species), ...picMoments]);
      keep = true;
      return result.withClip(clip: clipPath, seconds: dur, moments: moments);
    } finally {
      // The soundtrack is never kept. The clip stays only for the replay on the result
      // screen, and is deleted when that closes (discard) or straight away on a problem.
      for (final f in [if (!keep) clipPath, ?wav]) {
        try {
          await File(f).delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> discard(String? clipPath) async {
    if (clipPath == null) return;
    try {
      await File(clipPath).delete();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await _camera?.dispose();
    await _session?.close();
    await _vision?.close();
  }
}
