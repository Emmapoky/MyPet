import 'package:material_ui/material_ui.dart';

import '../theme.dart';

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

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space5),
        child: Column(children: [
          Icon(icon, size: 40, color: t.colorScheme.primary),
          const SizedBox(height: Tokens.space3),
          Text(title, style: t.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Tokens.space2),
          Text(body, style: t.textTheme.bodyMedium, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: Tokens.space4), action!],
        ]),
      ),
    );
  }
}

/// A row of choices, one of which can be picked. Each is at least 48 x 48 (NFR05).
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.number,
  });
  final String label;
  final int? number;
  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (number != null) ...[
          CircleAvatar(
            radius: 12,
            backgroundColor: t.colorScheme.primary,
            child: Text('$number',
                style: t.textTheme.labelMedium!.copyWith(color: t.colorScheme.onPrimary)),
          ),
          const SizedBox(width: Tokens.space2),
        ],
        Expanded(child: Text(label, style: t.textTheme.titleSmall)),
      ]),
      const SizedBox(height: Tokens.space2),
      Wrap(spacing: Tokens.space2, runSpacing: Tokens.space2, children: [
        for (final (value, text) in options)
          ChoiceChip(
            label: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 32),
              child: Text(text, textAlign: TextAlign.center),
            ),
            selected: selected == value,
            showCheckmark: false,
            onSelected: (_) => onSelected(value),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            tooltip: '$label: $text',
          ),
      ]),
    ]);
  }
}
