// MyPet ML Lab (FIT3162). A test app for the ML team, separate from the MyPet app.\n// Started as the timing bench (ML step 3).
//
// Measures, on a real phone, how long the behaviour check takes from
// "10 s clip finished" to "512-number embedding ready":
//   1. turn the clip into the model input (clap_features, Dart, in an isolate)
//   2. run the CLAP audio encoder (quantized ONNX, 34.3 MB) with ONNX Runtime
// Target from the report (FR20 / NFR03): under 5 s.
//
// It also checks the phone's embeddings against ones computed in Python on the
// same test signals (assets/expected_embeddings.json), so we know the on-phone
// pipeline gives the right numbers, not just fast ones.
import 'dart:convert';
import 'dart:math' as math;

import 'package:clap_features/clap_features.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'test_library.dart';
import 'try_live.dart';

const modelAsset = 'assets/models/clap_audio_quantized.onnx';
const signals = ['short_tone', 'chirp_10s', 'long_12s'];
const repeats = 5;

// Same formulas as test_signal() in ml/reference/clap_features.py
List<double> testSignal(String name) {
  const sr = sampleRate;
  switch (name) {
    case 'short_tone':
      return List.generate((1.5 * sr).toInt(), (i) {
        final t = i / sr;
        return 0.5 * math.sin(2 * math.pi * 440 * t) + 0.25 * math.sin(2 * math.pi * 1000 * t);
      });
    case 'chirp_10s':
      return List.generate(nSamples, (i) {
        final t = i / sr;
        return 0.3 * math.sin(2 * math.pi * (100 * t + (12000 - 100) / (2 * 10) * t * t));
      });
    case 'long_12s':
      return List.generate(12 * sr, (i) {
        final t = i / sr;
        return t < 6 ? 0.4 * math.sin(2 * math.pi * 300 * t) : 0.4 * math.sin(2 * math.pi * 2500 * t);
      });
  }
  throw ArgumentError(name);
}

Float32List _features(String name) => clapInputFeatures(testSignal(name));

double cosine(List<double> a, List<double> b) {
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return dot / (math.sqrt(na) * math.sqrt(nb));
}

int median(List<int> xs) => (List.of(xs)..sort())[xs.length ~/ 2];

// Colours from the MyPet app (design/mypet-tokens-v2.json), so the Lab looks like part of the project.
const coralDeep = Color(0xFFC9452F);
const coral = Color(0xFFE8684B);
const teal = Color(0xFF17706F);
const pageTop = Color(0xFFFFF2EB);
const pageBottom = Color(0xFFEDF7F7);
const ink = Color(0xFF2B1D1A);

void main() => runApp(MaterialApp(
      title: 'MyPet ML Lab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: teal),
        scaffoldBackgroundColor: pageTop,
        appBarTheme: const AppBarTheme(backgroundColor: pageTop, foregroundColor: ink),
      ),
      // --dart-define=AUTORUN=true opens and starts the timing test,
      // --dart-define=AUTORUN_LIBRARY=true opens and starts the test library.
      home: const bool.fromEnvironment('AUTORUN_LIBRARY')
          ? const TestLibraryPage(autorun: true)
          : const bool.fromEnvironment('AUTORUN')
              ? const BenchPage()
              : const HomePage(),
    ));

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _section(BuildContext context, IconData icon, String title, String subtitle, Widget page) => Card(
        color: Colors.white,
        child: ListTile(
          leading: CircleAvatar(backgroundColor: teal.withValues(alpha: 0.12), child: Icon(icon, color: teal)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [pageTop, pageBottom])),
          child: SafeArea(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(colors: [coralDeep, coral]),
                ),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [
                  Text('MyPet ML Lab',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  Text('For Li Shen and the ML team. Not part of the MyPet app.',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                ]),
              ),
              const SizedBox(height: 16),
              _section(context, Icons.library_music, 'Test library',
                  'Held-out cats and dogs plus online clips, scored against the true labels',
                  const TestLibraryPage()),
              _section(context, Icons.videocam, 'Try a clip',
                  'Record near a pet, or pick a video. Same check as the app', const TryLivePage()),
              _section(context, Icons.timer, 'Timing', 'How fast the check runs on this phone', const BenchPage()),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('How to retrain and test: ml/README.md, "For Li Shen".',
                    style: TextStyle(color: Color(0xFF6E5F5A))),
              ),
            ]),
          ),
        ),
      );
}

class BenchPage extends StatefulWidget {
  const BenchPage({super.key});
  @override
  State<BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<BenchPage> {
  final _log = <String>[];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    // flutter run --dart-define=AUTORUN=true starts the test without a tap
    if (const bool.fromEnvironment('AUTORUN')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  void _say(String s) {
    debugPrint(s);
    setState(() => _log.add(s));
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _log.clear();
    });
    final result = <String, dynamic>{};
    try {
      Map<String, dynamic> expected = {};
      try {
        expected = jsonDecode(await rootBundle.loadString('assets/expected_embeddings.json'));
      } catch (_) {
        _say('No expected_embeddings.json: correctness check skipped');
      }

      var sw = Stopwatch()..start();
      final ort = OnnxRuntime();
      final session = await ort.createSessionFromAsset(modelAsset);
      result['model_load_ms'] = sw.elapsedMilliseconds;
      _say('Model loaded in ${sw.elapsedMilliseconds} ms');

      for (final name in signals) {
        final featMs = <int>[], inferMs = <int>[], totalMs = <int>[];
        List<double>? emb;
        final n = name == 'chirp_10s' ? repeats : 2;
        for (var r = 0; r < n; r++) {
          final total = Stopwatch()..start();
          sw = Stopwatch()..start();
          final feats = await compute(_features, name); // off the UI thread, like the app will
          featMs.add(sw.elapsedMilliseconds);

          sw = Stopwatch()..start();
          final input = await OrtValue.fromList(feats, [1, 1, nFrames, nMels]);
          final outputs = await session.run({'input_features': input});
          final out = outputs['audio_embeds']!;
          emb = (await out.asFlattenedList()).map((v) => (v as num).toDouble()).toList();
          inferMs.add(sw.elapsedMilliseconds);
          totalMs.add(total.elapsedMilliseconds);
          await input.dispose();
          for (final v in outputs.values) {
            await v.dispose();
          }
        }
        final row = <String, dynamic>{
          'runs': n,
          'features_ms_first': featMs.first,
          'inference_ms_first': inferMs.first,
          'total_ms_first': totalMs.first,
          'total_ms_median': median(totalMs),
          'features_ms_median': median(featMs),
          'inference_ms_median': median(inferMs),
          'embedding_length': emb!.length,
        };
        if (expected[name] != null) {
          row['cosine_vs_python'] = double.parse(
              cosine(emb, (expected[name] as List).map((v) => (v as num).toDouble()).toList()).toStringAsFixed(5));
        }
        result[name] = row;
        _say('$name: total ${row['total_ms_median']} ms median '
            '(features ${row['features_ms_median']}, model ${row['inference_ms_median']}); '
            'first run ${row['total_ms_first']} ms'
            '${row.containsKey('cosine_vs_python') ? '; cosine vs Python ${row['cosine_vs_python']}' : ''}');
      }
      await session.close();
      final worst = signals.map((s) => result[s]['total_ms_first'] as int).reduce(math.max);
      result['worst_first_run_ms'] = worst;
      result['meets_5s_target'] = worst < 5000;
      _say(worst < 5000 ? 'PASS: every result in under 5 s' : 'FAIL: slower than 5 s');
    } catch (e, st) {
      result['error'] = '$e';
      _say('Error: $e');
      debugPrint('$st');
    }
    result['build_mode'] = kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug');
    // ignore: avoid_print
    print('BENCH_JSON ${jsonEncode(result)}');
    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Timing')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Runs the CLAP audio model on three 10 s test sounds and times it. Target: under 5 s.'),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('run'),
              onPressed: _running ? null : _run,
              child: Text(_running ? 'Running...' : 'Run timing test'),
            ),
            const SizedBox(height: 12),
            for (final line in _log) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(line)),
          ],
        ),
      );
}
