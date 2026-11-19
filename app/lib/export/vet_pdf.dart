import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../detection/change_detector.dart';
import '../models/care_entry.dart';
import '../models/pet.dart';
import '../models/timeline.dart';
import '../ui/wording.dart';
import '../util/day.dart';

/// A pet's record over a date range as a PDF that opens without the app (FR04).
/// Built on the phone with the free pdf package; nothing is uploaded.
Future<Uint8List> buildVetPdf({
  required Pet pet,
  required Timeline timeline,
  required DetectionResult? detection,
  required Day from,
  required Day to,
  required DateTime now,
}) {
  final doc = pw.Document(title: 'MyPet record: ${pet.name}', author: 'MyPet');
  final teal = PdfColor.fromInt(0xFF0E6B73);
  final grey = PdfColor.fromInt(0xFF4F5B5E);
  final inRange = timeline.current
      .where((e) => !e.day.isBefore(from) && !e.day.isAfter(to))
      .toList();
  final logs = inRange.where((e) => e.kind == EntryKind.dailyLog).toList().reversed.toList();
  final other = inRange.where((e) => e.kind != EntryKind.dailyLog).toList().reversed.toList();
  final d = DateFormat('d MMM y');
  String day(Day x) => DateFormat('EEE d MMM').format(x.asDateTime);

  final profile = [
    pet.species == Species.cat ? 'Cat' : 'Dog',
    if (pet.breed.isNotEmpty) pet.breed,
    if (pet.birthDate != null) 'born ${d.format(pet.birthDate!.asDateTime)}',
    if (pet.weightKg != null) '${pet.weightKg} kg (profile)',
  ].join(' · ');

  final days = to.difference(from) + 1;
  final loggedDays = {for (final e in logs) e.day}.length;

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    header: (c) => pw.Row(children: [
      pw.Text('MyPet', style: pw.TextStyle(color: teal, fontWeight: pw.FontWeight.bold)),
      pw.Spacer(),
      pw.Text('${pet.name} · ${d.format(from.asDateTime)} to ${d.format(to.asDateTime)}',
          style: pw.TextStyle(color: grey, fontSize: 9)),
    ]),
    footer: (c) => pw.Row(children: [
      pw.Expanded(
        child: pw.Text('Written by the owner in MyPet. ${Wording.notDiagnosis}',
            style: pw.TextStyle(color: grey, fontSize: 8)),
      ),
      pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: pw.TextStyle(color: grey, fontSize: 8)),
    ]),
    build: (c) => [
      pw.SizedBox(height: 8),
      pw.Text(pet.name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
      pw.Text(profile, style: pw.TextStyle(color: grey)),
      pw.SizedBox(height: 4),
      pw.Text('Record from ${d.format(from.asDateTime)} to ${d.format(to.asDateTime)}: '
          'logged on $loggedDays of $days days. Made ${DateFormat('d MMM y, h:mm a').format(now)}.',
          style: pw.TextStyle(color: grey, fontSize: 10)),
      pw.SizedBox(height: 16),
      pw.Text('Changes noticed', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      if (detection == null || !detection.ready)
        pw.Text('Not enough days logged yet (MyPet waits for 7).')
      else if (detection.flags.isEmpty)
        pw.Text('None. The last 3 days look like ${pet.name}\'s usual.')
      else
        for (final f in detection.flags)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('${Wording.flagTitle(f)}: ${Wording.flagBody(f, pet)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              for (final line in Wording.flagEvidence(f))
                pw.Text('- $line', style: const pw.TextStyle(fontSize: 9)),
            ]),
          ),
      pw.SizedBox(height: 16),
      pw.Text('Daily log', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      if (logs.isEmpty)
        pw.Text('No daily logs in this range.')
      else
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Ate', 'Energy (1-5)', 'Toileting normal', 'Weight', 'Note'],
          data: [
            for (final e in logs)
              [
                day(e.day),
                e.ate == null ? '' : (e.ate! ? 'Yes' : 'No'),
                e.energy?.toString() ?? '',
                e.toiletingNormal == null ? '' : (e.toiletingNormal! ? 'Yes' : 'No'),
                e.weightKg == null ? '' : '${e.weightKg!.toStringAsFixed(1)} kg',
                e.note,
              ],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: teal),
          cellStyle: const pw.TextStyle(fontSize: 9),
          columnWidths: {5: const pw.FlexColumnWidth(3)},
          cellAlignment: pw.Alignment.centerLeft,
        ),
      pw.SizedBox(height: 16),
      pw.Text('Health records, care tasks and behaviour checks',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      if (other.isEmpty)
        pw.Text('None in this range.')
      else
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'What', 'Details'],
          data: [
            for (final e in other)
              [day(e.day), Wording.entryTitleOf(e), [Wording.entryDetail(e), e.note].where((x) => x.isNotEmpty).join(' · ')],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: teal),
          cellStyle: const pw.TextStyle(fontSize: 9),
          columnWidths: {2: const pw.FlexColumnWidth(3)},
          cellAlignment: pw.Alignment.centerLeft,
        ),
      pw.SizedBox(height: 16),
      pw.Text(
        'About this record: the owner logs whether the pet ate, its energy on a 1 to 5 scale, and whether '
        'toileting was normal. MyPet compares the last 3 days with the pet\'s own previous 28 days and only '
        'notes a change that shows on 2 of the 3 days. Behaviour checks are likely emotions from a short '
        'sound clip, not a diagnosis.',
        style: pw.TextStyle(color: grey, fontSize: 9),
      ),
    ],
  ));
  return doc.save();
}
