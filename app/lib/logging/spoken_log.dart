// Turns a sentence like "Mao ate well but was a bit tired, normal poo. Woof skipped dinner"
// into daily log answers, per pet. Used by the voice log in the app and by the "Tell us"
// reply on the daily reminder notification (FR18, Lingsha's voice-input idea, team meeting
// 1 Sep 2026; Dr Yam 18 Sep: everything inside the app, no AI account).
//
// It is a small set of plain word rules that run on the phone: no network and no generative
// AI. Only what was actually said is filled in; anything not mentioned stays empty for the
// person to tap, and they always see what was understood before saving.

/// What one pet's part of the sentence said. Null means "not mentioned".
class SpokenLog {
  SpokenLog({this.ateAmount, this.energy, this.toiletingNormal, this.weightKg, this.text = '', Map<String, bool>? checks})
      : checks = checks ?? {};

  /// "all", "some" or "none".
  String? ateAmount;
  bool? get ate => ateAmount == null ? null : ateAmount != 'none';
  int? energy;
  bool? toiletingNormal;
  double? weightKg;

  /// Extra checks heard, by daily log key: drinkingMore, accident, vomited.
  final Map<String, bool> checks;

  /// The words this was read from, kept as the log's note.
  String text;

  bool get isEmpty =>
      ateAmount == null && energy == null && toiletingNormal == null && weightKg == null && checks.isEmpty;

  /// "Ate · Energy 2 of 5 · Toileting not normal", for showing what was understood.
  String get summary => [
        if (ateAmount != null)
          switch (ateAmount) {
            'all' => 'Ate all',
            'some' => 'Ate some',
            _ => 'Did not eat',
          },
        if (energy != null) 'Energy $energy of 5',
        if (toiletingNormal != null) toiletingNormal! ? 'Toileting normal' : 'Toileting not normal',
        if (checks['drinkingMore'] == true) 'Drinking more',
        if (checks['accident'] == true) 'Accident indoors',
        if (checks['vomited'] == true) 'Vomited',
        if (weightKg != null) '${weightKg!.toStringAsFixed(1)} kg',
      ].join(' · ');
}

RegExp _r(String p) => RegExp(p, caseSensitive: false);

// Checked in order: the first rule that matches wins, so "didn't eat" is read before "eat".
final _ateNo = _r(r"\b(did ?n[o']?t eat|not eat(ing|en)?|wouldn'?t eat|won'?t eat|refused|skipped|no appetite|"
    r"left (his|her|their|the|its)? ?(food|dinner|breakfast|lunch|meal|bowl)|off (his|her|their|its) food|"
    r"not hungry|ate nothing|didn'?t touch)");
// "Ate half", "picked at her food", "left some": ate, but not all of it.
final _ateSome = _r(r"\b(ate (half|some|a little|a bit|part|less)|half (his|her|their|its|the) (food|dinner|breakfast|bowl|meal)|"
    r"picked at|nibbled|barely ate|hardly ate|left some|didn'?t finish|did not finish|not finish(ed)?|only ate)");
final _ateYes = _r(r"\b(ate|eaten|eats|finished|cleared|good appetite|hungry|had (his|her|their|its) "
    r"(food|dinner|breakfast|lunch|meal)|wolfed|scoffed|licked the bowl)");

final _energy = <int, RegExp>{
  1: _r(r"\b(lethargic|very tired|so tired|really tired|exhausted|no energy|listless|very weak|weak|"
      r"wouldn'?t move|barely moved|very low energy|very flat|collapsed)"),
  5: _r(r"\b(very energetic|super energetic|hyper|zoomies|super active|very active|bouncing|bouncy|crazy|"
      r"full of beans|wild|very playful|so playful|really playful)"),
  2: _r(r"(?<!not )(?<!n't )\b(tired|sleepy|quiet|low energy|slow|lazy|flat|sluggish|dull|down|mopey|"
      r"sleeping a lot|slept all day)"),
  4: _r(r"\b(active|playful|energetic|lively|happy|perky|bright|not tired|played|running around)"),
  3: _r(r"\b(normal energy|usual energy|usual self|okay|ok|fine|alright|all right|calm|average|normal)\b"),
};
final _energyNumber = _r(r"\benergy (?:was |is |of |level )?([1-5])\b");

final _toiletNo = _r(r"\b(diarrh\w*|runny|loose (stool|poo|poop)|watery (stool|poo|poop)|vomit\w*|threw up|"
    r"throwing up|sick\b|constipat\w*|strain\w*|blood\w*|no (poo|poop|pee|wee)|did ?n[o']?t (poo|poop|pee|wee)|"
    r"accident|(peed|pooped|pooed|weed) (on|in) (the )?(couch|sofa|bed|floor|carpet|rug)|outside the (box|litter|tray)|"
    r"toilet(ing)? (wasn'?t|not|was not) normal|not normal (poo|poop|pee|toilet))");
final _toiletYes = _r(r"\b(normal (poo|poop|pee|wee|toilet\w*|stool)|good (poo|poop)|pooped|pooed|peed|weed|"
    r"toilet\w* (fine|normal|ok|okay|good)|went (potty|to the toilet)|used the (litter|tray|box))");

final _vomit = _r(r"\b(vomit\w*|threw up|throwing up|thrown up|puked?|sick on)");
final _accident = _r(r"\b(accident|(peed|pooped|pooed|weed) (on|in) (the )?(couch|sofa|bed|floor|carpet|rug|house)|outside the (box|litter|tray))");
final _drinking = _r(r"\b(drinking (a lot|more|loads|lots)|drank (a lot|more|loads|lots)|very thirsty|so thirsty|really thirsty)");

final _weight = _r(r"(\d+(?:[.,]\d+)?)\s*(kg|kgs|kilo|kilos|kilogram|kilograms)\b");
final _weightLb = _r(r"(\d+(?:[.,]\d+)?)\s*(lb|lbs|pound|pounds)\b");

/// Reads one pet's part of a sentence.
SpokenLog readSpokenLog(String text) {
  final out = SpokenLog(text: text.trim());
  // The last thing said about eating wins, so "he didn't eat... oh wait, he did, he
  // finished it" ends as "all". On a tie, the longer phrase ("barely ate" over "ate").
  RegExpMatch? lastOf(RegExp r) => r.allMatches(text).lastOrNull;
  (int, int, String)? best;
  for (final (r, v) in [(_ateSome, 'some'), (_ateNo, 'none'), (_ateYes, 'all')]) {
    final m = lastOf(r);
    if (m == null) continue;
    final cand = (m.end, m.end - m.start, v);
    if (best == null || cand.$1 > best.$1 || (cand.$1 == best.$1 && cand.$2 > best.$2)) best = cand;
  }
  out.ateAmount = best?.$3;
  if (_vomit.hasMatch(text)) out.checks['vomited'] = true;
  if (_accident.hasMatch(text)) out.checks['accident'] = true;
  if (_drinking.hasMatch(text)) out.checks['drinkingMore'] = true;
  final n = _energyNumber.firstMatch(text);
  if (n != null) {
    out.energy = int.parse(n[1]!);
  } else {
    for (final e in _energy.entries) {
      if (e.value.hasMatch(text)) {
        // "normal" alone may be about the toilet; only count it as energy with no toilet words near.
        if (e.key == 3 && _toiletYes.hasMatch(text) && !RegExp(r'\b(okay|ok|fine|calm|usual)\b', caseSensitive: false).hasMatch(text)) {
          continue;
        }
        out.energy = e.key;
        break;
      }
    }
  }
  if (_toiletNo.hasMatch(text)) {
    out.toiletingNormal = false;
  } else if (_toiletYes.hasMatch(text)) {
    out.toiletingNormal = true;
  }
  final w = _weight.firstMatch(text);
  final lb = _weightLb.firstMatch(text);
  if (w != null) {
    out.weightKg = double.tryParse(w[1]!.replaceAll(',', '.'));
  } else if (lb != null) {
    final v = double.tryParse(lb[1]!.replaceAll(',', '.'));
    if (v != null) out.weightKg = double.parse((v * 0.4536).toStringAsFixed(1));
  }
  return out;
}

/// Splits a sentence by pet name and reads each part. With one pet, or no name said,
/// the whole sentence is for [fallback] (the pet the log or notification is about).
Map<String, SpokenLog> readSpokenLogs(String text, List<String> petNames, {required String fallback}) {
  final hits = <(int, String)>[];
  for (final name in petNames) {
    for (final m in RegExp('\\b${RegExp.escape(name)}\\b', caseSensitive: false).allMatches(text)) {
      hits.add((m.start, name));
    }
  }
  hits.sort((a, b) => a.$1.compareTo(b.$1));
  if (hits.isEmpty) return {fallback: readSpokenLog(text)};
  final parts = <String, List<String>>{};
  // Words before the first name belong to the first pet named.
  for (var i = 0; i < hits.length; i++) {
    final from = i == 0 ? 0 : hits[i].$1;
    final to = i + 1 < hits.length ? hits[i + 1].$1 : text.length;
    parts.putIfAbsent(hits[i].$2, () => []).add(text.substring(from, to).trim());
  }
  return {for (final e in parts.entries) e.key: readSpokenLog(e.value.join(' '))};
}
