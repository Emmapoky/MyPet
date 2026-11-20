// Reads the text of a vet document (invoice, vaccination card, visit summary or lab
// report) and pulls out the fields a MyPet health record holds. Runs on the phone,
// with no account and nothing sent anywhere.
//
// It is a small keyword model, not GenAI: each record type has weighted keywords
// (scored like a bag-of-words classifier), and fields are found with patterns that
// were checked against the sample documents in test/vet_record_parser_test.dart.
// Anything it cannot find is listed in [VetRecord.missing] so the app can ask for it.
import 'dart:math' as math;

/// The record types in the health record's drop-down.
enum RecordType { vetVisit, vaccination, medicine, testResults, surgery, other }

const recordTypeNames = {
  RecordType.vetVisit: 'Vet visit',
  RecordType.vaccination: 'Vaccination',
  RecordType.medicine: 'Medicine',
  RecordType.testResults: 'Test results',
  RecordType.surgery: 'Surgery or procedure',
  RecordType.other: 'Other',
};

class VetRecord {
  VetRecord({
    required this.type,
    required this.typeScore,
    this.date,
    this.clinic,
    this.vet,
    this.petName,
    this.weightKg,
    this.vaccines = const [],
    this.medicines = const [],
    this.nextDue,
    this.notes,
  });

  final RecordType type;

  /// How strongly the words point to [type], 0 to 1 (low means "check the type").
  final double typeScore;
  final DateTime? date;
  final String? clinic, vet, petName, notes;
  final double? weightKg;
  final List<String> vaccines, medicines;
  final DateTime? nextDue;

  /// Fields the person should fill in by hand.
  List<String> get missing => [
        if (date == null) 'Date',
        if (clinic == null) 'Clinic',
        if (typeScore < 0.5) 'Type',
        if (type == RecordType.vaccination && vaccines.isEmpty) 'Vaccines',
        if (type == RecordType.medicine && medicines.isEmpty) 'Medicines',
      ];

  /// A short title for the record, such as "Vaccination: Rabies, DHPP".
  String get title {
    final base = recordTypeNames[type]!;
    if (type == RecordType.vaccination && vaccines.isNotEmpty) return '$base: ${vaccines.join(', ')}';
    if (type == RecordType.medicine && medicines.isNotEmpty) return '$base: ${medicines.first}';
    return base;
  }
}

// ---- record type: weighted keywords ----

const _typeWords = <RecordType, Map<String, double>>{
  RecordType.vaccination: {
    'vaccin': 3, 'vaccination certificate': 4, 'immunis': 3, 'immuniz': 3, 'booster': 2, 'rabies': 2,
    'dhpp': 2, 'da2pp': 2, 'fvrcp': 2, 'felv': 1.5, 'bordetella': 1.5, 'leptospir': 1.5, 'lot no': 2,
    'serial': 1, 'next due': 1.5,
  },
  RecordType.medicine: {
    'prescription': 3, 'dispensed': 2.5, 'tablet': 2, 'capsule': 2, ' mg': 1.5, ' ml': 1, 'twice daily': 2,
    'once daily': 2, 'every 12 hours': 2, 'give ': 1, 'dosage': 2, 'refill': 2, 'by mouth': 1.5, 'sid': 1, 'bid': 1,
  },
  RecordType.testResults: {
    'laboratory': 3, 'lab report': 3, 'reference range': 3, 'result': 1.5, 'haematology': 2.5, 'hematology': 2.5,
    'biochemistry': 2.5, 'urinalysis': 2.5, 'specimen': 2, 'alt ': 1, 'creatinine': 1.5, 'wbc': 1.5, 'rbc': 1.5,
  },
  RecordType.surgery: {
    'surgery': 3, 'surgical': 3, 'anaesthe': 2.5, 'anesthe': 2.5, 'procedure': 1.5, 'spay': 2.5, 'neuter': 2.5,
    'castrat': 2.5, 'sutures': 2, 'discharge instructions': 2, 'dental cleaning': 2, 'extraction': 1.5,
  },
  RecordType.vetVisit: {
    'consultation': 3, 'examination': 2.5, 'exam ': 1.5, 'visit': 1.5, 'reason for visit': 3, 'history': 1,
    'physical exam': 2.5, 'assessment': 1.5, 'plan': 0.5, 'follow-up': 1, 'recheck': 1.5, 'temperature': 1,
    'heart rate': 1, 'invoice': 1, 'wellness': 2, 'check-up': 2, 'checkup': 2,
  },
};

(RecordType, double) classifyRecord(String text) {
  final t = ' ${text.toLowerCase()} ';
  final scores = <RecordType, double>{};
  for (final e in _typeWords.entries) {
    var s = 0.0;
    for (final w in e.value.entries) {
      final n = RegExp(RegExp.escape(w.key)).allMatches(t).length;
      if (n > 0) s += w.value * (1 + math.log(n.toDouble())); // diminishing returns
    }
    scores[e.key] = s;
  }
  final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  if (ranked.first.value <= 0) return (RecordType.other, 0);
  // Softmax over scores, so the top type's share says how sure it is.
  final m = ranked.first.value;
  final ex = {for (final e in ranked) e.key: math.exp((e.value - m) / 2)};
  final sum = ex.values.fold(0.0, (a, b) => a + b);
  return (ranked.first.key, ex[ranked.first.key]! / sum);
}

// ---- dates ----

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

final _dateRes = [
  // 2026-11-03
  RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b'),
  // 03/11/2026 or 3.11.2026 (day first, as in Malaysia, Australia and the UK)
  RegExp(r'\b(\d{1,2})[/.](\d{1,2})[/.](\d{2,4})\b'),
  // 3 Nov 2026, 3rd November 2026
  RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3,9})\.?,?\s+(\d{4})\b'),
  // November 3, 2026
  RegExp(r'\b([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b'),
];

DateTime? _date(Match m, int which) {
  int? mon(String s) => _months[s.toLowerCase().substring(0, math.min(3, s.length))];
  try {
    late int y, mo, d;
    switch (which) {
      case 0:
        (y, mo, d) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      case 1:
        (d, mo, y) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
        if (mo > 12 && d <= 12) (d, mo) = (mo, d); // month-first document
        if (y < 100) y += 2000;
      case 2:
        final mm = mon(m[2]!);
        if (mm == null) return null;
        (d, mo, y) = (int.parse(m[1]!), mm, int.parse(m[3]!));
      default:
        final mm = mon(m[1]!);
        if (mm == null) return null;
        (mo, d, y) = (mm, int.parse(m[2]!), int.parse(m[3]!));
    }
    if (mo < 1 || mo > 12 || d < 1 || d > 31 || y < 1990 || y > 2100) return null;
    return DateTime(y, mo, d);
  } catch (_) {
    return null;
  }
}

List<DateTime> findDates(String s) {
  final found = <(int, DateTime)>[];
  for (var i = 0; i < _dateRes.length; i++) {
    for (final m in _dateRes[i].allMatches(s)) {
      final d = _date(m, i);
      if (d != null) found.add((m.start, d));
    }
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final f in found) f.$2];
}

/// The value after a label such as "Date of visit:" on the same line.
String? _after(List<String> lines, RegExp label) {
  for (final l in lines) {
    final m = label.firstMatch(l);
    if (m != null) {
      final rest = l.substring(m.end).replaceFirst(RegExp(r'^[\s:#\-–]+'), '').trim();
      if (rest.isNotEmpty) return rest;
    }
  }
  return null;
}

// ---- vaccines and medicines ----

const _vaccines = {
  'Rabies': r'rabies',
  'DHPP': r'dhpp|da2pp|dhppi|dhlpp|distemper|parvo',
  'Leptospirosis': r'leptospir|\blepto\b',
  'Bordetella': r'bordetella|kennel cough',
  'Canine influenza': r'canine influenza|\bciv\b',
  'Lyme': r'\blyme\b',
  'FVRCP': r'fvrcp|rhinotracheitis|calicivirus|panleukopenia',
  'FeLV': r'felv|feline leuk',
};

List<String> findVaccines(String text) {
  final t = text.toLowerCase();
  return [
    for (final e in _vaccines.entries)
      if (RegExp(e.value).hasMatch(t)) e.key,
  ];
}

final _medLine = RegExp(
    r'([A-Z][A-Za-z\-]+(?:\s[A-Z][A-Za-z\-]+)?)\s*(?:\(([^)]*)\))?\s+(\d+(?:\.\d+)?\s?(?:mg|ml|mcg|g|iu)\b)',
    caseSensitive: true);

/// Common pet medicines sold by brand name, often written without a dose
/// (parasite, flea and tick products, appetite and pain medicines).
const _brands = [
  'Milbemax', 'NexGard Spectra', 'NexGard', 'Bravecto', 'Simparica Trio', 'Simparica', 'Revolution Plus',
  'Revolution', 'Frontline Plus', 'Frontline', 'Advocate', 'Drontal', 'Heartgard', 'Credelio', 'Broadline',
  'Mirtazapine', 'Meloxicam', 'Gabapentin', 'Buprenorphine', 'Amoxicillin', 'Clavamox', 'Prednisolone',
];

List<String> findMedicines(String text) {
  final out = <String>[];
  // Brand names first, then "Name 50 mg" lines.
  for (final b in _brands) {
    if (!RegExp('\\b${RegExp.escape(b)}\\b', caseSensitive: false).hasMatch(text)) continue;
    if (out.any((o) => o.toLowerCase().startsWith(b.toLowerCase()) || b.toLowerCase().startsWith(o.split(' ').first.toLowerCase()))) continue;
    final dose = RegExp('\\b${RegExp.escape(b)}\\b[^\\n]*?(\\d+(?:\\.\\d+)?\\s?(?:mg|ml|mcg|iu))\\b', caseSensitive: false).firstMatch(text);
    out.add(dose == null ? b : '$b ${dose[1]!.replaceAll(' ', '')}');
  }
  for (final m in _medLine.allMatches(text)) {
    final name = m[1]!.trim();
    if (RegExp(r'^(Total|Weight|Dose|Date|Pet|Patient|Rabies|Invoice|Lot|Give|Take|Apply|Inject)$', caseSensitive: false).hasMatch(name)) continue;
    final item = '$name ${m[3]!.replaceAll(' ', '')}';
    final first = name.split(' ').first.toLowerCase();
    if (out.any((o) => o.toLowerCase().startsWith(first))) continue;
    if (!out.contains(item)) out.add(item);
  }
  return out;
}

// ---- everything ----

VetRecord parseVetRecord(String text) {
  final lines = text.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final (type, score) = classifyRecord(text);

  // Date: a labelled visit date first, then the first date in the document.
  DateTime? date;
  final labelled = _after(lines, RegExp(r'(date of (visit|service|vaccination|exam|procedure|surgery)|visit date|service date|^date)\b', caseSensitive: false));
  if (labelled != null) {
    final d = findDates(labelled);
    if (d.isNotEmpty) date = d.first;
  }
  date ??= findDates(text).firstOrNull;

  // Next due date (vaccines, recheck)
  DateTime? next;
  final dueLine = _after(lines, RegExp(r'(next due|due date|next vaccination|revaccinat\w* (date|by)|recheck|follow-up|follow up)', caseSensitive: false));
  if (dueLine != null) next = findDates(dueLine).firstOrNull;

  // Clinic: a line naming a clinic or hospital, usually the letterhead.
  String? clinic = _after(lines, RegExp(r'^(clinic|hospital|practice)\s*:', caseSensitive: false));
  clinic ??= lines.where((l) => RegExp(r'(veterinary|vet clinic|animal hospital|animal clinic|pet hospital|\bvets?\b)', caseSensitive: false).hasMatch(l) && l.length < 60 && !l.contains(':')).firstOrNull;

  // Vet: "Dr Name" or a labelled vet.
  String? vet = _after(lines, RegExp(r'(attending (vet|veterinarian)|veterinarian|vet|doctor|clinician)\s*:', caseSensitive: false));
  vet ??= RegExp(r'\bDr\.?\s+[A-Z][a-zA-Z\-]+(?:[ \t]+[A-Z][a-zA-Z\-]+){0,2}').firstMatch(text)?[0];

  final petName = _after(lines, RegExp(r"^(patient|pet|pet name|patient name|animal)(?:'s name)?\s*:", caseSensitive: false))
      ?.split(RegExp(r'\s{2,}|\s+(species|breed|sex|age|dob)\b', caseSensitive: false))
      .first
      .trim();

  // Weight, in kg (pounds are converted).
  double? weight;
  final wm = RegExp(r'weight\s*:?\s*(\d+(?:\.\d+)?)\s*(kg|kgs|lb|lbs|pounds)\b', caseSensitive: false).firstMatch(text);
  if (wm != null) {
    final v = double.parse(wm[1]!);
    weight = wm[2]!.toLowerCase().startsWith('k') ? v : double.parse((v * 0.4536).toStringAsFixed(1));
  }

  // The vet's own notes: what follows "Assessment", "Findings", "Diagnosis" or "Notes".
  final notes = _after(lines, RegExp(r'^(assessment|findings|diagnosis|comments|notes|summary|plan)\s*:', caseSensitive: false));

  return VetRecord(
    type: type,
    typeScore: score,
    date: date,
    clinic: clinic,
    vet: vet,
    petName: petName,
    weightKg: weight,
    vaccines: findVaccines(text),
    medicines: type == RecordType.vaccination ? const [] : findMedicines(text),
    nextDue: next,
    notes: notes,
  );
}
