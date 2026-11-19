import '../models/care_entry.dart';
import '../models/pet.dart';
import '../models/reminder.dart';

/// The signed-in carer.
class Carer {
  final String id;
  final String? email;
  const Carer(this.id, this.email);
}

/// Everything the app stores goes through this interface, so replacing Firebase needs no
/// change above it (NFR08). Two versions exist: [FirestoreBackend] (Firebase Spark, Auth
/// and Firestore only) and [LocalBackend] (on the phone only, for demos and tests).
abstract class Backend {
  /// Short name shown in Settings.
  String get name;

  Stream<Carer?> get carerChanges;
  Carer? get currentCarer;
  Future<void> signUp(String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signOut();

  /// Pets the signed-in carer looks after (NFR06).
  Stream<List<Pet>> watchPets();
  Future<void> savePet(Pet pet);

  /// Every entry ever written for a pet, including replaced versions (FR-N04).
  /// Use Timeline.resolve to get the current view.
  Stream<List<CareEntry>> watchEntries(String petId);

  /// Entries are only ever added, never changed or deleted (FR-N04).
  Future<void> addEntry(CareEntry entry);

  Stream<List<Reminder>> watchReminders(String petId);
  Future<void> saveReminder(Reminder reminder);

  /// True while changes made offline are waiting to reach the server (FR06).
  Stream<bool> get waitingToSync;

  String newId();
}
