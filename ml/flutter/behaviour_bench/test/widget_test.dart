import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:behaviour_bench/main.dart';

void main() {
  testWidgets('shows the run button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BenchPage()));
    expect(find.text('Run timing test'), findsOneWidget);
  });

  test('test signals have the expected lengths', () {
    expect(testSignal('short_tone').length, 72000);
    expect(testSignal('chirp_10s').length, 480000);
    expect(testSignal('long_12s').length, 576000);
  });
}
