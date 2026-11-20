import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../feedback.dart';
import '../theme.dart';

/// A part of a page a guide step can point at. When the step names [id], the page scrolls
/// it into view and outlines it, so "this week I had low energy" points at the flag.
class GuideTarget extends StatefulWidget {
  const GuideTarget({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  @override
  State<GuideTarget> createState() => _GuideTargetState();
}

class _GuideTargetState extends State<GuideTarget> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  String? _shownFor;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.select<AppState, (Guide?, int, bool)>((s) => (s.guide, s.guide?.at ?? -1, s.guide?.collapsed ?? false));
    final guide = g.$1;
    final on = guide != null && !g.$3 && guide.steps[g.$2].target == widget.id;
    final key = '${identityHashCode(guide)}:${g.$2}';
    if (on && _shownFor != key) {
      _shownFor = key;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Scrollable.ensureVisible(context,
            alignment: 0.15, duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic);
        if (!mounted) return;
        Feel.spotlight();
        _pulse
          ..reset()
          ..repeat(reverse: true, count: 4);
      });
    } else if (!on && _pulse.isAnimating) {
      _pulse.stop();
    }
    if (!on) _shownFor = null;
    final c = MyPetColors.of(context);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Container(
        foregroundDecoration: on
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(Tokens.radiusCard + 4),
                border: Border.all(color: c.brand.withValues(alpha: 0.55 + 0.45 * _pulse.value), width: 3),
              )
            : null,
        child: child,
      ),
      child: widget.child,
    );
  }
}
