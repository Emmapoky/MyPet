// path_provider's folders for the web build, inside the browser store (web_io.dart).
import 'web_io.dart';

Future<Directory> getApplicationDocumentsDirectory() async => Directory('/docs');
Future<Directory> getApplicationSupportDirectory() async => Directory('/support');
Future<Directory> getTemporaryDirectory() async => Directory('/tmp');
