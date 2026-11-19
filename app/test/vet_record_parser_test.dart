import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Brightness, MaterialApp, TextField;
import 'package:mypet/models/care_entry.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/ui/health_record_screen.dart';
import 'package:mypet/ui/theme.dart';
import 'package:provider/provider.dart';

import 'app_flow_test.dart' show signedInState;
import 'package:mypet/records/vet_record_parser.dart';

import 'fixtures/vet_samples.dart';

void main() {
  test('vaccination certificate', () {
    final r = parseVetRecord(vetSamples['vaccination-certificate']!);
    expect(r.type, RecordType.vaccination);
    expect(r.date, DateTime(2026, 11, 3));
    expect(r.nextDue, DateTime(2027, 11, 3));
    expect(r.clinic, 'Sunway Paws Veterinary Clinic');
    expect(r.vet, 'Dr Aisha Rahman');
    expect(r.petName, 'Biscuit');
    expect(r.weightKg, 9.8);
    expect(r.vaccines, ['Rabies', 'DHPP', 'Leptospirosis']);
    expect(r.missing, isEmpty);
    expect(r.title, 'Vaccination: Rabies, DHPP, Leptospirosis');
  });

  test('visit summary', () {
    final r = parseVetRecord(vetSamples['visit-summary']!);
    expect(r.type, RecordType.vetVisit);
    expect(r.date, DateTime(2026, 10, 14));
    expect(r.nextDue, DateTime(2026, 10, 28));
    expect(r.clinic, 'Kelana Animal Hospital');
    expect(r.petName, 'Mao');
    expect(r.weightKg, 4.1);
    expect(r.notes, 'Mild dental tartar. Otherwise healthy.');
  });

  test('prescription', () {
    final r = parseVetRecord(vetSamples['prescription']!);
    expect(r.type, RecordType.medicine);
    expect(r.date, DateTime(2026, 9, 21));
    expect(r.clinic, 'Happy Tails Vet');
    expect(r.medicines, ['Meloxicam 1.5mg', 'Amoxicillin 50mg']);
    expect(r.vet, 'Dr. Grace Tan');
  });

  test('lab report', () {
    final r = parseVetRecord(vetSamples['lab-report']!);
    expect(r.type, RecordType.testResults);
    expect(r.date, DateTime(2026, 9, 2));
    expect(r.petName, 'Mochi');
    expect(r.notes, 'All results within reference range.');
  });

  test('missing fields are listed so the app can ask for them', () {
    final r = parseVetRecord('Rabies vaccine given.');
    expect(r.type, RecordType.vaccination);
    expect(r.missing, containsAll(['Date', 'Clinic']));
  });

  test('pounds become kilograms; month-first dates still read', () {
    final r = parseVetRecord('Weight: 22 lb\nDate: 12/31/2026');
    expect(r.weightKg, 10.0);
    expect(r.date, DateTime(2026, 12, 31));
  });

  testWidgets('a vet PDF fills the record and asks for what it lacks', (t) async {
    final s = await signedInState();
    final pet = await s.addPet(name: 'Biscuit', species: Species.dog);
    final text = vetSamples['vaccination-certificate']!.replaceFirst('Sunway Paws Veterinary Clinic\n', '');
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: s,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: HealthRecordScreen(pet: pet, pickPdf: () async => '/x/biscuit-vaccines.pdf', readPdf: (_) async => text),
      ),
    ));
    await t.tap(find.text('Fill from a vet PDF'));
    await t.pumpAndSettle();
    expect(find.textContaining('Filled from biscuit-vaccines.pdf'), findsOneWidget);
    expect(find.textContaining('Please add: Clinic'), findsOneWidget);
    expect(find.text('Not in the PDF'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Clinic'), 'Sunway Paws');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    final r = s.timelineOf(pet.id).ofKind(EntryKind.healthRecord).single;
    expect(r.title, 'Vaccination: Rabies, DHPP, Leptospirosis');
    expect(r.data['clinic'], 'Sunway Paws');
    expect(r.data['vaccines'], ['Rabies', 'DHPP', 'Leptospirosis']);
    expect(r.data['nextDue'], '2027-11-03');
  });
}
