import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdfrx/pdfrx.dart';

import '../util/io.dart';

/// All the text in a PDF, page by page, read on the phone (pdfium, no network).
/// Returns an empty string for a scanned PDF that holds only pictures.
Future<String> readPdfText(String path) async {
  await pdfrxFlutterInitialize();
  // The web build keeps files in the browser store (lib/web/web_io.dart), so read the bytes.
  final doc = kIsWeb ? await PdfDocument.openData(await File(path).readAsBytes()) : await PdfDocument.openFile(path);
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
