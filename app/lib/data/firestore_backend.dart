import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/care_entry.dart';
import '../models/pet.dart';
import '../models/reminder.dart';
import 'backend.dart';

/// Firebase Spark backend: Authentication and Cloud Firestore only (report 4.3).
///
/// Layout:
///   pets/{petId}                    profile, with carerIds
///   pets/{petId}/entries/{entryId}  append-only timeline (FR-N04)
///   pets/{petId}/reminders/{id}     care schedules (FR10)
/// Access is limited to the carers in carerIds by firestore.rules (NFR06).
///
/// Writes are not awaited: Firestore saves them to the phone's cache at once and sends
/// them when the phone is back online, which is the offline queue (FR06).
class FirestoreBackend implements Backend {
  FirestoreBackend({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final _pending = <Object, bool>{};
  final _waiting = StreamController<bool>.broadcast();
  final _errors = StreamController<Object>.broadcast();

  /// Write errors that happen after the call returned, such as a rules rejection.
  Stream<Object> get errors => _errors.stream;

  @override
  String get name => 'Firebase';

  CollectionReference<Map<String, dynamic>> get _pets => _db.collection('pets');

  Carer? _toCarer(User? u) => u == null ? null : Carer(u.uid, u.email);

  @override
  Stream<Carer?> get carerChanges => _auth.authStateChanges().map(_toCarer);

  @override
  Carer? get currentCarer => _toCarer(_auth.currentUser);

  @override
  Future<void> signUp(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signOut() => _auth.signOut();

  void _track(Object key, SnapshotMetadata meta) {
    _pending[key] = meta.hasPendingWrites;
    _waiting.add(_pending.values.any((p) => p));
  }

  Stream<List<T>> _listen<T>(Query<Map<String, dynamic>> q,
      T Function(String id, Map<String, dynamic> m) read) {
    final key = Object();
    return q
        .snapshots(includeMetadataChanges: true)
        .map((s) {
          _track(key, s.metadata);
          return [for (final d in s.docs) read(d.id, d.data())];
        });
  }

  void _write(Future<void> f) => unawaited(f.catchError(_errors.add));

  @override
  Stream<List<Pet>> watchPets() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _listen(_pets.where('carerIds', arrayContains: uid), Pet.fromMap);
  }

  @override
  Future<void> savePet(Pet pet) async =>
      _write(_pets.doc(pet.id).set(pet.toMap()));

  @override
  Stream<List<CareEntry>> watchEntries(String petId) =>
      _listen(_pets.doc(petId).collection('entries'), CareEntry.fromMap);

  @override
  Future<void> addEntry(CareEntry entry) async {
    final problem = entry.kind == EntryKind.dailyLog
        ? LogRanges.checkDailyLog(entry.data)
        : null;
    if (problem != null) throw ArgumentError(problem);
    _write(_pets
        .doc(entry.petId)
        .collection('entries')
        .doc(entry.id)
        .set(entry.toMap()));
  }

  @override
  Stream<List<Reminder>> watchReminders(String petId) =>
      _listen(_pets.doc(petId).collection('reminders'), Reminder.fromMap);

  @override
  Future<void> saveReminder(Reminder reminder) async => _write(_pets
      .doc(reminder.petId)
      .collection('reminders')
      .doc(reminder.id)
      .set(reminder.toMap()));

  @override
  Stream<bool> get waitingToSync => _waiting.stream;

  @override
  String newId() => _pets.doc().id;
}
