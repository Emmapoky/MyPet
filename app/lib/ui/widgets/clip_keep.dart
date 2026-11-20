import '../../util/io.dart';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../behaviour/analysis.dart';
import '../../models/care_entry.dart';
import '../../state/app_state.dart';
import '../theme.dart';

/// Short words for each choice, shown in Settings, the sheet and under a result.
String clipKeepTitle(ClipKeep k) => switch (k) {
      ClipKeep.video => 'Video and sound',
      ClipKeep.sound => 'Sound only',
      ClipKeep.none => 'Results only',
    };

String clipKeepDetail(ClipKeep k) => switch (k) {
      ClipKeep.video => 'Replay the whole moment later.',
      ClipKeep.sound => 'The picture is not kept. What it showed is still saved.',
      ClipKeep.none => 'The clip is deleted. What was seen and heard is still saved.',
    };

/// Under a result: what Save keeps.
String clipKeepOnSave(ClipKeep k) => switch (k) {
      ClipKeep.video => 'Save keeps the video on this phone only',
      ClipKeep.sound => 'Save keeps only the sound, on this phone',
      ClipKeep.none => 'Save deletes the clip and keeps the results',
    };

IconData clipKeepIcon(ClipKeep k) => switch (k) {
      ClipKeep.video => Icons.videocam_rounded,
      ClipKeep.sound => Icons.graphic_eq_rounded,
      ClipKeep.none => Icons.lock_rounded,
    };

/// The three choices as radio rows. Clips never leave the phone.
class ClipKeepChoices extends StatelessWidget {
  const ClipKeepChoices({super.key, this.onPicked});
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return RadioGroup<ClipKeep>(
      groupValue: s.clipKeep,
      onChanged: (k) {
        if (k == null) return;
        s.setClipKeep(k);
        onPicked?.call();
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final k in ClipKeep.values)
          RadioListTile<ClipKeep>(
            value: k,
            secondary: Icon(clipKeepIcon(k)),
            title: Text(clipKeepTitle(k)),
            subtitle: Text(clipKeepDetail(k)),
          ),
      ]),
    );
  }
}

Future<void> showClipKeepSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.space4, 0, Tokens.space4, Tokens.space2),
            child: Text('What should Save keep?', style: Theme.of(c).textTheme.titleMedium),
          ),
          ClipKeepChoices(onPicked: () => Navigator.pop(c)),
          Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space4),
            child: Text('Clips stay on this phone and are never uploaded.',
                style: Theme.of(c).textTheme.bodySmall),
          ),
        ]),
      ),
    );

/// Deletes the clip a check kept, once the check itself is deleted for good.
Future<void> deleteKeptClip(AppState s, CareEntry e) async {
  final path = s.clipOf(e);
  if (path == null) return;
  try {
    await File(path).delete();
  } catch (_) {}
}
