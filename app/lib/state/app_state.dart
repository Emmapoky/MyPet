import 'dart:async';

import 'package:material_ui/material_ui.dart' show ThemeMode;

import 'package:flutter/foundation.dart';

import '../data/backend.dart';
import '../detection/change_detector.dart';
import '../models/care_entry.dart';
import '../models/pet.dart';
import '../models/reminder.dart';
import '../models/timeline.dart';
import '../util/day.dart';

/// Holds what the screens show and passes every change to the [Backend].
class AppState extends ChangeNotifier {
  AppState(this.backend,
      {DateTime Function()? clock, this.detectInBackground = true})
      : _clock = clock ?? DateTime.now {
    _carerSub = backend.carerChanges.listen(_onCarer);
    _syncSub = backend.waitingToSync.listen((w) {
      waitingToSync = w;
      notifyListeners();
    });
  }

  final Backend backend;

  /// Tests turn this off; the app always runs the detector in an isolate (NFR03).
  final bool detectInBackground;
  final DateTime Function() _clock;
  StreamSubscription<Carer?>? _carerSub;
  StreamSubscription<bool>? _syncSub;
  StreamSubscription<List<Pet>>? _petsSub;
  final Map<String, StreamSubscription> _petSubs = {};

  Carer? carer;
  bool carerKnown = false;
  List<Pet> pets = const [];
  bool petsLoaded = false;
  String? _selectedPetId;
  final Map<String, Timeline> _timelines = {};
  final Map<String, List<Reminder>> _reminders = {};
  final Map<String, DetectionResult> _detection = {};
  bool waitingToSync = false;

  /// Bottom tab shown (0 Today, 1 Pets, 2 Check, 3 Insights, 4 Reminders).
  int tab = 0;

  /// Light by default; dark or "match phone" only if the person picks it in Settings.
  /// Saved with [onLookChanged] by main.dart.
  ThemeMode look = ThemeMode.light;
  void Function(ThemeMode)? onLookChanged;

  void setLook(ThemeMode m) {
    look = m;
    onLookChanged?.call(m);
    notifyListeners();
  }

  void goToTab(int i) {
    tab = i;
    notifyListeners();
  }

  DateTime now() => _clock();
  Day get today => Day.of(_clock());

  List<Pet> get activePets => pets.where((p) => p.isActive).toList();

  Pet? get selectedPet {
    final active = activePets;
    if (active.isEmpty) return null;
    return active.firstWhere((p) => p.id == _selectedPetId,
        orElse: () => active.first);
  }

  void selectPet(String id) {
    _selectedPetId = id;
    notifyListeners();
  }

  Timeline timelineOf(String petId) =>
      _timelines[petId] ?? const Timeline([], []);
  List<Reminder> remindersOf(String petId) => _reminders[petId] ?? const [];
  DetectionResult? detectionOf(String petId) => _detection[petId];

  void _onCarer(Carer? c) {
    carer = c;
    carerKnown = true;
    _petsSub?.cancel();
    for (final s in _petSubs.values) {
      s.cancel();
    }
    _petSubs.clear();
    pets = const [];
    petsLoaded = false;
    if (c != null) {
      _petsSub = backend.watchPets().listen(_onPets);
    }
    notifyListeners();
  }

  void _onPets(List<Pet> list) {
    pets = list;
    petsLoaded = true;
    for (final p in list) {
      if (_petSubs.containsKey('e${p.id}')) continue;
      _petSubs['e${p.id}'] = backend.watchEntries(p.id).listen((all) {
        _timelines[p.id] = Timeline.resolve(all);
        notifyListeners();
        _detect(p.id);
      });
      _petSubs['r${p.id}'] = backend.watchReminders(p.id).listen((r) {
        _reminders[p.id] = r;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  /// Runs the detector off the main thread (NFR03).
  Future<void> _detect(String petId) async {
    final entries = timelineOf(petId).ofKind(EntryKind.dailyLog);
    final asOf = today;
    final result = detectInBackground
        ? await compute(_runDetector, (entries, asOf))
        : _runDetector((entries, asOf));
    _detection[petId] = result;
    notifyListeners();
  }

  // ---- writes ----

  String get _me => carer!.id;

  Future<Pet> addPet({
    required String name,
    required Species species,
    String breed = '',
    Day? birthDate,
    double? weightKg,
    int? colour,
    String? photo,
  }) async {
    final pet = Pet(
      id: backend.newId(),
      name: name,
      species: species,
      breed: breed,
      birthDate: birthDate,
      weightKg: weightKg,
      carerIds: [_me],
      createdAt: now(),
      colour: colour ?? nextColour(),
      photo: photo,
    );
    await backend.savePet(pet);
    _selectedPetId = pet.id;
    return pet;
  }

  Future<void> updatePet(Pet pet) => backend.savePet(pet);

  /// The first pet colour no active pet uses yet, so a household's pets look different.
  int nextColour() {
    final used = {for (final p in activePets) petColourIndex(p)};
    for (var i = 0; i < petColourCount; i++) {
      if (!used.contains(i)) return i;
    }
    return activePets.length % petColourCount;
  }

  /// Folder on this phone holding pet photos (set by main.dart; null in tests).
  String? photoDir;

  Future<CareEntry> addEntry(String petId, EntryKind kind, Map<String, dynamic> data,
      {Day? day, String? supersedes, bool voided = false}) async {
    final e = CareEntry(
      id: backend.newId(),
      petId: petId,
      kind: kind,
      day: day ?? today,
      createdAt: now(),
      createdBy: _me,
      supersedes: supersedes,
      voided: voided,
      data: data,
    );
    await backend.addEntry(e);
    return e;
  }

  /// Editing writes a new version (FR-N04).
  Future<CareEntry> editEntry(CareEntry old, Map<String, dynamic> data, {Day? day}) =>
      addEntry(old.petId, old.kind, data, day: day ?? old.day, supersedes: old.id);

  Future<CareEntry> deleteEntry(CareEntry old) =>
      addEntry(old.petId, old.kind, old.data, day: old.day, supersedes: old.id, voided: true);

  Future<void> saveReminder(Reminder r) => backend.saveReminder(r);

  bool loggedToday(String petId) => timelineOf(petId)
      .current
      .any((e) => e.kind == EntryKind.dailyLog && e.day == today);

  @override
  void dispose() {
    _carerSub?.cancel();
    _syncSub?.cancel();
    _petsSub?.cancel();
    for (final s in _petSubs.values) {
      s.cancel();
    }
    super.dispose();
  }
}

DetectionResult _runDetector((List<CareEntry>, Day) args) =>
    const ChangeDetector().run(args.$1, args.$2);
