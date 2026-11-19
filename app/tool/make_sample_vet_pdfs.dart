// Makes PDFs of the made-up vet documents in test/fixtures/vet_samples.dart, to try
// "Fill from a vet PDF" on a phone. Run: dart run tool/make_sample_vet_pdfs.dart <out dir>
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test/fixtures/vet_samples.dart';

Future<void> main(List<String> args) async {
  final out = Directory(args.isEmpty ? 'build/sample_vet_pdfs' : args.first)..createSync(recursive: true);
  for (final e in vetSamples.entries) {
    final lines = e.value.trim().split('\n');
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(lines.first, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Divider(),
        for (final l in lines.skip(1)) pw.Padding(padding: const pw.EdgeInsets.only(top: 6), child: pw.Text(l, style: const pw.TextStyle(fontSize: 12))),
        pw.Spacer(),
        pw.Text('Sample document made for testing MyPet. Not a real record.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ]),
    ));
    File('${out.path}/${e.key}.pdf').writeAsBytesSync(await doc.save());
  }
  stdout.writeln('Wrote ${vetSamples.length} PDFs to ${out.path}');
}
