// Draws the app icon (the logo's paw on the hero gradient, square, no transparency).
// Run: flutter test test/screens/app_icon_test.dart --run-skipped --update-goldens
// then: python3 tool/make_app_icons.py
@Tags(['screenshots'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mypet/ui/theme.dart';
import 'package:mypet/ui/widgets/logo.dart';

void main() {
  testWidgets('app icon 1024', (t) async {
    t.view.physicalSize = const Size(1024, 1024);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const c = MyPetColors.light;
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        child: Container(
          width: 1024,
          height: 1024,
          decoration: BoxDecoration(gradient: c.heroGradient),
          // Slightly smaller paw than the in-app mark, so iOS's rounded corners never clip it.
          child: Padding(
            padding: const EdgeInsets.all(64),
            child: CustomPaint(painter: PawPainter(dot: c.sun), size: const Size.square(896)),
          ),
        ),
      ),
    ));
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('out/app_icon_1024.png'));
  });
}
