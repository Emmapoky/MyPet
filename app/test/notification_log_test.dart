import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/models/care_entry.dart';
import 'package:mypet/models/pet.dart';
import 'package:mypet/notify/notification_log.dart';

import 'app_flow_test.dart' show signedInState;

void main() {
  test('"All normal" on the notification logs every pet not logged yet, at its usual energy', () async {
    final s = await signedInState();
    final mao = await s.addPet(name: 'Mao', species: Species.cat);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final woof = await s.addPet(name: 'Woof', species: Species.dog);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final n = await logFromNotification(s, allNormalAction, null, [mao.id, woof.id], s.now());
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(n, 2);
    final e = s.timelineOf(mao.id).ofKind(EntryKind.dailyLog).single;
    expect((e.ate, e.energy, e.toiletingNormal), (true, 3, true));
    // Pressed twice: nothing is logged twice.
    expect(await logFromNotification(s, allNormalAction, null, [mao.id], s.now()), 0);
  });

  test('"Tell us" reply is split by pet name and only fills what was said', () async {
    final s = await signedInState();
    final mao = await s.addPet(name: 'Mao', species: Species.cat);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final woof = await s.addPet(name: 'Woof', species: Species.dog);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await logFromNotification(s, tellAction, 'Mao ate well, a bit sleepy. Woof threw up after dinner',
        [mao.id, woof.id], s.now());
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final m = s.timelineOf(mao.id).ofKind(EntryKind.dailyLog).single;
    final w = s.timelineOf(woof.id).ofKind(EntryKind.dailyLog).single;
    expect((m.ate, m.energy, m.toiletingNormal), (true, 2, null));
    expect(w.toiletingNormal, false);
    expect(w.note, contains('threw up'));
  });

  test('answers given while the app was closed wait in the inbox and are added on open', () async {
    final s = await signedInState();
    final mao = await s.addPet(name: 'Mao', species: Species.cat);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final dir = Directory.systemTemp.createTempSync('inbox');
    s.notificationInbox = '${dir.path}/inbox.jsonl';
    await saveToInbox(dailyPayload(s, [mao.id]), tellAction, 'did not eat, lethargic', s.now());
    expect(payloadPets(dailyPayload(s, [mao.id])), [mao.id]);
    expect(payloadPets('old-pet-id'), ['old-pet-id']);
    expect(await drainInbox(s), 1);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final e = s.timelineOf(mao.id).ofKind(EntryKind.dailyLog).single;
    expect((e.ate, e.energy), (false, 1));
    expect(File(s.notificationInbox!).existsSync(), isFalse);
  });

  test('Siri and Shortcuts leave no pet ids: every pet is covered', () async {
    final s = await signedInState();
    final mao = await s.addPet(name: 'Mao', species: Species.cat);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final woof = await s.addPet(name: 'Woof', species: Species.dog);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(await logFromNotification(s, allNormalAction, null, const [], s.now()), 2);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(s.timelineOf(woof.id).ofKind(EntryKind.dailyLog), hasLength(1));
    expect(s.timelineOf(mao.id).ofKind(EntryKind.dailyLog).single.ateAmount, 'all');
  });
}
