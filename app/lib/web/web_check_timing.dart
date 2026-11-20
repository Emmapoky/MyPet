// Web test build only: a small "how long did this take" line under a check result,
// with a Copy button, so testers can paste it to Erwyna and compare phones.
// Nothing is sent anywhere; the tester decides what to share.
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../behaviour/engine.dart';
import 'web_engine.dart';

@JS('mypetMedia.deviceLine')
external String _deviceLine();

String _s(int ms) => '${(ms / 1000).toStringAsFixed(1)} s';

Widget checkTiming(BuildContext context, {required String? clip}) {
  final e = context.read<BehaviourEngine>();
  final t = e is WebBehaviourEngine ? e.lastTiming : null;
  if (t == null || clip == null || t.clip != clip) return const SizedBox.shrink();
  String device;
  try {
    device = _deviceLine();
  } catch (_) {
    device = 'unknown device';
  }
  final parts = [
    'MyPet web check took ${_s(t.totalMs)}',
    if (t.loadMs > 300) 'incl. ${_s(t.loadMs)} first-time model download',
    'sound ${_s(t.soundMs)}',
    if (t.pictureMs > 0) 'picture ${_s(t.pictureMs)}',
    '${t.clipSeconds.toStringAsFixed(0)} s clip',
    device,
  ];
  final line = parts.join(' · ');
  final th = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: th.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(Icons.timer_outlined, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(line, style: th.textTheme.bodySmall)),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: line));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Copied. Paste it to Erwyna.')));
            }
          },
          child: const Text('Copy'),
        ),
      ]),
    ),
  );
}
