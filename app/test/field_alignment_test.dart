import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mypet/data/local_backend.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/state/app_state.dart';
import 'package:mypet/ui/quick_log_screen.dart';
import 'package:mypet/ui/theme.dart';
import 'package:provider/provider.dart';

// Erwyna's padding rule (20 Nov): "kg" ends where the mic circle ends, both inset from the
// border, and the weight label never touches the number.
void main() {
  for (final scale in [1.0, 1.6]) {
    testWidgets('quick log fields line up on the right (text x$scale)', (t) async {
      t.view.physicalSize = const Size(390 * 3, 844 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final s = AppState(LocalBackend(), detectInBackground: false);
      await s.backend.signIn('', '');
      await t.pump(const Duration(milliseconds: 100));
      final pet = await s.addPet(name: 'Bean', species: Species.cat);
      await t.pumpWidget(ChangeNotifierProvider.value(
        value: s,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
          home: QuickLogScreen(pet: pet),
        ),
      ));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Add a note (optional)'), 200, scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      final kg = t.getRect(find.text('kg'));
      final mic = t.getRect(find.ancestor(of: find.byIcon(Icons.mic_none_rounded), matching: find.byType(IconButton)));
      final box = t.getRect(find.ancestor(of: find.text('kg'), matching: find.byType(Container)).first);
      final label = t.getRect(find.text('Weight (optional)'));
      final hint = t.getRect(find.text('—'));
      expect((kg.right - mic.right).abs(), lessThan(2), reason: 'kg and the mic end at the same inset');
      expect(box.right - kg.right, greaterThanOrEqualTo(Tokens.fieldTrail));
      expect(hint.left - label.right, greaterThanOrEqualTo(Tokens.space3 - 1));
      expect(t.takeException(), isNull);
    });
  }
}
