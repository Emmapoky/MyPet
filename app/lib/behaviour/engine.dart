// Runs the behaviour check on the phone (FR02, FR20, FR-N02, NFR03).
//
// One tap records a short video clip (5 to 10 s, report FR02: "record a short
// video using phone on spot"), or the carer picks a video or audio file.
// The picture and the sound are read separately and combined into one result:
//   sound:   soundtrack -> 48 kHz mono WAV (ffmpeg) -> clap_features (isolate)
//            -> quantized CLAP ONNX -> Analysis rules (ML steps 3 to 10).
//   picture: frames from the clip -> image model (ML step 11, not trained yet;
//            until its files exist the result says it used sound only).
// The clip and everything taken from it are deleted straight after (FR-N02).
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

  /// Checks the clip (picture and sound) and deletes it, whatever happens.
  Future<CheckOutcome> check(String clipPath, Species species, {required bool picked});

  Future<void> dispose();
}

Float32List _features(List<double> x) => clapInputFeatures(x);

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

  /// Reads [n] evenly spaced frames of the clip, resized and centre-cropped, as RGB bytes.
  Future<List<Uint8List>> _frames(String src, int n, int size) async {
    final info = (await FFprobeKit.getMediaInformation(src)).getMediaInformation();
    final hasVideo = info?.getStreams().any((s) => s.getType() == 'video') ?? false;
    final dur = double.tryParse(info?.getDuration() ?? '') ?? 0;
    if (!hasVideo || dur <= 0) return const [];
    final out = <Uint8List>[];
    for (var i = 0; i < n; i++) {
      final at = dur * (i + 0.5) / n;
      final raw = await _tmp('frame$i.rgb');
      await FFmpegKit.execute('-y -ss ${at.toStringAsFixed(2)} -i "$src" -frames:v 1 '
          '-vf "scale=$size:$size:force_original_aspect_ratio=increase:flags=bicubic,crop=$size:$size" '
          '-f rawvideo -pix_fmt rgb24 "$raw"');
      final f = File(raw);
      if (await f.exists()) {
        final b = await f.readAsBytes();
        if (b.length == size * size * 3) out.add(b);
        await f.delete();
      }
    }
    return out;
  }

  Future<PictureReading?> _readPicture(String src, Species species) async {
    final m = _picture, v = _vision;
    if (m == null || v == null) return null;
    final frames = await _frames(src, m.frames, m.size);
    if (frames.isEmpty) return null;
    final embs = <List<double>>[];
    for (final f in frames) {
      final input = await OrtValue.fromList(m.pixels(f), [1, 3, m.size, m.size]);
      final out = await v.run({m.inputName: input});
      embs.add((await out[m.output]!.asFlattenedList()).map((x) => (x as num).toDouble()).toList());
      await input.dispose();
      for (final o in out.values) {
        await o.dispose();
      }
    }
    final e = meanUnit(embs);
    final seen = m.gate.speciesOf(m.gate.probs(e));
    final clf = species == Species.cat ? m.cat : m.dog;
    return PictureReading(species: seen, feelings: clf?.probs(e));
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
    try {
      await load();
      wav = await _soundtrack(clipPath);
      var x = readWav16(ByteData.sublistView(await File(wav).readAsBytes()));
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
      final sound = _analysis!.check([for (final v in e) v / n], species);
      final pic = await _readPicture(clipPath, species);
      final names = _analysis!.classifiers[species == Species.cat ? 'cat_context' : 'dog_report']!.names;
      return combine(sound, pic, soundWeight: _picture?.soundWeight ?? 1, names: names);
    } finally {
      // Nothing is kept (FR-N02): not the clip, not the soundtrack.
      for (final f in [clipPath, ?wav]) {
        try {
          await File(f).delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _camera?.dispose();
    await _session?.close();
    await _vision?.close();
  }
}
