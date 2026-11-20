// The web build's stand-in for the few dart:io pieces MyPet uses (File, Directory,
// FileMode, Platform.environment). Files live in this browser only:
//   * text and small files (logs, settings, photos under 400 KB) are kept in
//     localStorage, so they are still there after a reload;
//   * bigger files (clips) and anything under /tmp stay in memory for this visit.
// Nothing is uploaded. Each visitor has their own copy.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('localStorage')
external _Storage get _localStorage;

extension type _Storage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
  external int get length;
  external String? key(int index);
}

const _prefix = 'mypetfs:';
const _keepLimit = 400 * 1024;

/// path -> bytes. Filled from localStorage on first use.
Map<String, Uint8List>? _files;

Map<String, Uint8List> get _fs {
  final known = _files;
  if (known != null) return known;
  final m = <String, Uint8List>{};
  try {
    final ls = _localStorage;
    for (var i = 0; i < ls.length; i++) {
      final k = ls.key(i);
      if (k == null || !k.startsWith(_prefix)) continue;
      final v = ls.getItem(k);
      if (v == null) continue;
      m[k.substring(_prefix.length)] = v.startsWith('b:') ? base64Decode(v.substring(2)) : utf8.encode(v.substring(2));
    }
  } catch (_) {}
  return _files = m;
}

String _norm(String p) {
  final parts = <String>[];
  for (final s in p.split('/')) {
    if (s.isEmpty || s == '.') continue;
    if (s == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(s);
    }
  }
  return '/${parts.join('/')}';
}

void _store(String path, Uint8List bytes, {String? text}) {
  _fs[path] = bytes;
  try {
    if (path.startsWith('/tmp/')) return;
    if (bytes.length > _keepLimit) {
      _localStorage.removeItem('$_prefix$path');
      return;
    }
    _localStorage.setItem('$_prefix$path', text != null ? 't:$text' : 'b:${base64Encode(bytes)}');
  } catch (_) {
    // Browser store full or blocked: the file still works for this visit.
  }
}

void _remove(String path) {
  _fs.remove(path);
  try {
    _localStorage.removeItem('$_prefix$path');
  } catch (_) {}
}

/// Bytes of a file in the browser store, or null (used by web_media.dart).
Uint8List? webFileBytes(String path) => _fs[_norm(path)];

class FileSystemException implements Exception {
  const FileSystemException([this.message = '', this.path = '']);
  final String message, path;
  @override
  String toString() => 'FileSystemException: $message, path = $path';
}

class FileMode {
  const FileMode._(this._mode);
  final int _mode;
  static const read = FileMode._(0);
  static const write = FileMode._(1);
  static const append = FileMode._(2);
  static const writeOnly = FileMode._(3);
  static const writeOnlyAppend = FileMode._(4);
  bool get _appends => _mode == 2 || _mode == 4;
}

abstract class FileSystemEntity {
  String get path;
  Future<bool> exists();
  bool existsSync();
}

class File implements FileSystemEntity {
  File(String path) : path = _norm(path);
  @override
  final String path;

  Directory get parent => Directory(path.substring(0, path.lastIndexOf('/')));

  @override
  Future<bool> exists() async => existsSync();
  @override
  bool existsSync() => _fs.containsKey(path);

  Uint8List readAsBytesSync() {
    final b = _fs[path];
    if (b == null) throw FileSystemException('Cannot open file', path);
    return b;
  }

  Future<Uint8List> readAsBytes() async => readAsBytesSync();
  String readAsStringSync({Encoding encoding = utf8}) => encoding.decode(readAsBytesSync());
  Future<String> readAsString({Encoding encoding = utf8}) async => readAsStringSync(encoding: encoding);
  Future<List<String>> readAsLines({Encoding encoding = utf8}) async =>
      const LineSplitter().convert(readAsStringSync(encoding: encoding));
  int lengthSync() => readAsBytesSync().length;
  Future<int> length() async => lengthSync();

  void writeAsBytesSync(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false}) {
    final add = Uint8List.fromList(bytes);
    final old = mode._appends ? _fs[path] : null;
    _store(path, old == null ? add : (Uint8List(old.length + add.length)..setAll(0, old)..setAll(old.length, add)));
  }

  Future<File> writeAsBytes(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false}) async {
    writeAsBytesSync(bytes, mode: mode);
    return this;
  }

  void writeAsStringSync(String contents, {FileMode mode = FileMode.write, Encoding encoding = utf8, bool flush = false}) {
    final text = mode._appends && _fs[path] != null ? readAsStringSync() + contents : contents;
    _store(path, Uint8List.fromList(encoding.encode(text)), text: text);
  }

  Future<File> writeAsString(String contents,
      {FileMode mode = FileMode.write, Encoding encoding = utf8, bool flush = false}) async {
    writeAsStringSync(contents, mode: mode, encoding: encoding);
    return this;
  }

  Future<File> create({bool recursive = false, bool exclusive = false}) async {
    if (!existsSync()) _store(path, Uint8List(0), text: '');
    return this;
  }

  File copySync(String newPath) {
    final to = File(newPath);
    _store(to.path, readAsBytesSync());
    return to;
  }

  Future<File> copy(String newPath) async => copySync(newPath);

  File renameSync(String newPath) {
    final to = copySync(newPath);
    _remove(path);
    return to;
  }

  Future<File> rename(String newPath) async => renameSync(newPath);

  void deleteSync({bool recursive = false}) {
    if (!existsSync()) throw FileSystemException('Cannot delete file', path);
    _remove(path);
  }

  Future<File> delete({bool recursive = false}) async {
    deleteSync();
    return this;
  }

  @override
  String toString() => "File: '$path'";
}

class Directory implements FileSystemEntity {
  Directory(String path) : path = _norm(path);
  @override
  final String path;

  static Directory get systemTemp => Directory('/tmp');

  // Folders exist as soon as something is put in them.
  @override
  Future<bool> exists() async => true;
  @override
  bool existsSync() => true;
  Future<Directory> create({bool recursive = false}) async => this;
  void createSync({bool recursive = false}) {}

  Future<Directory> delete({bool recursive = false}) async {
    for (final k in _fs.keys.where((k) => k.startsWith('$path/')).toList()) {
      _remove(k);
    }
    return this;
  }

  @override
  String toString() => "Directory: '$path'";
}

class Platform {
  static const Map<String, String> environment = {};
  static const isIOS = false, isAndroid = false, isMacOS = false, isLinux = false, isWindows = false;
  static const pathSeparator = '/';
}
