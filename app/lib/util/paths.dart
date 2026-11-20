// path_provider on the phone. The web build gets folders inside the browser store.
export 'package:path_provider/path_provider.dart' if (dart.library.js_interop) '../web/web_paths.dart';
