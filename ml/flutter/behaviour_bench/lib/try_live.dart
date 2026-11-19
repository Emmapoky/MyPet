// MyPet ML step 10: try the behaviour check on a real pet.
//
// Record 10 s with the microphone (report Table 4.1), or pick a video or sound
// file already on the phone (for example a video of a relative's cat). Only the
// sound is used: a video's soundtrack is extracted, the picture is never read.
// The clip is analysed on the phone and deleted straight after (FR-N02).
import 'dart:io';
import 'dart:math' as math;

import 'package:clap_features/clap_features.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'analysis.dart';
import 'test_library.dart' show readWav16;

Float32List _features(List<double> x) => clapInputFeatures(x);

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

class TryLivePage extends StatefulWidget {
  const TryLivePage({super.key});
  @override
  State<TryLivePage> createState() => _TryLivePageState();
}

class _TryLivePageState extends State<TryLivePage> {
  final _rec = AudioRecorder();
  Analysis? _analysis;
  OrtSession? _session;
  String _species = 'dog';
  String _status = '';
  int _seconds = 0;
  bool _busy = false;
  CheckResult? _result;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Load once when the screen opens, not after recording (step 3: about 0.5 s).
    final a = await Analysis.load();
    final s = await OnnxRuntime().createSessionFromAsset('assets/models/clap_audio_quantized.onnx');
    if (mounted) {
      setState(() {
        _analysis = a;
        _session = s;
      });
    }
  }

  @override
  void dispose() {
    _rec.dispose();
    _session?.close();
    super.dispose();
  }

  Future<String> _tmp(String name) async => '${(await getTemporaryDirectory()).path}/$name';

  Future<void> _record() async {
    if (!await _rec.hasPermission()) {
      setState(() => _status = 'Microphone permission is off. Turn it on in Settings.');
      return;
    }
    final path = await _tmp('check.wav');
    setState(() {
      _busy = true;
      _result = null;
      _status = 'Recording';
    });
    await _rec.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: sampleRate, numChannels: 1), path: path);
    for (_seconds = 10; _seconds > 0; _seconds--) {
      if (mounted) setState(() {});
      await Future.delayed(const Duration(seconds: 1));
    }
    await _rec.stop();
    await _analyseFile(path, fromRecording: true);
  }

  Future<void> _pick() async {
    final picked = await FilePicker.pickFiles(type: FileType.media);
    final src = picked.isEmpty ? null : picked.first.path;
    if (src == null) return;
    setState(() {
      _busy = true;
      _result = null;
      _status = 'Reading the sound';
    });
    // Any audio or video file -> 48 kHz mono 16-bit WAV (soundtrack only).
    final wav = await _tmp('picked.wav');
    final s = await FFmpegKit.execute('-y -i "$src" -vn -ac 1 -ar $sampleRate -c:a pcm_s16le "$wav"');
    if (!(await File(wav).exists()) || (await s.getReturnCode())?.isValueSuccess() != true) {
      setState(() {
        _busy = false;
        _status = 'Could not read a sound track from that file.';
      });
      return;
    }
    await _analyseFile(wav, fromRecording: false);
  }

  Future<void> _analyseFile(String path, {required bool fromRecording}) async {
    setState(() => _status = 'Checking');
    final sw = Stopwatch()..start();
    try {
      final bytes = await File(path).readAsBytes();
      var x = readWav16(ByteData.sublistView(bytes));
      x = fromRecording ? x : loudest10s(x);
      final feats = await compute(_features, x);
      final input = await OrtValue.fromList(feats, [1, 1, nFrames, nMels]);
      final out = await _session!.run({'input_features': input});
      final e = (await out['audio_embeds']!.asFlattenedList()).map((v) => (v as num).toDouble()).toList();
      await input.dispose();
      for (final v in out.values) {
        await v.dispose();
      }
      final n = math.sqrt(e.fold(0.0, (s, v) => s + v * v));
      final r = _analysis!.check(e.map((v) => v / n).toList(), _species);
      setState(() {
        _result = r;
        _status = 'Done in ${sw.elapsedMilliseconds} ms';
      });
    } finally {
      // The clip is never kept (FR-N02).
      await File(path).delete().catchError((_) => File(path));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _analysis != null && _session != null;
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Try a clip')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Record 10 seconds near the pet, or pick a video or sound already on this phone. '
            'Only the sound is used, and it is deleted after the check.'),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'dog', label: Text('Dog'), icon: Icon(Icons.pets)),
            ButtonSegment(value: 'cat', label: Text('Cat'), icon: Icon(Icons.pets_outlined)),
          ],
          selected: {_species},
          onSelectionChanged: _busy ? null : (s) => setState(() => _species = s.first),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: ready && !_busy ? _record : null,
          icon: const Icon(Icons.mic),
          label: Text(_busy && _seconds > 0 ? 'Recording... $_seconds s' : 'Record 10 s'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: ready && !_busy ? _pick : null,
          icon: const Icon(Icons.video_library),
          label: const Text('Pick a video or sound'),
        ),
        const SizedBox(height: 12),
        if (!ready) const Text('Loading the model...'),
        if (_status.isNotEmpty) Text(_status, style: Theme.of(context).textTheme.bodySmall),
        if (r != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
                Text(r.headline, style: Theme.of(context).textTheme.titleLarge),
                if (r.reason != null) Text(r.reason!),
                for (final (name, p) in r.feelings)
                  Row(children: [
                    SizedBox(width: 190, child: Text(name)),
                    Expanded(child: LinearProgressIndicator(value: p)),
                    SizedBox(width: 48, child: Text(' ${(100 * p).round()}%')),
                  ]),
                Text('Sounds like: ${r.sounds.take(3).map((s) => '${s.$1} ${(100 * s.$2).round()}%').join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall),
                const Text('Not a medical diagnosis.'),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
