// dart:io on the phone. The web build gets a small stand-in (lib/web/web_io.dart)
// that keeps files in the browser, so the same code runs in both.
export 'dart:io' if (dart.library.js_interop) '../web/web_io.dart';
