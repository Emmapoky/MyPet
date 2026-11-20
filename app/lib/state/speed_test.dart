import 'dart:convert';

import '../behaviour/engine.dart';
import '../models/pet.dart';

/// One clip timed in the phone speed test.
class SpeedRun {
  const SpeedRun(this.label, this.ms, {this.ok = true, this.answer});
  final String label;
  final int ms;
  final bool ok;
  final String? answer;
}

/// What a phone speed test found: how long the behaviour check takes on this device.
class SpeedResult {
  SpeedResult({required this.device, required this.loadMs, required this.runs, required this.at, this.app = ''});
  final Map<String, String> device;
  final int loadMs;
  final List<SpeedRun> runs;
  final DateTime at;
  final String app;

  int get totalMs => loadMs + runs.fold(0, (a, r) => a + r.ms);

  /// The average of the warm checks (all but the first), or the only one.
  int get typicalCheckMs {
    final warm = runs.length > 1 ? runs.skip(1) : runs;
    return warm.isEmpty ? 0 : (warm.fold(0, (a, r) => a + r.ms) / warm.length).round();
  }

  Map<String, dynamic> toJson() => {
        'app': app,
        ...device,
        'modelLoadMs': loadMs,
        for (final (i, r) in runs.indexed) 'check${i + 1}Ms': r.ms,
        'typicalCheckMs': typicalCheckMs,
        'totalMs': totalMs,
        'at': at.toIso8601String(),
      };

  /// The text a tester sends: readable first, then one JSON line to paste into a sheet.
  String get shareText {
    final name = device['device'] ?? 'Unknown device';
    final b = StringBuffer()
      ..writeln('MyPet speed test: $name')
      ..writeln([device['os'], device['browser']].whereType<String>().where((s) => s.isNotEmpty).join(', '))
      ..writeln('Model load: ${secs(loadMs)}');
    for (final r in runs) {
      b.writeln('${r.label}: ${secs(r.ms)}${r.ok ? '' : ' (failed)'}');
    }
    b
      ..writeln('A check usually takes: ${secs(typicalCheckMs)}')
      ..writeln('Whole test: ${secs(totalMs)}')
      ..writeln()
      ..write(jsonEncode(toJson()));
    return b.toString();
  }
}

String secs(int ms) => '${(ms / 1000).toStringAsFixed(1)} s';

/// A clip for the speed test: what to call it, its species and how to get a fresh copy.
class SpeedClip {
  const SpeedClip(this.label, this.species, this.copy);
  final String label;
  final Species species;
  final Future<String?> Function() copy;
}

/// Times loading the model, then a real check on each clip. [onStep] reports progress.
Future<SpeedResult> runSpeedTest(
  BehaviourEngine engine,
  List<SpeedClip> clips, {
  required Map<String, String> device,
  required DateTime Function() now,
  String app = '',
  void Function(String step)? onStep,
}) async {
  final watch = Stopwatch()..start();
  onStep?.call('Loading the model');
  await engine.load();
  final loadMs = watch.elapsedMilliseconds;
  final runs = <SpeedRun>[];
  for (final c in clips) {
    onStep?.call('Checking ${c.label.toLowerCase()}');
    final path = await c.copy();
    if (path == null) {
      runs.add(SpeedRun(c.label, 0, ok: false));
      continue;
    }
    watch.reset();
    try {
      final o = await engine.check(path, c.species, picked: true);
      runs.add(SpeedRun(c.label, watch.elapsedMilliseconds, answer: o.feelings.isNotEmpty ? o.feelings.first.$1 : (o.sounds.isNotEmpty ? o.topSound : null)));
      await engine.discard(o.clip);
    } catch (_) {
      runs.add(SpeedRun(c.label, watch.elapsedMilliseconds, ok: false));
    }
  }
  return SpeedResult(device: device, loadMs: loadMs, runs: runs, at: now(), app: app);
}
