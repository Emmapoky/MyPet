// Logging a pet's day straight from the daily reminder notification, without opening the
// app (Lingsha's idea, team meeting 1 Sep 2026; Dr Yam 18 Sep: inside MyPet, through its
// own reminder notifications). Two buttons on the notification:
//   "All normal": ate, usual energy, toileting normal, for every pet not logged yet;
//   "Tell us":    a reply box (type, or tap the keyboard's mic to speak), read by
//                 spoken_log.dart and split by pet name.
// When the app is closed, the answer is written to a small inbox file on the phone, and
// added to the timeline the next time MyPet opens.
import 'dart:convert';
import 'dart:io';

import '../logging/spoken_log.dart';
import '../models/care_entry.dart';
import '../state/app_state.dart';
import '../util/day.dart';

const allNormalAction = 'all_normal';
const tellAction = 'tell';

/// The daily notification's payload: the pets it is about, and where to leave answers.
String dailyPayload(AppState s, List<String> petIds) => jsonEncode({
      'pets': petIds,
      'inbox': ?s.notificationInbox,
    });

/// Pet ids in a payload (old payloads were a bare pet id).
List<String> payloadPets(String? payload) {
  if (payload == null || payload.isEmpty) return const [];
  try {
    final j = jsonDecode(payload);
    if (j is Map && j['pets'] is List) return [for (final p in j['pets'] as List) '$p'];
  } catch (_) {}
  return [payload];
}

/// Writes an answer given while the app was closed (no plugins needed, plain file write).
Future<void> saveToInbox(String? payload, String action, String? input, DateTime at) async {
  try {
    final j = jsonDecode(payload ?? '') as Map;
    final inbox = j['inbox'] as String?;
    if (inbox == null) return;
    await File(inbox).writeAsString(
        '${jsonEncode({'at': at.toIso8601String(), 'action': action, 'input': input, 'pets': j['pets']})}\n',
        mode: FileMode.append,
        flush: true);
  } catch (_) {}
}

/// Adds answers left in the inbox while the app was closed, then empties it.
Future<int> drainInbox(AppState s) async {
  final path = s.notificationInbox;
  if (path == null) return 0;
  final f = File(path);
  if (!await f.exists()) return 0;
  final lines = await f.readAsLines();
  await f.delete();
  var n = 0;
  for (final l in lines.where((l) => l.trim().isNotEmpty)) {
    try {
      final j = jsonDecode(l) as Map;
      n += await logFromNotification(s, j['action'] as String, j['input'] as String?,
          [for (final p in j['pets'] as List) '$p'], DateTime.parse(j['at'] as String));
    } catch (_) {}
  }
  return n;
}

/// Saves daily logs from a notification answer; returns how many pets were logged.
/// A pet already logged that day is left alone.
Future<int> logFromNotification(AppState s, String action, String? input, List<String> petIds, DateTime at) async {
  final day = Day.of(at);
  final pets = [for (final id in petIds) ...s.activePets.where((p) => p.id == id)];
  if (pets.isEmpty) return 0;
  bool logged(String id) => s.timelineOf(id).current.any((e) => e.kind == EntryKind.dailyLog && e.day == day);
  var n = 0;
  if (action == allNormalAction) {
    for (final p in pets.where((p) => !logged(p.id))) {
      await s.addEntry(p.id, EntryKind.dailyLog,
          {'ate': true, 'ateAmount': 'all', 'energy': s.usualEnergy(p.id), 'toiletingNormal': true, 'source': 'notification'},
          day: day);
      n++;
    }
  } else if (action == tellAction && (input ?? '').trim().isNotEmpty) {
    final heard = readSpokenLogs(input!, [for (final p in s.activePets) p.name], fallback: pets.first.name);
    for (final e in heard.entries) {
      final p = s.activePets.where((p) => p.name == e.key).firstOrNull;
      if (p == null || logged(p.id)) continue;
      final h = e.value;
      await s.addEntry(p.id, EntryKind.dailyLog, {
        'ate': ?h.ate,
        'ateAmount': ?h.ateAmount,
        ...h.checks,
        'energy': ?h.energy,
        'toiletingNormal': ?h.toiletingNormal,
        'weightKg': ?h.weightKg,
        if (h.text.isNotEmpty) 'note': h.text,
        'source': 'notification',
      }, day: day);
      n++;
    }
  }
  return n;
}
