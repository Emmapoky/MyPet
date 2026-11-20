// Pictures and clips for the web build: files from the browser store become
// in-memory images and blob URLs the browser's video element can play.
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart' show ImageProvider, MemoryImage;
import 'package:video_player/video_player.dart';

import 'web_io.dart';

@JS('URL.createObjectURL')
external String _createObjectUrl(JSObject blob);

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, _BlobOptions options);
}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}

final _urls = <String, String>{};

/// A blob URL for bytes, e.g. a clip, so the browser can play or read it.
String blobUrlOf(Uint8List bytes, String type) =>
    _createObjectUrl(_Blob([bytes.toJS].toJS, _BlobOptions(type: type)));

String _typeOf(String path) {
  final p = path.toLowerCase();
  if (p.endsWith('.webm')) return 'video/webm';
  if (p.endsWith('.mov')) return 'video/quicktime';
  if (p.endsWith('.m4a')) return 'audio/mp4';
  if (p.endsWith('.wav')) return 'audio/wav';
  if (p.endsWith('.mp3')) return 'audio/mpeg';
  return 'video/mp4';
}

/// A URL the browser can open for [path]: blob:, http(s): and data: URLs as they are,
/// files in the browser store as a blob URL. Null if there is no such file.
String? urlOf(String path) {
  if (path.startsWith('blob:') || path.startsWith('http') || path.startsWith('data:')) return path;
  final b = webFileBytes(path);
  if (b == null) return null;
  return _urls[path] ??= blobUrlOf(b, _typeOf(path));
}

ImageProvider fileImage(File f) => MemoryImage(f.readAsBytesSync());

VideoPlayerController? clipPlayer(String path) {
  final u = urlOf(path);
  return u == null ? null : VideoPlayerController.networkUrl(Uri.parse(u));
}
