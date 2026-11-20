import '../util/day.dart';

/// What a timeline entry records (FR03: feeding, medication, toileting and health records).
enum EntryKind {
  /// The 3-tap quick log (FR05, NFR01).
  dailyLog,

  /// A dated health record, such as a vet visit or a vaccination (FR02).
  healthRecord,

  /// The saved result of a behaviour check. The clip itself is never stored (FR-N02).
  behaviourResult,

  /// A reminder occurrence ticked off (FR12).
  taskDone,
}

/// One entry in a pet's timeline.
///
/// Entries are append-only (FR-N04): an edit writes a new entry that names the one it
/// replaces in [supersedes], and a delete writes a new entry with [voided] set. Nothing is
/// overwritten, so every earlier version stays recoverable.
class CareEntry {
  final String id;
  final String petId;
  final EntryKind kind;
  final Day day;
  final DateTime createdAt;
  final String createdBy;
  final String? supersedes;
  final bool voided;
  final Map<String, dynamic> data;

  const CareEntry({
    required this.id,
    required this.petId,
    required this.kind,
    required this.day,
    required this.createdAt,
    required this.createdBy,
    this.supersedes,
    this.voided = false,
    this.data = const {},
  });

  // Daily log fields.
  bool? get ate => data['ate'] as bool?;

  /// "all", "some" or "none". Older logs only have yes/no, read as all or none.
  String? get ateAmount =>
      data['ateAmount'] as String? ?? (ate == null ? null : (ate! ? 'all' : 'none'));

  /// The person said they did not see the pet go (toileting left empty on purpose).
  bool get toiletingUnseen => data['toiletingSeen'] == false;
  int? get energy => (data['energy'] as num?)?.toInt();
  bool? get toiletingNormal => data['toiletingNormal'] as bool?;
  double? get weightKg => (data['weightKg'] as num?)?.toDouble();
  String get note => (data['note'] as String?) ?? '';

  // Health record fields.
  String get title => (data['title'] as String?) ?? '';

  // Behaviour result fields.
  String? get topLabel => data['topLabel'] as String?;
  Map<String, double> get likelihoods =>
      ((data['likelihoods'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k as String, (v as num).toDouble()));
  List<String> get soundEvidence =>
      List<String>.from((data['soundEvidence'] as List?) ?? const []);

  // Task fields.
  String? get reminderId => data['reminderId'] as String?;
  DateTime? get occurrence => data['occurrence'] == null
      ? null
      : DateTime.parse(data['occurrence'] as String);

  Map<String, dynamic> toMap() => {
        'petId': petId,
        'kind': kind.name,
        'day': day.toString(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'createdBy': createdBy,
        'supersedes': supersedes,
        'voided': voided,
        'data': data,
      };

  factory CareEntry.fromMap(String id, Map<String, dynamic> m) => CareEntry(
        id: id,
        petId: m['petId'] as String,
        kind: EntryKind.values.byName(m['kind'] as String),
        day: Day.parse(m['day'] as String),
        createdAt: DateTime.parse(m['createdAt'] as String),
        createdBy: m['createdBy'] as String,
        supersedes: m['supersedes'] as String?,
        voided: (m['voided'] as bool?) ?? false,
        data: Map<String, dynamic>.from((m['data'] as Map?) ?? const {}),
      );
}

/// Valid ranges for logged values (report 4.4: the app checks each value is within range).
class LogRanges {
  static const int energyMin = 1;
  static const int energyMax = 5;
  static const double weightMinKg = 0.1;
  static const double weightMaxKg = 120;

  static String? checkDailyLog(Map<String, dynamic> d) {
    final e = d['energy'];
    if (e != null && (e is! int || e < energyMin || e > energyMax)) {
      return 'Energy must be between $energyMin and $energyMax.';
    }
    final w = d['weightKg'];
    if (w != null && (w is! num || w < weightMinKg || w > weightMaxKg)) {
      return 'Weight must be between $weightMinKg and $weightMaxKg kg.';
    }
    return null;
  }
}
