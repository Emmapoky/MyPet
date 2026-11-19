import '../util/day.dart';

/// Cats and dogs only (report Table 3.1, FR01).
enum Species { cat, dog }

/// FR01 archive and FR19 lifecycle states.
enum PetStatus { active, archived, rehomed, deceased }

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
      );
}
