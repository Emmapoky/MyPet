import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/detection/change_detector.dart';
import 'package:mypet/detection/synthetic_logs.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/ui/wording.dart';
import 'package:mypet/util/day.dart';

/// FR-N01: no screen shows a disease name. Checks every flag sentence the detector can
/// produce on a large synthetic set against a list of condition words.
const conditionWords = [
  'disease', 'kidney', 'renal', 'diabetes', 'cancer', 'infection', 'arthritis', 'pain',
  'sick', 'illness', 'diagnos', 'syndrome', 'urinary tract', 'blockage', 'thyroid',
];

void main() {
  test('FR-N01: flag wording never names a condition, and always shows evidence (FR15)', () {
    final pet = Pet(
        id: 'p', name: 'Milo', species: Species.dog, carerIds: const ['a'], createdAt: DateTime(2027));
    final first = Day(2027, 1, 1);
    var checked = 0;
    for (var i = 0; i < 90; i++) {
      final m = [Measure.ate, Measure.energy, Measure.toileting][i % 3];
      final logs = SyntheticLogs(i).pet(
          petId: 'p', first: first, days: 45, change: PlantedChange(m, first.addDays(38)));
      for (var d = 30; d < 45; d++) {
        for (final f in const ChangeDetector().run(logs, first.addDays(d)).flags) {
          final text = [Wording.flagHeadline(f, pet), ...Wording.flagEvidence(f)]
              .join(' ')
              .toLowerCase();
          for (final w in conditionWords) {
            expect(text.contains(w), isFalse, reason: '"$w" in: $text');
          }
          expect(text, contains('compared with'));
          checked++;
        }
      }
    }
    expect(checked, greaterThan(50));
    expect(Wording.notDiagnosis, contains('Not a medical diagnosis'));
  });
}
