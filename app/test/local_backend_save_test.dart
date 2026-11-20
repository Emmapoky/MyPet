import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/local_backend.dart';
import 'package:mypet/state/app_state.dart';
import 'package:mypet/models/pet.dart';

void main() {
  test('many quick changes in a row are all on disk after a restart', () async {
    final dir = await Directory.systemTemp.createTemp('mypet_save');
    final f = File('${dir.path}/data.json');
    final b = LocalBackend(file: f);
    final s = AppState(b, detectInBackground: false);
    await b.signIn('', '');
    // Not awaited one by one: saves overlap, as when a demo adds pets and logs fast.
    await Future.wait([for (var i = 0; i < 20; i++) s.addPet(name: 'Pet $i', species: Species.cat)]);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final again = LocalBackend(file: f);
    await again.load();
    expect(again.currentCarer, isNotNull);
    final pets = await again.watchPets().first;
    expect(pets, hasLength(20));
    expect(File('${f.path}.tmp').existsSync(), isFalse);
    await dir.delete(recursive: true);
  });
}
