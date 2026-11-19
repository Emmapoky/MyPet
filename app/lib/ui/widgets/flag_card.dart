import 'package:material_ui/material_ui.dart';

import '../../detection/change_detector.dart';
import '../../models/pet.dart';
import '../theme.dart';
import '../wording.dart';

/// Change flag (Figma Components, "Change flag"): which measure moved, its direction, by how
/// much and over what window (FR15), softer when the baseline is thin (FR16), and the
/// no-diagnosis line (FR-N01). Amber, never red.
class FlagCard extends StatelessWidget {
  const FlagCard({super.key, required this.flag, required this.pet, this.onTap});
  final ChangeFlag flag;
  final Pet pet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final early = flag.confidence == Confidence.early;
    final on = c.onChangeContainer;
    final caption = t.textTheme.bodySmall!.copyWith(color: early ? t.colorScheme.onSurfaceVariant : on);
    final content = Padding(
      padding: const EdgeInsets.all(Tokens.space4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(early ? Icons.help_outline_rounded : Icons.trending_down_rounded, color: on),
          const SizedBox(width: Tokens.space2),
          Expanded(
            child: Text(Wording.flagTitle(flag),
                style: t.textTheme.titleMedium!.copyWith(color: on)),
          ),
        ]),
        const SizedBox(height: Tokens.space2),
        Text(Wording.flagBody(flag, pet), style: t.textTheme.bodyLarge),
        const SizedBox(height: Tokens.space2),
        Text(early ? Wording.flagThinLine(flag) : Wording.flagEvidenceLine(flag), style: caption),
        const SizedBox(height: Tokens.space2),
        Text(Wording.notDiagnosis, style: caption),
      ]),
    );
    return Semantics(
      button: onTap != null,
      child: Material(
        color: early ? t.colorScheme.surface : c.changeContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(Tokens.radiusCard),
          onTap: onTap,
          child: early
              ? CustomPaint(painter: _DashedBorder(on), child: content)
              : content,
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(Tokens.radiusCard));
    final path = Path()..addRRect(rrect.deflate(0.5));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
