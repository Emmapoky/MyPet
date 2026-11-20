import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/records/demo_documents.dart';
import 'package:mypet/records/vet_record_parser.dart';

void main() {
  VetRecord read(String file) => parseVetRecord(demoDocuments.firstWhere((d) => d.file == file).text);

  test('every demo document is read for the right pet, and the complete ones need nothing added', () {
    for (final d in demoDocuments.where((d) => d.pet != null)) {
      final r = parseVetRecord(d.text);
      expect(r.petName, d.pet, reason: d.file);
      expect(r.date != null || d.shows.contains('No date'), isTrue, reason: d.file);
      if (d.shows.startsWith('Complete')) expect(r.missing, isEmpty, reason: d.file);
    }
  });

  test('the tricky demo documents show what they are meant to', () {
    expect(read('bean-first-check.pdf').missing, containsAll(['Date', 'Clinic']));
    expect(read('pepper-microchip.pdf').missing, contains('Type'));
    expect(read('luna-visit-other-pet.pdf').petName, 'Luna');
    expect(read('biscuit-vaccination-2026.pdf').vaccines, ['Rabies', 'DHPP', 'Leptospirosis']);
    expect(read('mochi-dental-procedure.pdf').type, RecordType.surgery);
    expect(read('biscuit-blood-test.pdf').type, RecordType.testResults);
  });

  test('medicines sold by brand name are picked out, with a dose when one is written', () {
    expect(read('pepper-parasite-prevention.pdf').medicines, ['Milbemax', 'NexGard Spectra']);
    expect(read('bean-flea-treatment.pdf').medicines, ['Revolution Plus']);
    expect(read('mochi-prescription.pdf').medicines, ['Mirtazapine 2mg', 'Buprenorphine 0.3mg']);
    expect(read('biscuit-prescription.pdf').medicines, ['Meloxicam 1.5mg', 'Gabapentin 100mg']);
  });
}
