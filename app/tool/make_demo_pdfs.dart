// Makes the demo pets' vet PDFs (lib/records/demo_documents.dart) into assets/demo_pdfs,
// laid out like real clinic paperwork. The scanned one is a picture of a page with no
// text in it, like a phone scan. Run: dart run tool/make_demo_pdfs.dart [out dir]
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:mypet/records/demo_documents.dart';

const _ink = PdfColor.fromInt(0xFF1B1530);
const _accent = PdfColor.fromInt(0xFF2E5E8C);

pw.Widget _line(String l) {
  final cells = l.split(RegExp(r'\s{2,}'));
  if (cells.length > 1 && !l.contains(':')) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      child: pw.Row(children: [for (final c in cells) pw.Expanded(child: pw.Text(c, style: const pw.TextStyle(fontSize: 11, color: _ink)))]),
    );
  }
  final i = l.indexOf(':');
  if (i > 0 && i < 34) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(text: l.substring(0, i + 1), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.TextSpan(text: l.substring(i + 1), style: const pw.TextStyle(fontSize: 11, color: _ink)),
        ]),
      ),
    );
  }
  return pw.Padding(padding: const pw.EdgeInsets.only(top: 6), child: pw.Text(l, style: const pw.TextStyle(fontSize: 11, color: _ink)));
}

pw.Page _page(DemoDocument d, {pw.Widget? body}) {
  final lines = d.text.trim().split('\n');
  final hasAddress = lines.length > 2 && lines[1].contains('|');
  final titleAt = hasAddress ? 2 : 1;
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(44),
    build: (_) => body ?? pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(14),
        decoration: const pw.BoxDecoration(color: _accent, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(lines.first, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          if (hasAddress) pw.Text(lines[1], style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
        ]),
      ),
      pw.SizedBox(height: 16),
      pw.Text(lines[titleAt], style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _accent)),
      pw.SizedBox(height: 6),
      for (final l in lines.skip(titleAt + 1)) _line(l),
      pw.Spacer(),
      pw.Divider(color: PdfColors.grey400),
      pw.Text('Made-up document for the MyPet demo. No real pet, owner, clinic or vet.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ]),
  );
}

Future<void> main(List<String> args) async {
  final out = Directory(args.isEmpty ? 'assets/demo_pdfs' : args.first)..createSync(recursive: true);
  for (final d in demoDocuments) {
    final doc = pw.Document();
    if (d.scanned) {
      // A phone photo of the page: render the page to a picture first (ImageMagick), then
      // put only the picture in the PDF, so there is no text to read.
      final tmp = Directory.systemTemp.createTempSync('scan');
      final png = '${tmp.path}/page.png';
      final r = Process.runSync('convert', [
        '-size', '1240x1754', 'xc:#F4F1EA', '-font', 'DejaVu-Sans', '-pointsize', '34', '-fill', '#2A2A2A',
        '-annotate', '+110+170', d.text.trim(), '-rotate', '1.2', '-blur', '0x0.8', '-attenuate', '0.3', '+noise', 'Gaussian', png,
      ]);
      if (r.exitCode != 0) throw StateError('ImageMagick failed: ${r.stderr}');
      final img = pw.MemoryImage(File(png).readAsBytesSync());
      doc.addPage(_page(d, body: pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain))));
    } else {
      doc.addPage(_page(d));
    }
    File('${out.path}/${d.file}').writeAsBytesSync(await doc.save());
  }
  stdout.writeln('Wrote ${demoDocuments.length} PDFs to ${out.path}');
}
