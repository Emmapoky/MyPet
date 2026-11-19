import 'package:pdfrx/pdfrx.dart';

/// All the text in a PDF, page by page, read on the phone (pdfium, no network).
/// Returns an empty string for a scanned PDF that holds only pictures.
Future<String> readPdfText(String path) async {
  await pdfrxFlutterInitialize();
  final doc = await PdfDocument.openFile(path);
  try {
    final out = StringBuffer();
    for (final page in doc.pages) {
      final t = await page.loadText();
      if (t != null) out.writeln(t.fullText);
    }
    return out.toString();
  } finally {
    await doc.dispose();
  }
}
