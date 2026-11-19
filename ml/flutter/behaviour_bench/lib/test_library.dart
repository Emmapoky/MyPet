// MyPet ML step 6: Test library.
//
// Runs the full on-phone behaviour check on every held-out clip that
// tool/build_test_library.py put in assets/test_library/ (cats and dogs the
// classifiers never saw), and shows each result next to the true label.
// One button tests everything; tap a clip to hear it and see the likelihoods.
//
// Pipeline per clip, the same as the app's Check tab will use:
//   WAV (48 kHz mono 16-bit, at most 10 s) -> clap_features (Dart, isolate)
//   -> quantized CLAP ONNX -> 512 numbers scaled to length 1
//   -> logistic regression (classifiers.json) -> likelihood per label.
// It also compares the phone's likelihoods with Python's (manifest.json), so we
// know the phone gives the same answers as the training script.
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:clap_features/clap_features.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:material_ui/material_ui.dart';

const _dir = 'assets/test_library';
const _modelAsset = 'assets/models/clap_audio_quantized.onnx';

const taskTitles = {
  'cat_context': 'Likely feeling',
  'dog_report': 'Likely feeling',
  'dog_arousal': 'Energy',
  'dog_valence': 'Mood',
};

/// CLAP zero-shot sound labels shown as evidence (report 4.2), from sound_evidence.json.
class SoundEvidence {
  SoundEvidence(Map<String, dynamic> j)
      : names = List<String>.from(j['names']),
        species = List<String>.from(j['species']),
        scale = (j['scale'] as num).toDouble(),
        t = (j['T'] as List).map((r) => (r as List).map((v) => (v as num).toDouble()).toList()).toList();
  final List<String> names, species;
  final double scale;
  final List<List<double>> t;

  List<double> probs(List<double> x) {
    final z = [
      for (final row in t) scale * List.generate(x.length, (i) => row[i] * x[i]).fold(0.0, (a, b) => a + b)
    ];
    final m = z.reduce(math.max);
    final e = z.map((v) => math.exp(v - m)).toList();
    final s = e.reduce((a, b) => a + b);
    return e.map((v) => v / s).toList();
  }

  /// Which species the sound alone points to: the group with the most likelihood.
  String speciesOf(List<double> p) {
    final by = <String, double>{};
    for (var i = 0; i < p.length; i++) {
      by[species[i]] = (by[species[i]] ?? 0) + p[i];
    }
    return by.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

class Classifier {
  Classifier(Map<String, dynamic> j)
      : classes = List<String>.from(j['classes']),
        names = List<String>.from(j['names']),
        w = (j['W'] as List).map((r) => (r as List).map((v) => (v as num).toDouble()).toList()).toList(),
        b = (j['b'] as List).map((v) => (v as num).toDouble()).toList();
  final List<String> classes, names;
  final List<List<double>> w;
  final List<double> b;

  List<double> probs(List<double> x) {
    final z = List.generate(b.length, (k) {
      var s = b[k];
      for (var i = 0; i < x.length; i++) {
        s += w[k][i] * x[i];
      }
      return s;
    });
    final m = z.reduce(math.max);
    final e = z.map((v) => math.exp(v - m)).toList();
    final t = e.reduce((a, c) => a + c);
    return e.map((v) => v / t).toList();
  }
}

class Clip {
  Clip(Map<String, dynamic> j)
      : file = j['file'],
        species = j['species'],
        animal = j['animal'],
        seconds = (j['seconds'] as num).toDouble(),
        truth = Map<String, String>.from(j['truth']),
        python = (j['python'] as Map).map((k, v) => MapEntry(k as String, (v as List).map((x) => (x as num).toDouble()).toList()));
  final String file, species, animal;
  final double seconds;
  final Map<String, String> truth;
  final Map<String, List<double>> python;
  Map<String, List<double>>? phone;
  int? ms;
}

/// Reads a 16-bit PCM mono WAV (as written by build_test_library.py) into samples in [-1, 1).
List<double> readWav16(ByteData d) {
  var p = 12; // skip "RIFF" size "WAVE"
  while (p + 8 <= d.lengthInBytes) {
    final id = String.fromCharCodes(d.buffer.asUint8List(d.offsetInBytes + p, 4));
    final size = d.getUint32(p + 4, Endian.little);
    if (id == 'data') {
      final n = size ~/ 2;
      return List.generate(n, (i) => d.getInt16(p + 8 + 2 * i, Endian.little) / 32768.0);
    }
    p += 8 + size + (size & 1);
  }
  throw const FormatException('no data chunk');
}

Float32List _features(List<double> x) => clapInputFeatures(x);

int argmax(List<double> v) {
  var best = 0;
  for (var i = 1; i < v.length; i++) {
    if (v[i] > v[best]) best = i;
  }
  return best;
}

/// Macro F1 over classes 0..k-1.
double macroF1(List<int> yt, List<int> yp, int k) {
  var sum = 0.0;
  for (var c = 0; c < k; c++) {
    var tp = 0, fp = 0, fn = 0;
    for (var i = 0; i < yt.length; i++) {
      if (yp[i] == c && yt[i] == c) tp++;
      if (yp[i] == c && yt[i] != c) fp++;
      if (yp[i] != c && yt[i] == c) fn++;
    }
    sum += tp == 0 ? 0 : 2 * tp / (2 * tp + fp + fn);
  }
  return sum / k;
}

class TestLibraryPage extends StatefulWidget {
  const TestLibraryPage({super.key, this.autorun = false});
  final bool autorun;
  @override
  State<TestLibraryPage> createState() => _TestLibraryPageState();
}

class _TestLibraryPageState extends State<TestLibraryPage> {
  Map<String, Classifier> _clf = {};
  SoundEvidence? _sound;
  List<Clip> _clips = [];
  String _filter = 'all';
  String? _error;
  bool _running = false;
  int _done = 0;
  final _player = AudioPlayer();
  String? _playing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = jsonDecode(await rootBundle.loadString('$_dir/classifiers.json')) as Map<String, dynamic>;
      final m = jsonDecode(await rootBundle.loadString('$_dir/manifest.json')) as List;
      SoundEvidence? sound;
      try {
        sound = SoundEvidence(jsonDecode(await rootBundle.loadString('$_dir/sound_evidence.json')));
      } catch (_) {}
      setState(() {
        _sound = sound;
        _clf = c.map((k, v) => MapEntry(k, Classifier(v)));
        _clips = m.map((j) => Clip(j)).toList();
      });
      if (widget.autorun) _runAll();
    } catch (e) {
      setState(() => _error = 'No test library found. On the Mac, run tool/build_test_library.py first ($e)');
    }
  }

  Future<void> _runAll() async {
    setState(() {
      _running = true;
      _done = 0;
      for (final c in _clips) {
        c.phone = null;
      }
    });
    final session = await OnnxRuntime().createSessionFromAsset(_modelAsset);
    try {
      for (final clip in _clips) {
        final sw = Stopwatch()..start();
        final x = readWav16(await rootBundle.load('$_dir/${clip.file}'));
        final feats = await compute(_features, x);
        final input = await OrtValue.fromList(feats, [1, 1, nFrames, nMels]);
        final outputs = await session.run({'input_features': input});
        final e = (await outputs['audio_embeds']!.asFlattenedList()).map((v) => (v as num).toDouble()).toList();
        await input.dispose();
        for (final v in outputs.values) {
          await v.dispose();
        }
        final norm = math.sqrt(e.fold(0.0, (s, v) => s + v * v));
        final emb = e.map((v) => v / norm).toList();
        clip.phone = {
          for (final t in clip.truth.keys) t: _clf[t]!.probs(emb),
          if (_sound != null) 'sound': _sound!.probs(emb),
        };
        clip.ms = sw.elapsedMilliseconds;
        if (mounted) setState(() => _done++);
      }
    } finally {
      await session.close();
    }
    final s = _summary();
    // ignore: avoid_print
    print('LIBRARY_JSON ${jsonEncode(s)}');
    if (mounted) setState(() => _running = false);
  }

  /// Scores per task on the clips that have been run, plus the largest gap to Python's likelihoods.
  Map<String, dynamic> _summary() {
    final out = <String, dynamic>{};
    var maxGap = 0.0;
    final ms = <int>[];
    for (final t in _clf.keys) {
      final run = _clips.where((c) => c.phone != null && c.truth.containsKey(t)).toList();
      if (run.isEmpty) continue;
      final cls = _clf[t]!.classes;
      final yt = run.map((c) => cls.indexOf(c.truth[t]!)).toList();
      final yp = run.map((c) => argmax(c.phone![t]!)).toList();
      var right = 0;
      for (var i = 0; i < yt.length; i++) {
        if (yt[i] == yp[i]) right++;
      }
      for (final c in run) {
        for (var k = 0; k < cls.length; k++) {
          maxGap = math.max(maxGap, (c.phone![t]![k] - c.python[t]![k]).abs());
        }
      }
      out[t] = {
        'clips': run.length,
        'right': right,
        'accuracy': double.parse((right / run.length).toStringAsFixed(3)),
        'macro_f1': double.parse(macroF1(yt, yp, cls.length).toStringAsFixed(3)),
      };
    }
    if (_sound != null) {
      final run = _clips.where((c) => c.phone?['sound'] != null).toList();
      var right = 0;
      for (final c in run) {
        if (_sound!.speciesOf(c.phone!['sound']!) == c.species) right++;
        final py = c.python['sound'];
        if (py != null) {
          for (var k = 0; k < py.length; k++) {
            maxGap = math.max(maxGap, (c.phone!['sound']![k] - py[k]).abs());
          }
        }
      }
      if (run.isNotEmpty) out['species_from_sound'] = {'clips': run.length, 'right': right};
    }
    for (final c in _clips) {
      if (c.ms != null) ms.add(c.ms!);
    }
    if (ms.isNotEmpty) out['median_ms_per_clip'] = (List.of(ms)..sort())[ms.length ~/ 2];
    out['max_gap_vs_python'] = double.parse(maxGap.toStringAsFixed(4));
    return out;
  }

  Future<void> _play(Clip c) async {
    if (_playing == c.file) {
      await _player.stop();
      setState(() => _playing = null);
      return;
    }
    await _player.stop();
    await _player.play(AssetSource('test_library/${c.file}'));
    setState(() => _playing = c.file);
    _player.onPlayerComplete.first.then((_) {
      if (mounted && _playing == c.file) setState(() => _playing = null);
    });
  }

  Widget _summaryCard() {
    final s = _summary();
    final rows = <Widget>[];
    for (final t in _clf.keys) {
      final r = s[t];
      if (r == null) continue;
      final species = t.startsWith('cat') ? 'Cats' : 'Dogs';
      if (t == 'dog_arousal' || t == 'dog_valence') {
        rows.add(Text('  $species, ${taskTitles[t]}: ${r['right']} of ${r['clips']} right, macro F1 ${r['macro_f1']}',
            style: Theme.of(context).textTheme.bodySmall));
        continue;
      }
      rows.add(Text('$species, ${taskTitles[t]}: ${r['right']} of ${r['clips']} right '
          '(${(100 * r['accuracy']).round()}%), macro F1 ${r['macro_f1']}'));
    }
    if (rows.isEmpty) {
      rows.add(Text('${_clips.length} clips ready: '
          '${_clips.where((c) => c.species == 'cat').length} cat meows, '
          '${_clips.where((c) => c.species == 'dog').length} dog barks, all from animals the model never saw.'));
    } else {
      final sp = s['species_from_sound'];
      if (sp != null) {
        rows.add(Text('Sound evidence names the right animal on ${sp['right']} of ${sp['clips']} clips'));
      }
      rows.add(Text('Chance is about 33% for three labels and 25% for four. '
          'Median ${s['median_ms_per_clip']} ms per clip. '
          'Largest difference from Python: ${s['max_gap_vs_python']}'));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: rows),
      ),
    );
  }

  Widget _tile(Clip c) {
    final lines = <Widget>[];
    var allRight = true;
    for (final t in c.truth.keys) {
      final clf = _clf[t]!;
      final truthName = clf.names[clf.classes.indexOf(c.truth[t]!)];
      if (c.phone == null) {
        lines.add(Text('${taskTitles[t]}: true $truthName'));
        continue;
      }
      final p = c.phone![t]!;
      if (t == 'dog_arousal' || t == 'dog_valence') {
        final k = argmax(p);
        lines.add(Text('${taskTitles[t]}: ${clf.classes[k] == c.truth[t] ? '✓' : '✗'} ${clf.names[k]}, true $truthName',
            style: Theme.of(context).textTheme.bodySmall));
        continue;
      }
      final k = argmax(p);
      final ok = clf.classes[k] == c.truth[t];
      if (t == 'cat_context' || t == 'dog_report') allRight &= ok;
      lines.add(Text('${taskTitles[t]}: ${ok ? '✓' : '✗'} said ${clf.names[k]} ${(100 * p[k]).round()}%, '
          'true $truthName'));
    }
    final sp = c.phone?['sound'];
    if (sp != null && _sound != null) {
      final order = List.generate(sp.length, (i) => i)..sort((a, b) => sp[b].compareTo(sp[a]));
      lines.add(Text('Sounds like: ${order.take(2).map((i) => '${_sound!.names[i]} ${(100 * sp[i]).round()}%').join(', ')}',
          style: Theme.of(context).textTheme.bodySmall));
    }
    return Card(
      child: ExpansionTile(
        leading: IconButton(
          icon: Icon(_playing == c.file ? Icons.stop_circle : Icons.play_circle),
          tooltip: 'Play',
          onPressed: () => _play(c),
        ),
        title: Text('${c.animal} · ${c.seconds.toStringAsFixed(1)} s'),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
        trailing: c.phone == null
            ? null
            : Icon(allRight ? Icons.check_circle : Icons.cancel, color: allRight ? Colors.green : Colors.red),
        children: [
          if (c.phone != null)
            for (final t in c.truth.keys)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(taskTitles[t]!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  for (var k = 0; k < _clf[t]!.classes.length; k++)
                    Row(children: [
                      SizedBox(width: 190, child: Text(_clf[t]!.names[k])),
                      Expanded(child: LinearProgressIndicator(value: c.phone![t]![k])),
                      SizedBox(width: 48, child: Text(' ${(100 * c.phone![t]![k]).round()}%')),
                    ]),
                ]),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(c.file, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _clips.where((c) => _filter == 'all' || c.species == _filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Test library')),
      body: _error != null
          ? Padding(padding: const EdgeInsets.all(16), child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('Real cat and dog sounds the model never trained on. '
                    'Likelihoods only, not a diagnosis.'),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('runAll'),
                  onPressed: _running || _clips.isEmpty ? null : _runAll,
                  child: Text(_running ? 'Testing $_done of ${_clips.length}...' : 'Test all ${_clips.length} clips'),
                ),
                const SizedBox(height: 8),
                _summaryCard(),
                Wrap(spacing: 8, children: [
                  for (final f in ['all', 'cat', 'dog'])
                    ChoiceChip(
                      label: Text({'all': 'All', 'cat': 'Cats', 'dog': 'Dogs'}[f]!),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ]),
                for (final c in shown) _tile(c),
              ],
            ),
    );
  }
}
