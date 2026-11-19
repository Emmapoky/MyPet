import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/local_backend.dart';
import 'package:mypet/models/care_entry.dart';
import 'package:mypet/models/timeline.dart';
import 'package:mypet/util/day.dart';

CareEntry e(
  String id, {
  String? sup,
  bool voided = false,
  int min = 0,
  int energy = 4,
  Day? day,
}) => CareEntry(
  id: id,
  petId: 'p',
  kind: EntryKind.dailyLog,
  day: day ?? Day(2027, 3, 1),
  createdAt: DateTime.utc(2027, 3, 1, 10, min),
  createdBy: 'a',
  supersedes: sup,
  voided: voided,
  data: {'energy': energy},
);

void main() {
  test('FR03: newest day first', () {
    final t = Timeline.resolve([
      e('a', day: Day(2027, 3, 1)),
      e('b', day: Day(2027, 3, 3)),
      e('c', day: Day(2027, 3, 2)),
    ]);
    expect(t.current.map((x) => x.id), ['b', 'c', 'a']);
  });

  test(
    'an edit replaces the old version in the timeline but keeps it stored',
    () {
      final t = Timeline.resolve([
        e('a'),
        e('a2', sup: 'a', min: 5, energy: 2),
      ]);
      expect(t.current.single.id, 'a2');
      expect(t.current.single.energy, 2);
    },
  );

  test('a delete hides the entry', () {
    final t = Timeline.resolve([
      e('a'),
      e('a2', sup: 'a', min: 5, voided: true),
    ]);
    expect(t.current, isEmpty);
  });

  test('FR09 and FR-N04: two edits at once give the same winner everywhere and keep the loser', () {
    final x = e('x', sup: 'a', min: 5, energy: 1);
    final y = e('y', sup: 'a', min: 6, energy: 2);
    final one = Timeline.resolve([e('a'), x, y]);
    final two = Timeline.resolve([y, x, e('a')]);
    expect(one.current.single.id, 'y');
    expect(two.current.single.id, 'y');
    expect(one.conflicts.single.id, 'x');
  });

  test('FR05: last daily log is offered for "same as last entry"', () {
    final t = Timeline.resolve([
      e('a', day: Day(2027, 3, 1)),
      e('b', day: Day(2027, 3, 2)),
    ]);
    expect(t.lastDailyLog!.id, 'b');
  });

  test(
    'local backend refuses to overwrite an entry and checks ranges (4.4)',
    () async {
      final b = LocalBackend();
      await b.addEntry(e('a'));
      expect(() => b.addEntry(e('a')), throwsStateError);
      expect(() => b.addEntry(e('z', energy: 9)), throwsArgumentError);
    },
  );
}
