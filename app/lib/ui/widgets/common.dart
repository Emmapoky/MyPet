import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// A card with the design's padding and shadow, and an optional heading.
class MyCard extends StatelessWidget {
  const MyCard({super.key, this.title, required this.child, this.padding});
  final String? title;
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: padding ?? const EdgeInsets.all(Tokens.space4),
          child: title == null
              ? child
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Semantics(
                    header: true,
                    child: Text(title!, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: Tokens.space3),
                  child,
                ]),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, Tokens.space5, 0, Tokens.space2),
        child: Row(children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          ?trailing,
        ]),
      );
}

/// Empty state (Figma Components): 72 px circle with an icon, heading, body, optional action.
class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.icon, required this.title, required this.body, this.action, this.extra});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: t.colorScheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: t.colorScheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Text(title, style: t.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Tokens.space2),
          Text(body,
              style: t.textTheme.bodyLarge!.copyWith(color: t.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          if (extra != null) ...[const SizedBox(height: Tokens.space4), extra!],
          if (action != null) ...[const SizedBox(height: Tokens.space4), action!],
        ]),
      ),
    );
  }
}

/// Choice chip (Figma Components): min 48 high, radius 12; when on, primary fill with a
/// tick so the choice is not shown by colour alone.
class AnswerChip extends StatelessWidget {
  const AnswerChip(
      {super.key, required this.label, required this.selected, required this.onTap, this.semantic});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final fg = selected ? t.colorScheme.onPrimary : t.colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: semantic ?? label,
      excludeSemantics: true,
      child: Tooltip(
        message: semantic ?? label,
        excludeFromSemantics: true,
        child: Material(
          color: selected ? t.colorScheme.primary : t.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusInput),
            side: selected ? BorderSide.none : BorderSide(color: t.colorScheme.outline),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Tokens.radiusInput),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Tokens.minTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space2, vertical: Tokens.space2),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (selected) ...[
                    Icon(Icons.check_rounded, size: 20, color: fg),
                    const SizedBox(width: Tokens.space1),
                  ],
                  Flexible(
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: t.textTheme.titleSmall!.copyWith(color: fg)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A question with answer chips. With [expand] the chips share the row equally (Quick log);
/// otherwise they wrap.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.number,
    this.expand = false,
  });
  final String label;
  final int? number;
  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final chips = [
      for (final (value, text) in options)
        AnswerChip(
          label: text,
          semantic: '$label: $text',
          selected: selected == value,
          onTap: () => onSelected(value),
        ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (number != null) ...[
          ExcludeSemantics(
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.colorScheme.onSurface, shape: BoxShape.circle),
              child: Text('$number',
                  style: t.textTheme.labelMedium!.copyWith(color: t.colorScheme.surface)),
            ),
          ),
          const SizedBox(width: Tokens.space2),
        ],
        Expanded(child: Text(label, style: t.textTheme.titleSmall)),
      ]),
      const SizedBox(height: Tokens.space2),
      if (expand)
        Row(children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: Tokens.space2),
            Expanded(child: chips[i]),
          ],
        ])
      else
        Wrap(spacing: Tokens.space2, runSpacing: Tokens.space2, children: chips),
    ]);
  }
}
