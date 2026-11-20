import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';

import 'theme.dart';
import 'widgets/common.dart';

/// "Guide and FAQ": the full MyPet guide (docs/MyPet Guide.md, bundled as
/// assets/guide/guide.md), one section per heading, opened one at a time.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guide and FAQ')),
      body: PageWash(
        child: FutureBuilder<String>(
          future: rootBundle.loadString('assets/guide/guide.md'),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final sections = guideSections(snap.data!);
            return ListView(
              padding: const EdgeInsets.all(Tokens.space4),
              children: [
                for (final (i, sec) in sections.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Tokens.space3),
                    child: MyCard(
                      padding: EdgeInsets.zero,
                      child: ExpansionTile(
                        initiallyExpanded: i == 0,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        tilePadding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
                        childrenPadding: const EdgeInsets.fromLTRB(Tokens.space4, 0, Tokens.space4, Tokens.space4),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        title: Text(sec.$1, style: Theme.of(context).textTheme.titleMedium),
                        children: [for (final l in sec.$2) _line(context, l)],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String l) {
    final t = Theme.of(context);
    final body = t.textTheme.bodyLarge!;
    if (l.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: Tokens.space3, bottom: Tokens.space1),
        child: Semantics(header: true, child: Text(l.substring(4), style: t.textTheme.titleSmall)),
      );
    }
    final bullet = l.startsWith('- ') ? '•' : RegExp(r'^\d+\. ').stringMatch(l)?.trim();
    final text = bullet == null ? l : l.substring(l.indexOf(' ') + 1);
    final rich = Text.rich(_bold(text, body), style: body);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space2),
      child: bullet == null
          ? rich
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 24, child: Text(bullet, style: body)),
              Expanded(child: rich),
            ]),
    );
  }

  static TextSpan _bold(String s, TextStyle base) {
    final parts = s.split('**');
    return TextSpan(children: [
      for (var i = 0; i < parts.length; i++)
        TextSpan(text: parts[i], style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w700) : null),
    ]);
  }
}

/// Splits the guide into (heading, lines) by "## " headings. Tables become one line per
/// row; rules and the top title are dropped.
List<(String, List<String>)> guideSections(String md) {
  final out = <(String, List<String>)>[];
  List<String>? cur;
  for (final raw in md.split('\n')) {
    final l = raw.trimRight();
    if (l.startsWith('## ')) {
      cur = [];
      out.add((l.substring(3).replaceFirst(RegExp(r'^\d+\. '), ''), cur));
      continue;
    }
    if (cur == null || l.isEmpty || l == '---') continue;
    if (l.startsWith('|')) {
      if (RegExp(r'^\|[\s\-|]+\|$').hasMatch(l)) continue;
      final cells = l.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      cur.add('- ${cells.join(' · ')}');
      continue;
    }
    cur.add(l);
  }
  return out;
}
