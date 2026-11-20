// Every word inside a card sits at least 8 px in from the card's edges, on every main
// screen, at normal and at large text (Erwyna, 20 Nov: "Thu" was touching the card edge).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mypet/state/demo_data.dart';
import 'package:mypet/ui/app.dart';
import 'package:mypet/ui/feedback.dart';
import 'package:mypet/ui/pet_detail_screen.dart';
import 'package:mypet/ui/settings_screen.dart';

import 'app_flow_test.dart' show settle, signedInState;
import 'behaviour_test.dart' show FakeEngine, bark, phoneSize;

List<String> cramped(WidgetTester t) {
  final bad = <String>[];
  for (final card in find.byType(Card, skipOffstage: false).evaluate()) {
    final cb = card.renderObject;
    if (cb is! RenderBox || !cb.hasSize || !cb.attached) continue;
    final cr = cb.localToGlobal(Offset.zero) & cb.size;
    void visit(Element e) {
      final w = e.widget;
      if (w is RichText) {
        final rb = e.renderObject;
        if (rb is RenderBox && rb.hasSize && rb.size.width > 0) {
          final r = rb.localToGlobal(Offset.zero) & rb.size;
          final left = r.left - cr.left, right = cr.right - r.right;
          if (left < 8 || right < 8 || r.top - cr.top < 4) {
            bad.add('"${w.text.toPlainText()}" ${left.toStringAsFixed(0)} px from the left, ${right.toStringAsFixed(0)} px from the right');
          }
        }
      }
      e.visitChildren(visit);
    }

    card.visitChildren(visit);
  }
  return bad;
}

void main() {
  Feel.sounds = false;
  for (final scale in [1.0, 1.6]) {
    testWidgets('no text touches a card edge (text size $scale)', (t) async {
      phoneSize(t);
      final s = await signedInState();
      await addDemoPets(s, fixedIds: true);
      await t.pumpWidget(MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), textScaler: TextScaler.linear(scale)),
        child: MyPetApp(state: s, engine: FakeEngine(bark)),
      ));
      await settle(t);
      final problems = <String>[];
      for (var tab = 0; tab < 5; tab++) {
        s.goToTab(tab);
        await settle(t);
        problems.addAll(cramped(t).map((p) => 'tab $tab: $p'));
      }
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      for (final p in s.activePets) {
        nav.push(MaterialPageRoute<void>(builder: (_) => PetDetailScreen(petId: p.id)));
        await settle(t);
        problems.addAll(cramped(t).map((x) => '${p.name} page: $x'));
        nav.pop();
        await settle(t);
      }
      nav.push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      await settle(t);
      problems.addAll(cramped(t).map((x) => 'Settings: $x'));
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}
