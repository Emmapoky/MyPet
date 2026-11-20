import '../util/day.dart';
import 'life_stage.dart';

/// How many pet colours there are (MyPetColors.petAccents).
const petColourCount = 8;

/// Names of the pet colours, in the same order (tokens v3.2 petAccentNames).
const petColourNames = ['Violet', 'Berry', 'Periwinkle', 'Plum', 'Ocean', 'Rose', 'Honey', 'Mauve'];

/// The pet's colour: the one picked, or a steady one from its id.
int petColourIndex(Pet p) => (p.colour ?? p.id.codeUnits.fold<int>(0, (a, b) => a + b)) % petColourCount;

/// Cats and dogs only (report Table 3.1, FR01).
enum Species { cat, dog }

/// FR01 archive and FR19 lifecycle states.
enum PetStatus { active, archived, rehomed, deceased }

/// How a pet's status reads to a person.
String statusWord(PetStatus s) => switch (s) {
      PetStatus.active => 'Active',
      PetStatus.archived => 'Archived',
      PetStatus.rehomed => 'Rehomed',
      PetStatus.deceased => 'Passed away',
    };

/// A pet profile (FR01): species, breed, birth date, weight.
class Pet {
  final String id;
  final String name;
  final Species species;
  final String breed;
  final Day? birthDate;
  final double? weightKg;
  final PetStatus status;

  /// Carers who can read and write this pet's data (NFR06).
  final List<String> carerIds;
  final DateTime createdAt;

  /// Index into the pet colours the person picked (null: the app picks one).
  final int? colour;

  /// Profile photo file name in the app's photo folder on this phone (null: illustration).
  final String? photo;

  /// Neutered or spayed (null: not said). Changes the energy guide only.
  final bool? neutered;

  /// The birth date is a guess from "about N years" (adopted pets).
  final bool birthEstimated;

  /// Expected adult size for a dog, when the breed does not say it.
  final SizeClass? adultSize;

  /// Usual portion in the owner's own words and units, such as "60 g" or "1 cup".
  final String portion;
  final int? mealsPerDay;

  /// Extra one-tap questions on the daily log for this pet: drinking, accidents, vomited.
  final List<String> checks;

  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed = '',
    this.birthDate,
    this.weightKg,
    this.status = PetStatus.active,
    required this.carerIds,
    required this.createdAt,
    this.colour,
    this.photo,
    this.neutered,
    this.birthEstimated = false,
    this.adultSize,
    this.portion = '',
    this.mealsPerDay,
    this.checks = const [],
  });

  bool get isActive => status == PetStatus.active;

  Pet copyWith({
    String? name,
    Species? species,
    String? breed,
    Day? birthDate,
    bool clearBirthDate = false,
    double? weightKg,
    bool clearWeight = false,
    PetStatus? status,
    List<String>? carerIds,
    int? colour,
    String? photo,
    bool clearPhoto = false,
    bool? neutered,
    bool clearNeutered = false,
    bool? birthEstimated,
    SizeClass? adultSize,
    bool clearAdultSize = false,
    String? portion,
    int? mealsPerDay,
    bool clearMeals = false,
    List<String>? checks,
  }) =>
      Pet(
        id: id,
        name: name ?? this.name,
        species: species ?? this.species,
        breed: breed ?? this.breed,
        birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
        weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
        status: status ?? this.status,
        carerIds: carerIds ?? this.carerIds,
        createdAt: createdAt,
        colour: colour ?? this.colour,
        photo: clearPhoto ? null : (photo ?? this.photo),
        neutered: clearNeutered ? null : (neutered ?? this.neutered),
        birthEstimated: birthEstimated ?? this.birthEstimated,
        adultSize: clearAdultSize ? null : (adultSize ?? this.adultSize),
        portion: portion ?? this.portion,
        mealsPerDay: clearMeals ? null : (mealsPerDay ?? this.mealsPerDay),
        checks: checks ?? this.checks,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'species': species.name,
        'breed': breed,
        'birthDate': birthDate?.toString(),
        'weightKg': weightKg,
        'status': status.name,
        'carerIds': carerIds,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'colour': ?colour,
        'photo': ?photo,
        'neutered': ?neutered,
        if (birthEstimated) 'birthEstimated': true,
        'adultSize': ?adultSize?.name,
        if (portion.isNotEmpty) 'portion': portion,
        'mealsPerDay': ?mealsPerDay,
        if (checks.isNotEmpty) 'checks': checks,
      };

  factory Pet.fromMap(String id, Map<String, dynamic> m) => Pet(
        id: id,
        name: m['name'] as String,
        species: Species.values.byName(m['species'] as String),
        breed: (m['breed'] as String?) ?? '',
        birthDate:
            m['birthDate'] == null ? null : Day.parse(m['birthDate'] as String),
        weightKg: (m['weightKg'] as num?)?.toDouble(),
        status: PetStatus.values.byName((m['status'] as String?) ?? 'active'),
        carerIds: List<String>.from(m['carerIds'] as List),
        createdAt: DateTime.parse(m['createdAt'] as String),
        colour: (m['colour'] as num?)?.toInt(),
        photo: m['photo'] as String?,
        neutered: m['neutered'] as bool?,
        birthEstimated: (m['birthEstimated'] as bool?) ?? false,
        adultSize: m['adultSize'] == null ? null : SizeClass.values.asNameMap()[m['adultSize']],
        portion: (m['portion'] as String?) ?? '',
        mealsPerDay: (m['mealsPerDay'] as num?)?.toInt(),
        checks: List<String>.from((m['checks'] as List?) ?? const []),
      );
}

/// Optional one-tap checks a pet can have on its daily log (review section 6).
class PetChecks {
  static const drinking = 'drinking';
  static const accidents = 'accidents';
  static const vomited = 'vomited';
  static const all = [drinking, accidents, vomited];

  /// The data key on a daily log, true for the concerning answer.
  static String key(String check) => switch (check) {
        drinking => 'drinkingMore',
        accidents => 'accident',
        _ => 'vomited',
      };

  static String question(String check) => switch (check) {
        drinking => 'Drinking more than usual',
        accidents => 'Accident indoors',
        _ => 'Vomited',
      };

  static String why(String check) => switch (check) {
        drinking => 'Useful for older cats and dogs, kidneys or diabetes',
        accidents => 'Useful for puppies in house training and older pets',
        _ => 'Useful for pets with a sensitive tummy',
      };
}
