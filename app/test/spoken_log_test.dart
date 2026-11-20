import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/logging/spoken_log.dart';

void main() {
  test('one pet: only what was said is filled in', () {
    final h = readSpokenLog('She ate well, a bit tired today, normal poo');
    expect((h.ate, h.energy, h.toiletingNormal), (true, 2, true));
    final n = readSpokenLog('He did not eat his dinner and seems lethargic');
    expect((n.ate, n.energy, n.toiletingNormal), (false, 1, null));
    final z = readSpokenLog('zoomies all evening, had diarrhoea in the morning');
    expect((z.ate, z.energy, z.toiletingNormal), (null, 5, false));
    expect(readSpokenLog('Pooped on the couch').toiletingNormal, false);
    expect(readSpokenLog('energy 4, weighs 4.2 kg').energy, 4);
    expect(readSpokenLog('weighs 4.2 kilos').weightKg, 4.2);
    expect(readSpokenLog('not tired at all, very playful').energy, 5);
    expect(readSpokenLog('skipped breakfast').ate, false);
    expect(readSpokenLog('nothing much happened').isEmpty, isTrue);
  });

  test('several pets in one sentence are split by name', () {
    final r = readSpokenLogs('Mao ate well but was sleepy. Woof skipped dinner and threw up', ['Mao', 'Woof'],
        fallback: 'Mao');
    expect((r['Mao']!.ate, r['Mao']!.energy), (true, 2));
    expect((r['Woof']!.ate, r['Woof']!.toiletingNormal), (false, false));
    expect(r['Mao']!.summary, 'Ate · Energy 2 of 5');
  });

  test('no name said: the whole sentence is for the pet being logged', () {
    expect(readSpokenLogs('ate everything, normal pee', ['Mao', 'Woof'], fallback: 'Woof').keys, ['Woof']);
  });
}
