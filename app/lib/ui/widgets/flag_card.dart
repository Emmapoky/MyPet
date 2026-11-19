import 'package:material_ui/material_ui.dart';

import '../../detection/change_detector.dart';
import '../../models/pet.dart';
import '../theme.dart';
import '../wording.dart';

/// A change flag with its evidence (FR15) and the no-diagnosis line (FR-N01).
class FlagCard extends StatelessWidget {
  const FlagCard({super.key, required this.flag, required this.pet, this.expanded = false});
  final ChangeFlag flag;
  final Pet pet;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final early = flag.confidence == Confidence.early;
    return Card(
      color: early ? t.colorScheme.surfaceContainerHigh : t.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.insights, color: t.colorScheme.onTertiaryContainer),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Text(Wording.flagHeadline(flag, pet),
                  style: t.textTheme.titleSmall),
            ),
          ]),
          if (expanded) ...[
            const SizedBox(height: Tokens.space3),
            for (final line in Wording.flagEvidence(flag))
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space1),
                child: Text('• $line', style: t.textTheme.bodySmall),
              ),
          ],
          const SizedBox(height: Tokens.space2),
          Text(Wording.notDiagnosis, style: t.textTheme.bodySmall),
        ]),
      ),
    );
  }
}
