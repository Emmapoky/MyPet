// Behaviour check rules (ML step 10) and the Check tab flow, with small fake
// model files, so they run without the 34 MB model.
import 'dart:typed_data';

import 'dart:ui' show Color, Size;

import 'package:flutter/widgets.dart' show ColoredBox, Widget;

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/behaviour/analysis.dart';
import 'package:mypet/behaviour/engine.dart';
import 'package:mypet/behaviour/model.dart';
import 'package:mypet/models/care_entry.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/ui/app.dart';
import 'package:mypet/ui/check_screen.dart';
import 'package:mypet/ui/feedback.dart';
import 'package:mypet/ui/wording.dart';

import 'app_flow_test.dart' show settle, signedInState;

// 4-number "embeddings": one direction per sound.
const bark = [1.0, 0.0, 0.0, 0.0];
const meow = [0.0, 1.0, 0.0, 0.0];
const purr = [0.0, 0.0, 1.0, 0.0];
const talk = [0.0, 0.0, 0.0, 1.0];
const barkUnclear = [
  0.8,
  0.0,
  0.0,
  0.6,
]; // mostly bark, but the dog feelings are flat

final fakeAnalysis = Analysis(
  sound: SoundEvidence({
    'keys': ['dog_bark', 'cat_meow', 'cat_purr', 'speech'],
    'species': ['dog', 'cat', 'cat', 'other'],
    'names': ['Barking', 'Meowing', 'Purring', 'People talking'],
    'scale': 10,
    'T': [bark, meow, purr, talk],
  }),
  classifiers: {
    'dog_report': Classifier({
      'classes': ['happy', 'calm', 'sad_uneasy', 'upset'],
      'names': [
        'Likely happy or playful',
        'Likely calm',
        'Likely sad or uneasy',
        'Likely upset',
      ],
      'W': [
        [5.0, 0.0, 0.0, -10.0],
        [0.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 0.0],
      ],
      'b': [0.0, 0.0, 0.0, 0.0],
    }),
    'cat_context': Classifier({
      'classes': ['food', 'brushing', 'isolation'],
      'names': [
        'Likely hungry',
        'Likely reacting to handling',
        'Likely stressed in a strange place',
      ],
      'W': [
        [0.0, 5.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 0.0],
      ],
      'b': [0.0, 0.0, 0.0],
    }),
  },
);

class FakeEngine implements BehaviourEngine {
  FakeEngine(this.emb);
  List<double> emb;
  final checked = <String>[];

  @override
  Future<void> load() async {}
  @override
  Future<bool> openCamera() async => true;
  @override
  Widget preview() => const ColoredBox(color: Color(0xFF6B5B4E));
  @override
  Future<void> startRecording() async {}
  @override
  Future<String> stopRecording() async => 'clip.mov';
  @override
  Future<String?> pickFile() async => 'picked.mp4';
  @override
  Future<CheckOutcome> check(
    String wavPath,
    Species species, {
    required bool picked,
  }) async {
    checked.add(wavPath);
    final o = fakeAnalysis.check(emb, species);
    // A few moments like the phone finds: the top pet sound twice, and the pet in view.
    final pet = o.kind != OutcomeKind.notHeard;
    return o.withClip(clip: wavPath, seconds: 8, moments: [
      if (pet) Moment(MomentSource.sound, o.topSound, 1, 3, p: o.sounds.first.$2),
      if (pet) Moment(MomentSource.sound, o.topSound, 5, 6, p: o.sounds.first.$2),
      Moment(MomentSource.picture, species == Species.cat ? 'Cat in view' : 'Dog in view', 0, 7, p: 0.93),
    ]);
  }

  final discarded = <String?>[];
  @override
  Future<void> discard(String? clipPath) async => discarded.add(clipPath);

  @override
  Future<void> dispose() async {}
}

/// The design's phone frame, 390 x 844.
void phoneSize(WidgetTester t) {
  t.view.physicalSize = const Size(390 * 3, 844 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

void main() {
  Feel.sounds = false;
  group('moments in the clip', () {
    test('back-to-back seconds with the same label join into one moment', () {
      final m = mergeMoments([
        const Moment(MomentSource.sound, 'Hissing', 2, 3),
        const Moment(MomentSource.picture, 'Cat in view', 0, 1),
        const Moment(MomentSource.sound, 'Hissing', 3, 4),
        const Moment(MomentSource.sound, 'Purring', 4, 5),
        const Moment(MomentSource.picture, 'Cat in view', 1, 2),
        const Moment(MomentSource.sound, 'Hissing', 7, 8),
      ]);
      expect(m.map((x) => x.toString()), [
        'sound:Hissing@2.0-4.0',
        'sound:Purring@4.0-5.0',
        'sound:Hissing@7.0-8.0',
        'picture:Cat in view@0.0-2.0',
      ]);
    });

    test('only pet sounds that stand out become moments', () {
      final ev = fakeAnalysis.sound;
      expect(soundInWindow(ev, [0.7, 0.1, 0.1, 0.1]), ('Barking', 0.7));
      expect(soundInWindow(ev, [0.1, 0.1, 0.1, 0.7]), isNull); // people talking
      expect(soundInWindow(ev, [0.35, 0.3, 0.3, 0.05]), isNull); // nothing clear
    });

    test('a frame shows a feeling only when the picture is sure', () {
      expect(pictureInFrame('dog', feelings: [('Likely calm', 0.8)]), ('Calm', 0.8));
      expect(pictureInFrame('dog', seenP: 0.9, feelings: [('Likely calm', 0.4)]), ('Dog in view', 0.9));
      expect(pictureInFrame('cat', seenP: 0.8), ('Cat in view', 0.8));
      expect(soundGuess([('Purring', 0.72), ('Meowing', 0.18)]), 'Purring 72%, or maybe meowing 18%');
      expect(soundGuess([('Purring', 0.9), ('Meowing', 0.05)]), 'Purring 90%');
      expect(pictureInFrame('other'), isNull);
    });
  });

  group('decision rules', () {
    test('a clear bark gives a feeling for a dog', () {
      final o = fakeAnalysis.check(bark, Species.dog);
      expect(o.kind, OutcomeKind.feeling);
      expect(o.feelings.first.$1, 'Likely happy or playful');
      expect(o.feelings.first.$2, greaterThan(Analysis.unsureBelow));
      expect(o.sounds.first.$1, 'Barking');
    });

    test('A: a dog pet but the sound is people talking gives no feeling', () {
      final o = fakeAnalysis.check(talk, Species.dog);
      expect(o.kind, OutcomeKind.notHeard);
      expect(o.feelings, isEmpty);
      expect(o.topSound, 'People talking');
    });

    test('A: a bark checked for a cat is "did not clearly hear a cat"', () {
      expect(fakeAnalysis.check(bark, Species.cat).kind, OutcomeKind.notHeard);
    });

    test('B: a purring cat shows the sound, not a feeling', () {
      final o = fakeAnalysis.check(purr, Species.cat);
      expect(o.kind, OutcomeKind.heardOnly);
      expect(o.topSound, 'Purring');
      expect(o.toEntryData(ms: 100, source: 'recording')['heard'], 'Purring');
    });

    test('a meowing cat gets a cat feeling', () {
      final o = fakeAnalysis.check(meow, Species.cat);
      expect(o.kind, OutcomeKind.feeling);
      expect(o.feelings.first.$1, 'Likely hungry');
    });

    test(
      'C: no feeling over 50% is "Not sure", with every likelihood kept',
      () {
        final o = fakeAnalysis.check(barkUnclear, Species.dog);
        expect(o.kind, OutcomeKind.notSure);
        expect(o.feelings.first.$2, lessThan(Analysis.unsureBelow));
        expect(o.feelings, hasLength(4));
        final d = o.toEntryData(ms: 90, source: 'file');
        expect(d['unsure'], isTrue);
        expect((d['likelihoods'] as Map).length, 4);
      },
    );

    test('a saved result never holds audio (FR-N02)', () {
      final d = fakeAnalysis
          .check(bark, Species.dog)
          .toEntryData(ms: 110, source: 'recording');
      expect(d.keys, isNot(anyElement(anyOf('audio', 'clip', 'recording'))));
      expect(d['soundEvidence'], hasLength(3));
    });
  });

  group('picture and sound combined (ML step 11)', () {
    const names = [
      'Likely happy or playful',
      'Likely calm',
      'Likely sad or uneasy',
      'Likely upset',
    ];
    test('no picture model: the sound result is unchanged', () {
      final o = fakeAnalysis.check(bark, Species.dog);
      expect(combine(o, null, soundWeight: 0.6, names: names), same(o));
      expect(o.picture, PictureUse.none);
    });
    test('the picture does not show a dog: sound only, marked as not seen', () {
      final o = combine(
        fakeAnalysis.check(bark, Species.dog),
        PictureReading(species: 'other', feelings: [0, 0, 0, 1]),
        soundWeight: 0.6,
        names: names,
      );
      expect(o.picture, PictureUse.notSeen);
      expect(o.feelings.first.$1, 'Likely happy or playful');
    });
    test('picture and sound are weighted together', () {
      final sound = fakeAnalysis.check(bark, Species.dog);
      final o = combine(
        sound,
        PictureReading(species: 'dog', feelings: [0, 0, 0, 1]),
        soundWeight: 0.6,
        names: names,
      );
      expect(o.picture, PictureUse.combined);
      final happy = sound.feelings.firstWhere((f) => f.$1 == names[0]).$2;
      expect(
        o.feelings.firstWhere((f) => f.$1 == names[0]).$2,
        closeTo(0.6 * happy, 1e-9),
      );
      expect(
        o.feelings.firstWhere((f) => f.$1 == names[3]).$2,
        greaterThan(0.4),
      );
    });
    test(
      'a cat in view only confirms: the feeling still comes from the meow',
      () {
        final o = combine(
          fakeAnalysis.check(meow, Species.cat),
          PictureReading(species: 'cat'),
          soundWeight: 0.6,
          names: const [
            'Likely hungry',
            'Likely reacting to handling',
            'Likely stressed in a strange place',
          ],
        );
        expect(o.picture, PictureUse.confirmed);
        expect(o.feelings.first.$1, 'Likely hungry');
      },
    );
    test('pixels are normalised per channel, channels first', () {
      final m = PictureModel({
        'input': [1, 3, 2, 2],
        'mean': [0.5, 0.5, 0.5],
        'std': [0.5, 0.5, 0.5],
        'gate': {
          'keys': ['dog', 'cat', 'other'],
          'species': ['dog', 'cat', 'other'],
          'scale': 1,
          'T': [
            [1.0],
            [0.0],
            [0.0],
          ],
        },
      });
      final px = m.pixels(
        Uint8List.fromList([
          for (var i = 0; i < 4; i++) ...[255, 0, 255],
        ]),
      );
      expect(px.sublist(0, 4), everyElement(closeTo(1, 1e-6)));
      expect(px.sublist(4, 8), everyElement(closeTo(-1, 1e-6)));
    });
  });

  group('audio helpers', () {
    test('readWav16 reads 16-bit PCM', () {
      final b = BytesBuilder();
      void u32(int v) => b.add(
        (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
      );
      b.add('RIFF'.codeUnits);
      u32(36 + 4);
      b.add('WAVEfmt '.codeUnits);
      u32(16);
      b.add(List.filled(16, 0));
      b.add('data'.codeUnits);
      u32(4);
      b.add(
        (ByteData(4)
              ..setInt16(0, 16384, Endian.little)
              ..setInt16(2, -32768, Endian.little))
            .buffer
            .asUint8List(),
      );
      expect(readWav16(ByteData.sublistView(b.toBytes())), [0.5, -1.0]);
    });

    test('loudest10s keeps the loudest 10 s of a longer file', () {
      const sr = 48000;
      final x = List<double>.filled(sr * 25, 0.0);
      for (var i = sr * 12; i < sr * 22; i++) {
        x[i] = 0.5;
      }
      final y = loudest10s(x);
      expect(y.length, sr * 10);
      expect(y.every((v) => v == 0.5), isTrue);
    });
  });

  test('result title drops "Likely"', () {
    expect(
      Wording.feelingHeadline('Likely happy or playful'),
      'Happy or playful',
    );
  });

  testWidgets(
    'record, see the result, save it to the timeline (Figma 07 to 09)',
    (t) async {
      final s = await signedInState();
      final pet = await s.addPet(name: 'Milo', species: Species.dog);
      phoneSize(t);
      final engine = FakeEngine(bark);
      await t.pumpWidget(MyPetApp(state: s, engine: engine));
      await settle(t);
      await t.tap(find.text('Check'));
      await settle(t);
      expect(find.bySemanticsLabel('Checking Milo. Change pet'), findsOneWidget);
      expect(find.bySemanticsLabel('Checking Milo. Change pet'), findsOneWidget);

      await t.tap(find.bySemanticsLabel('Record a clip of Milo'));
      await t.pump(const Duration(milliseconds: 300)); // start chime
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text('0:01'), findsOneWidget);
      // Stop is off until the clip is 5 s long.
      await t.tap(find.bySemanticsLabel('Stop recording'));
      await t.pump();
      expect(engine.checked, isEmpty);
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      await t.tap(find.bySemanticsLabel('Stop recording'));
      await settle(t);

      expect(engine.checked, ['clip.mov']);
      expect(find.byType(ResultView), findsOneWidget);
      expect(find.text('Happy or playful'), findsOneWidget);
      expect(find.text('0:01 Barking'), findsOneWidget);
    expect(find.text('0:00 Dog in view'), findsOneWidget);
      expect(find.text(Wording.notDiagnosisBehaviour), findsOneWidget);
      await t.scrollUntilVisible(find.textContaining('Clip deleted'), 200);
      expect(find.textContaining('Clip deleted'), findsOneWidget);

      await t.tap(find.text('Save'));
      await settle(t);
      final saved = s.timelineOf(pet.id).ofKind(EntryKind.behaviourResult);
      expect(saved, hasLength(1));
      expect(saved.first.topLabel, 'Likely happy or playful');
    expect(engine.discarded, ['clip.mov']);
    expect(saved.first.data['moments'], hasLength(3));
      expect(s.tab, 2); // stays on Check for the next pet
      expect(find.text("Saved to Milo's timeline"), findsOneWidget);
    },
  );

  testWidgets('A: nothing to save when the dog was not heard', (t) async {
    final s = await signedInState();
    await s.addPet(name: 'Milo', species: Species.dog);
    phoneSize(t);
    await t.pumpWidget(MyPetApp(state: s, engine: FakeEngine(talk)));
    await settle(t);
    await t.tap(find.text('Check'));
    await settle(t);
    await t.tap(find.byTooltip('Choose a video'));
    await settle(t);
    expect(find.text('Did not clearly hear a dog'), findsOneWidget);
    expect(find.textContaining('Closest sound: People talking'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Try again'), 200);
    expect(find.text('Save'), findsNothing);
    await t.tap(find.text('Try again'));
    await settle(t);
    expect(find.bySemanticsLabel('Checking Milo. Change pet'), findsOneWidget);
  });
}
