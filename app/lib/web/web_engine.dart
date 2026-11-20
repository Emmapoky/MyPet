// The behaviour check in the browser (web build for testers). Same models and the
// same rules as the phone (lib/behaviour/engine.dart); only the plumbing differs:
//   * ONNX Runtime Web (web/index.html) instead of the native runtime;
//   * the browser decodes and resamples the sound (web/mypet_media.js), not ffmpeg;
//   * frames come from a <video> element drawn on a canvas;
//   * clips are blob URLs or files in the browser store, never uploaded.
// The models (about 120 MB) download on the first check and the browser caches them.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:clap_features/clap_features.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:material_ui/material_ui.dart' show Widget, SizedBox;

import '../behaviour/analysis.dart';
import '../behaviour/engine.dart';
import '../behaviour/model.dart';
import '../models/pet.dart';
import 'web_io.dart';
import 'web_media.dart';

/// Where the web host serves the two models (one file each, see web_host/).
const webModelUrl = 'models/clap_audio_quantized.onnx';
const webVisionModelUrl = 'models/clip_vision_quantized.onnx';

BehaviourEngine makeBehaviourEngine() => WebBehaviourEngine();

@JS('mypetMedia.decodeAudio')
external JSPromise<JSFloat32Array> _decodeAudio(String url, int rate);

@JS('mypetMedia.probe')
external JSPromise<JSArray<JSNumber>> _probe(String url);

@JS('mypetMedia.frames')
external JSPromise<JSUint8Array> _frames(String url, int size, int max, double dur);

@JS('mypetMedia.bytes')
external JSPromise<JSUint8Array> _bytes(String url);

class WebBehaviourEngine implements BehaviourEngine {
  CameraController? _camera;
  Analysis? _analysis;
  OrtSession? _session;
  PictureModel? _picture;
  OrtSession? _vision;
  Future<void>? _loading;

  @override
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final c = await rootBundle.loadString(classifiersAsset);
      final s = await rootBundle.loadString(soundEvidenceAsset);
      final clf = (jsonDecode(c) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, Classifier(v as Map<String, dynamic>)));
      _analysis = Analysis(classifiers: clf, sound: SoundEvidence(jsonDecode(s) as Map<String, dynamic>));
      _session = await OnnxRuntime().createSession(webModelUrl);
    } catch (_) {
      _loading = null;
      throw const CheckProblem('Could not load the behaviour model. Check the internet connection and try again.');
    }
    try {
      _picture = PictureModel(jsonDecode(await rootBundle.loadString(pictureAsset)) as Map<String, dynamic>);
      _vision = await OnnxRuntime().createSession(webVisionModelUrl);
    } catch (_) {
      _picture = null; // Picture model not reachable: sound only.
    }
  }

  String _url(String path) {
    final u = urlOf(path);
    if (u == null) throw const CheckProblem('That clip is gone. Record it again.');
    return u;
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

  /// Same as the phone: whole-clip reading from frames at 20%, 50% and 80%, plus one
  /// moment per second of what the picture showed.
  Future<(PictureReading?, List<Moment>)> _readPicture(String url, Species species, double dur) async {
    final m = _picture, v = _vision;
    if (m == null || v == null || dur <= 0) return (null, const <Moment>[]);
    final raw = (await _frames(url, m.size, maxMoments, dur).toDart).toDart;
    final one = m.size * m.size * 3;
    final frames = [for (var k = 0; (k + 1) * one <= raw.length; k++) Uint8List.sublistView(raw, k * one, (k + 1) * one)];
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
    final n = m.frames;
    final pick = <int>{
      for (var i = 0; i < n; i++)
        (dur * (n == 1 ? 0.5 : 0.2 + 0.6 * i / (n - 1))).floor().clamp(0, embs.length - 1),
    };
    final e = meanUnit([for (final i in pick) embs[i]]);
    final seen = m.gate.speciesOf(m.gate.probs(e));
    return (PictureReading(species: seen, feelings: clf?.probs(e)), moments);
  }

  Future<List<Moment>> _soundMoments(List<double> x, Species species) async {
    final secs = math.min((x.length / sampleRate).ceil(), maxMoments);
    final out = <Moment>[];
    final dur = x.length / sampleRate;
    for (var k = 0; k < secs; k++) {
      final a = math.max(0, ((k - 0.5) * sampleRate).round());
      final b = math.min(x.length, ((k + 1.5) * sampleRate).round());
      if (b - a < sampleRate ~/ 2) continue;
      final w = x.sublist(a, b);
      final rms = math.sqrt(w.fold(0.0, (s, v) => s + v * v) / w.length);
      if (rms < 0.005) continue;
      await Future<void>.delayed(Duration.zero); // Let the page draw between windows.
      final e = await _embed(clapInputFeatures(w));
      final hit = soundInWindow(_analysis!.sound, _analysis!.sound.probs(e));
      if (hit != null) {
        out.add(Moment(MomentSource.sound, hit.$1, k.toDouble(), math.min(k + 1.0, dur), p: hit.$2));
      }
    }
    return out;
  }

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
  Future<String> stopRecording() async => (await _camera!.stopVideoRecording()).path; // a blob: URL

  @override
  Future<String?> pickFile() async {
    final picked = await FilePicker.pickFiles(type: FileType.media);
    if (picked.isEmpty) return null;
    final f = picked.first;
    final dot = f.name.lastIndexOf('.');
    final path = '/tmp/picked_${DateTime.now().millisecondsSinceEpoch}${dot >= 0 ? f.name.substring(dot) : '.mp4'}';
    await File(path).writeAsBytes(await f.readAsBytes());
    return path;
  }

  @override
  Future<CheckOutcome> check(String clipPath, Species species, {required bool picked}) async {
    var keep = false;
    try {
      await load();
      final url = _url(clipPath);
      final List<double> all;
      try {
        all = (await _decodeAudio(url, sampleRate).toDart).toDart;
      } catch (_) {
        throw const CheckProblem('Could not hear any sound in that clip. Try another one.');
      }
      if (all.length < sampleRate) {
        throw const CheckProblem('The clip was under 1 second. Record a little longer.');
      }
      final x = picked ? loudest10s(all) : all;
      final sound = _analysis!.check(await _embed(clapInputFeatures(x)), species);
      final info = (await _probe(url).toDart).toDart;
      final dur0 = info[0].toDartDouble;
      final hasVideo = info[1].toDartDouble > 0;
      final dur = dur0 > 0 && dur0.isFinite ? dur0 : all.length / sampleRate;
      final (pic, picMoments) = hasVideo ? await _readPicture(url, species, dur) : (null, const <Moment>[]);
      final names = _analysis!.classifiers[species == Species.cat ? 'cat_context' : 'dog_report']!.names;
      final result = combine(sound, pic, soundWeight: _picture?.soundWeight ?? 1, names: names);
      final moments = mergeMoments([...await _soundMoments(all, species), ...picMoments]);
      keep = true;
      return result.withClip(clip: clipPath, seconds: dur, moments: moments);
    } finally {
      if (!keep) await discard(clipPath);
    }
  }

  @override
  Future<void> discard(String? clipPath) async {
    if (clipPath == null || clipPath.startsWith('blob:')) return;
    try {
      await File(clipPath).delete();
    } catch (_) {}
  }

  /// In the browser a saved check can keep its video for this visit (big clips are not
  /// kept after a reload). "Sound only" keeps nothing here, since there is no ffmpeg
  /// to drop the picture.
  @override
  Future<String?> keep(String clipPath, String dir, String id, ClipKeep how) async {
    try {
      if (how != ClipKeep.video) return null;
      final b = (await _bytes(_url(clipPath)).toDart).toDart;
      final webm = b.length > 4 && b[0] == 0x1a && b[1] == 0x45 && b[2] == 0xdf && b[3] == 0xa3;
      final name = 'check_$id${webm ? '.webm' : '.mp4'}';
      await File('$dir/$name').writeAsBytes(b);
      return name;
    } catch (_) {
      return null;
    } finally {
      await discard(clipPath);
    }
  }

  @override
  Future<void> dispose() async {
    await _camera?.dispose();
    await _session?.close();
    await _vision?.close();
  }
}
