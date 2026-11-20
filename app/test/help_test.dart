import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/ui/help_screen.dart';

void main() {
  test('the in-app guide is the same as docs/MyPet Guide.md and has every section', () {
    final app = File('assets/guide/guide.md').readAsStringSync();
    expect(app, File('../docs/MyPet Guide.md').readAsStringSync(),
        reason: 'Copy docs/MyPet Guide.md to app/assets/guide/guide.md after editing it');
    final titles = guideSections(app).map((s) => s.$1).toList();
    expect(titles, containsAll(['How to use MyPet', 'FAQ (as a new owner would ask)', 'Limits, honestly']));
    expect(app, isNot(contains('diagnosis:')));
  });
}
