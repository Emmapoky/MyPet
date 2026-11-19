import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/config/thresholds.dart';
import 'package:mypet/detection/change_detector.dart';
import 'package:mypet/models/care_entry.dart';
import 'package:mypet/util/day.dart';

CareEntry log(
  Day d, {
  bool ate = true,
  int energy = 4,
  bool toilet = true,
  double? w,
}) => CareEntry(
  id: d.toString(),
  petId: 'p',
  kind: EntryKind.dailyLog,
  day: d,
  createdAt: d.asDateTime.add(const Duration(hours: 18)),
  createdBy: 't',
  data: {
    'ate': ate,
    'energy': energy,
    'toiletingNormal': toilet,
    'weightKg': ?w,
  },
);

void main() {
  const detector = ChangeDetector();
  final start = Day(2027, 3, 1);

  List<CareEntry> steady(int n) => [
    for (var i = 0; i < n; i++) log(start.addDays(i)),
  ];

  group('NFR07: nothing before 7 days of logs', () {
    test('6 logged days with a big drop gives no flags and is not ready', () {
      final e = [
        ...steady(4),
        log(start.addDays(4), energy: 1, ate: false),
        log(start.addDays(5), energy: 1, ate: false),
      ];
      final r = detector.run(e, start.addDays(5));
      expect(r.ready, isFalse);
      expect(r.flags, isEmpty);
      expect(r.daysUntilReady, 1);
    });

    test('missed days do not count towards the 7', () {
      final e = [for (var i = 0; i < 12; i += 2) log(start.addDays(i))];
      expect(detector.run(e, start.addDays(11)).ready, isFalse);
    });
  });

  group('FR14: change must persist on 2 of the last 3 days', () {
    test('one odd day is not flagged', () {
      final e = [...steady(20), log(start.addDays(20), energy: 1)];
      expect(detector.run(e, start.addDays(20)).flags, isEmpty);
    });

    test('two low days out of three are flagged with evidence (FR15)', () {
      final e = [
        ...steady(20),
        log(start.addDays(20), energy: 2),
        log(start.addDays(21), energy: 4),
        log(start.addDays(22), energy: 2),
      ];
      final r = detector.run(e, start.addDays(22));
      expect(r.flags, hasLength(1));
      final f = r.flags.single;
      expect(f.measure, Measure.energy);
      expect(f.usual, 4);
      expect(f.unusualDays, 2);
      expect(f.recent.map((x) => x.value), [2, 4, 2]);
      expect(f.baselineTo, start.addDays(19));
      expect(f.baselineFrom, start.addDays(19 - Thresholds.baselineDays + 1));
      expect(f.baselineLoggedDays, 20);
      expect(f.confidence, Confidence.normal);
    });
  });

  group('FR-N03: never flag the harmless direction', () {
    test('higher energy is not flagged', () {
      final e = [
        for (var i = 0; i < 20; i++) log(start.addDays(i), energy: 2),
        log(start.addDays(20), energy: 5),
        log(start.addDays(21), energy: 5),
      ];
      expect(detector.run(e, start.addDays(21)).flags, isEmpty);
    });

    test('weight gain is not flagged, weight loss is', () {
      List<CareEntry> withWeights(double a, double b) => [
        for (var i = 0; i < 20; i++) log(start.addDays(i), w: 10),
        log(start.addDays(20), w: a),
        log(start.addDays(21), w: b),
      ];
      expect(
        detector.run(withWeights(11, 11), start.addDays(21)).flags,
        isEmpty,
      );
      final r = detector.run(withWeights(9.3, 9.2), start.addDays(21));
      expect(r.flags.single.measure, Measure.weight);
    });
  });

  group('yes/no measures', () {
    test('not eating on 2 of 3 days is flagged when it is rare', () {
      final e = [
        ...steady(20),
        log(start.addDays(20), ate: false),
        log(start.addDays(21), ate: false),
      ];
      final f = detector.run(e, start.addDays(21)).flags.single;
      expect(f.measure, Measure.ate);
      expect(f.usual, 0);
    });

    test('a pet that often skips meals is not flagged for skipping', () {
      final e = [
        for (var i = 0; i < 20; i++) log(start.addDays(i), ate: i % 3 != 0),
        log(start.addDays(20), ate: false),
        log(start.addDays(21), ate: false),
      ];
      expect(detector.run(e, start.addDays(21)).flags, isEmpty);
    });
  });

  test('FR16: thin baseline makes the flag early', () {
    final e = [
      ...steady(8),
      log(start.addDays(8), toilet: false),
      log(start.addDays(9), toilet: false),
    ];
    final f = detector.run(e, start.addDays(9)).flags.single;
    expect(f.baselineLoggedDays, 7);
    expect(f.confidence, Confidence.early);
  });

  test(
    'baseline excludes the last 3 days and only reaches back 28 days (FR13)',
    () {
      // Energy 1 long ago, then 28 steady days at 4, then two low days.
      final e = [
        for (var i = 0; i < 10; i++) log(start.addDays(i), energy: 1),
        for (var i = 10; i < 38; i++) log(start.addDays(i)),
        log(start.addDays(38), energy: 2),
        log(start.addDays(39), energy: 2),
      ];
      final f = detector.run(e, start.addDays(39)).flags.single;
      expect(f.usual, 4);
      expect(f.baselineLoggedDays, 28);
    },
  );

  test('a later log on the same day replaces the earlier one', () {
    final d = start.addDays(20);
    final e = [
      ...steady(20),
      log(d, energy: 1),
      CareEntry(
        id: 'later',
        petId: 'p',
        kind: EntryKind.dailyLog,
        day: d,
        createdAt: d.asDateTime.add(const Duration(hours: 22)),
        createdBy: 't',
        data: const {'ate': true, 'energy': 4, 'toiletingNormal': true},
      ),
      log(start.addDays(21), energy: 1),
    ];
    expect(detector.run(e, start.addDays(21)).flags, isEmpty);
  });

  test('median handles odd and even counts', () {
    expect(ChangeDetector.median([3, 1, 2]), 2);
    expect(ChangeDetector.median([4, 1, 2, 3]), 2.5);
  });
}
