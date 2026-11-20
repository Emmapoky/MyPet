import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../behaviour/engine.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import '../state/demo_data.dart';
import '../state/speed_test.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// The app's commit, set at build time: flutter build --dart-define=APP_COMMIT=$(git rev-parse --short HEAD)
const appCommit = String.fromEnvironment('APP_COMMIT');

/// This phone or browser, in words a tester's results can be grouped by.
Future<Map<String, String>> deviceSummary() async {
  try {
    final info = DeviceInfoPlugin();
    if (kIsWeb) {
      final w = await info.webBrowserInfo;
      return {
        'platform': 'web',
        'device': w.platform ?? 'Browser',
        'browser': '${w.browserName.name} ${w.appVersion?.split(' ').first ?? ''}'.trim(),
        'os': w.userAgent ?? '',
      };
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        final i = await info.iosInfo;
        return {
          'platform': 'ios',
          'device': i.modelName.isNotEmpty ? i.modelName : i.utsname.machine,
          'os': '${i.systemName} ${i.systemVersion}',
        };
      case TargetPlatform.android:
        final a = await info.androidInfo;
        return {'platform': 'android', 'device': '${a.manufacturer} ${a.model}', 'os': 'Android ${a.version.release}'};
      case TargetPlatform.macOS:
        final m = await info.macOsInfo;
        return {'platform': 'macos', 'device': m.model, 'os': 'macOS ${m.osRelease}'};
      default:
        return {'platform': defaultTargetPlatform.name, 'device': defaultTargetPlatform.name};
    }
  } catch (_) {
    return {'platform': kIsWeb ? 'web' : defaultTargetPlatform.name, 'device': 'Unknown device'};
  }
}

/// The two bundled clips the speed test checks: a dog (sound and picture) and a cat.
Future<List<SpeedClip>> speedClips() async {
  final clips = await loadDemoClips();
  SpeedClip? pick(String file, String label, Species sp) {
    final c = clips.where((c) => c.file == file).firstOrNull;
    return c == null ? null : SpeedClip(label, sp, () => demoClipCopy(c));
  }

  final dog = pick('dog_dog_bark_01.mp4', 'Dog clip', Species.dog);
  final cat = pick('cat_cat_hiss_10.mp4', 'Cat clip', Species.cat);
  return [
    ?dog,
    ?cat,
    if (dog != null) SpeedClip('Dog clip again', Species.dog, dog.copy),
  ];
}

/// More > Test this phone: times a real behaviour check on two bundled clips, so testers can
/// send Erwyna how long it takes on their phone.
class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key, this.clips, this.device});

  /// For tests: clips and device to use instead of the bundled ones.
  final List<SpeedClip>? clips;
  final Map<String, String>? device;

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  String? step;
  SpeedResult? result;
  String? error;

  Future<void> _run() async {
    final engine = context.read<BehaviourEngine>();
    final s = context.read<AppState>();
    setState(() {
      step = 'Getting ready';
      result = null;
      error = null;
    });
    try {
      final clips = widget.clips ?? await speedClips();
      if (clips.isEmpty) throw const CheckProblem('The test clips are missing from this build.');
      final device = widget.device ?? await deviceSummary();
      final r = await runSpeedTest(engine, clips,
          device: device, now: s.now, app: appCommit, onStep: (t) => mounted ? setState(() => step = t) : null);
      if (mounted) setState(() => result = r);
    } catch (e) {
      if (mounted) setState(() => error = e is CheckProblem ? e.message : 'The test stopped: $e');
    } finally {
      if (mounted) setState(() => step = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = result;
    return Scaffold(
      appBar: AppBar(title: const Text('Test this phone')),
      body: PageWash(
        child: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
          Text(
            'Times a real behaviour check on this phone, with two example clips. Nothing about you or your pets is sent. '
            'Use Wi-Fi the first time on the web link, as the models download once.',
            style: t.textTheme.bodyMedium!.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Tokens.space4),
          if (step != null)
            MyCard(
              child: Row(children: [
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(width: Tokens.space3),
                Expanded(child: Semantics(liveRegion: true, child: Text('$step…', style: t.textTheme.titleSmall))),
              ]),
            )
          else if (r == null)
            FilledButton.icon(onPressed: _run, icon: const Icon(Icons.speed_rounded), label: const Text('Start the test')),
          if (error != null) ...[
            const SizedBox(height: Tokens.space3),
            Text(error!, style: TextStyle(color: t.colorScheme.error)),
          ],
          if (r != null) ...[
            HeroCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.device['device'] ?? 'This phone',
                    style: t.textTheme.titleMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: Tokens.space1),
                Text('A check takes about ${secs(r.typicalCheckMs)}',
                    style: t.textTheme.headlineSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(height: Tokens.space3),
            MyCard(
              child: Column(children: [
                _Line('Model load', secs(r.loadMs)),
                for (final run in r.runs) _Line(run.label, run.ok ? secs(run.ms) : 'failed'),
                const Divider(),
                _Line('Whole test', secs(r.totalMs), bold: true),
              ]),
            ),
            const SizedBox(height: Tokens.space4),
            FilledButton.icon(
              onPressed: () => SharePlus.instance.share(ShareParams(text: r.shareText, subject: 'MyPet speed test')),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send to Erwyna'),
            ),
            const SizedBox(height: Tokens.space2),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: r.shareText));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied. Paste it to Erwyna.')));
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy results'),
            ),
            const SizedBox(height: Tokens.space2),
            TextButton(onPressed: _run, child: const Text('Run again')),
          ],
        ]),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});
  final String label, value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final st = bold ? t.titleSmall : t.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
      child: Row(children: [Expanded(child: Text(label, style: st)), Text(value, style: st)]),
    );
  }
}
