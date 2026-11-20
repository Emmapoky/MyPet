import 'dart:async';
import 'dart:convert';
import '../util/io.dart';

import 'package:uuid/uuid.dart';

import '../models/care_entry.dart';
import '../models/pet.dart';
import '../models/reminder.dart';
import 'backend.dart';

/// Keeps everything on this phone in one JSON file. Used before Firebase is set up, for
/// the offline demo, and as the fake in tests. There is one local carer and no password.
class LocalBackend implements Backend {
  LocalBackend({this.file});

  /// Where data is saved. Null keeps it in memory only (tests).
  final File? file;

  final _uuid = const Uuid();
  final Map<String, Pet> _pets = {};
  final Map<String, CareEntry> _entries = {};
  final Map<String, Reminder> _reminders = {};
  final _changes = StreamController<void>.broadcast();
  final _carer = StreamController<Carer?>.broadcast();
  Carer? _current;

  static const localCarerId = 'local-carer';

  @override
  String get name => 'On this phone only';

  Future<void> load() async {
    final f = file;
    if (f == null || !await f.exists()) return;
    final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    for (final e in (m['pets'] as Map).entries) {
      _pets[e.key as String] =
          Pet.fromMap(e.key as String, Map<String, dynamic>.from(e.value as Map));
    }
    for (final e in (m['entries'] as Map).entries) {
      _entries[e.key as String] = CareEntry.fromMap(
          e.key as String, Map<String, dynamic>.from(e.value as Map));
    }
    for (final e in (m['reminders'] as Map).entries) {
      _reminders[e.key as String] = Reminder.fromMap(
          e.key as String, Map<String, dynamic>.from(e.value as Map));
    }
    if (m['signedIn'] == true) _current = const Carer(localCarerId, null);
  }

  Future<void> _save() async {
    _changes.add(null);
    final f = file;
    if (f == null) return;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      'signedIn': _current != null,
      'pets': {for (final p in _pets.values) p.id: p.toMap()},
      'entries': {for (final e in _entries.values) e.id: e.toMap()},
      'reminders': {for (final r in _reminders.values) r.id: r.toMap()},
    }));
    await tmp.rename(f.path);
  }

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Stream<Carer?> get carerChanges async* {
    yield _current;
    yield* _carer.stream;
  }

  @override
  Carer? get currentCarer => _current;

  @override
  Future<void> signUp(String email, String password) => signIn(email, password);

  @override
  Future<void> signIn(String email, String password) async {
    _current = const Carer(localCarerId, null);
    _carer.add(_current);
    await _save();
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _carer.add(null);
    await _save();
  }

  @override
  Stream<List<Pet>> watchPets() => _watch(() => _pets.values
      .where((p) => _current != null && p.carerIds.contains(_current!.id))
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));

  @override
  Future<void> savePet(Pet pet) async {
    _pets[pet.id] = pet;
    await _save();
  }

  @override
  Stream<List<CareEntry>> watchEntries(String petId) => _watch(
      () => _entries.values.where((e) => e.petId == petId).toList());

  @override
  Future<void> addEntry(CareEntry entry) async {
    if (_entries.containsKey(entry.id)) {
      throw StateError('Entries are append-only (FR-N04).');
    }
    final problem = entry.kind == EntryKind.dailyLog
        ? LogRanges.checkDailyLog(entry.data)
        : null;
    if (problem != null) throw ArgumentError(problem);
    _entries[entry.id] = entry;
    await _save();
  }

  /// Adds many entries with one save (demo data).
  Future<void> addEntries(Iterable<CareEntry> entries) async {
    for (final e in entries) {
      _entries[e.id] = e;
    }
    await _save();
  }

  @override
  Stream<List<Reminder>> watchReminders(String petId) => _watch(
      () => _reminders.values.where((r) => r.petId == petId).toList());

  @override
  Future<void> saveReminder(Reminder reminder) async {
    _reminders[reminder.id] = reminder;
    await _save();
  }

  @override
  Stream<bool> get waitingToSync => Stream.value(false);

  @override
  String newId() => _uuid.v4();
}
