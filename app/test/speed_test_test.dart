import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/state/speed_test.dart';
import 'package:mypet/ui/app.dart';
import 'package:mypet/ui/feedback.dart';
import 'package:mypet/ui/speed_test_screen.dart';

import 'app_flow_test.dart' show settle, signedInState;
import 'behaviour_test.dart' show FakeEngine, bark, phoneSize;

void main() {
  Feel.sounds = false;
  final clips = [
    SpeedClip('Dog clip', Species.dog, () async => 'a.mp4'),
    SpeedClip('Cat clip', Species.cat, () async => 'b.mp4'),
    SpeedClip('Missing clip', Species.cat, () async => null),
  ];
  const device = {'platform': 'ios', 'device': 'iPhone 15', 'os': 'iOS 27.2'};

  test('times the model load and each check, and makes a text to send', () async {
    final r = await runSpeedTest(FakeEngine(bark), clips, device: device, now: () => DateTime(2026, 11, 20), app: 'abc');
    expect(r.runs.map((x) => x.ok), [true, true, false]);
    expect(r.totalMs, r.loadMs + r.runs.fold(0, (a, x) => a + x.ms));
    expect(r.shareText, startsWith('MyPet speed test: iPhone 15'));
    final json = jsonDecode(r.shareText.split('\n').last) as Map<String, dynamic>;
    expect(json['device'], 'iPhone 15');
    expect(json['app'], 'abc');
    expect(json.keys, containsAll(['modelLoadMs', 'check1Ms', 'typicalCheckMs', 'totalMs']));
  });

  testWidgets('More > Test this phone runs and offers Send to Erwyna', (t) async {
    final s = await signedInState();
    phoneSize(t);
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(bark)));
    await settle(t);
    navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => SpeedTestScreen(clips: clips, device: device)));
    await settle(t);
    await t.tap(find.text('Start the test'));
    await settle(t);
    expect(find.text('iPhone 15'), findsOneWidget);
    expect(find.textContaining('A check takes about'), findsOneWidget);
    expect(find.text('Send to Erwyna'), findsOneWidget);
    expect(find.text('Copy results'), findsOneWidget);
  });
}
