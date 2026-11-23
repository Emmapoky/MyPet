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
    expect(r['Mao']!.summary, 'Ate all · Energy 2 of 5');
  });

  test('no name said: the whole sentence is for the pet being logged', () {
    expect(readSpokenLogs('ate everything, normal pee', ['Mao', 'Woof'], fallback: 'Woof').keys, ['Woof']);
  });

  test('amounts, corrections and extra checks', () {
    expect(readSpokenLog('she only ate half her dinner').ateAmount, 'some');
    expect(readSpokenLog('barely ate today').ateAmount, 'some');
    expect(readSpokenLog("he didn't eat his breakfast, oh wait no he did, he finished it").ateAmount, 'all');
    expect(readSpokenLog('ate well, then threw up').checks['vomited'], isTrue);
    expect(readSpokenLog('peed on the rug again').checks['accident'], isTrue);
    expect(readSpokenLog('drinking a lot of water').checks['drinkingMore'], isTrue);
  });

  test("the demo's driving voice note fills every answer", () {
    final h = readSpokenLogs(
        "Hey, so, quick one for Biscuit. So he didn't eat his breakfast this morning, oh wait, no, he did. He finished "
        "it after his walk. He's been a bit tired today, so energy 2. Normal poo on the walk too. Oh, and he was 10.4 "
        "kilos at the vet. Yeah, that's it. Thanks!",
        ['Biscuit', 'Mochi'],
        fallback: 'Biscuit')['Biscuit']!;
    expect(h.ateAmount, 'all');
    expect(h.energy, 2);
    expect(h.toiletingNormal, isTrue);
    expect(h.weightKg, 10.4);
  });
}
