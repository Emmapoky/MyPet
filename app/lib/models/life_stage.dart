import 'dart:math' as math;

import '../util/day.dart';
import 'pet.dart';

// Life stage, size class and a rough daily energy need, worked out from the profile.
// Used only as context ("Getting to know Coco") and to pick the right baseline window.
// Never a flag or a judgement (FR14, Dr Yam: no clinical thresholds).
//
// Sources (pet owner review, section 5): AAHA 2021 Nutrition and Weight Management
// Guidelines and the Pet Nutrition Alliance calculator. RER = 70 x kg^0.75 kcal a day,
// times a life-stage factor.

/// Expected adult size of a dog, from the breed or the owner's guess (adult weight).
enum SizeClass { toy, small, medium, large, giant }

String sizeClassName(SizeClass s) => switch (s) {
      SizeClass.toy => 'Toy (under 5 kg)',
      SizeClass.small => 'Small (5 to 10 kg)',
      SizeClass.medium => 'Medium (10 to 25 kg)',
      SizeClass.large => 'Large (25 to 45 kg)',
      SizeClass.giant => 'Giant (over 45 kg)',
    };

String sizeClassShort(SizeClass s) => switch (s) {
      SizeClass.toy => 'toy',
      SizeClass.small => 'small',
      SizeClass.medium => 'medium',
      SizeClass.large => 'large',
      SizeClass.giant => 'giant',
    };

SizeClass sizeFromAdultKg(double kg) => kg < 5
    ? SizeClass.toy
    : kg < 10
        ? SizeClass.small
        : kg < 25
            ? SizeClass.medium
            : kg < 45
                ? SizeClass.large
                : SizeClass.giant;

/// A short list of common breeds and their adult size, so most owners never need to pick.
const _breedSizes = <String, SizeClass>{
  'chihuahua': SizeClass.toy,
  'pomeranian': SizeClass.toy,
  'toy poodle': SizeClass.toy,
  'yorkshire': SizeClass.toy,
  'maltese': SizeClass.toy,
  'shih tzu': SizeClass.small,
  'dachshund': SizeClass.small,
  'jack russell': SizeClass.small,
  'miniature': SizeClass.small,
  'pug': SizeClass.small,
  'cavalier': SizeClass.small,
  'french bulldog': SizeClass.small,
  'shiba': SizeClass.medium,
  'beagle': SizeClass.medium,
  'corgi': SizeClass.medium,
  'cocker': SizeClass.medium,
  'border collie': SizeClass.medium,
  'bulldog': SizeClass.medium,
  'poodle': SizeClass.medium,
  'husky': SizeClass.large,
  'labrador': SizeClass.large,
  'golden': SizeClass.large,
  'german shepherd': SizeClass.large,
  'rottweiler': SizeClass.large,
  'doberman': SizeClass.large,
  'great dane': SizeClass.giant,
  'mastiff': SizeClass.giant,
  'saint bernard': SizeClass.giant,
  'newfoundland': SizeClass.giant,
};

/// The dog's size: picked by the owner, else from the breed, else from an adult weight.
SizeClass? sizeOf(Pet p, {Day? asOf}) {
  if (p.species == Species.cat) return null;
  if (p.adultSize != null) return p.adultSize;
  final b = p.breed.toLowerCase();
  for (final e in _breedSizes.entries) {
    if (b.contains(e.key)) return e.value;
  }
  final months = ageInMonths(p, asOf ?? Day.today());
  if (p.weightKg != null && (months == null || months >= 12)) return sizeFromAdultKg(p.weightKg!);
  return null;
}

int? ageInMonths(Pet p, Day asOf) {
  final b = p.birthDate;
  if (b == null) return null;
  var m = (asOf.year - b.year) * 12 + asOf.month - b.month;
  if (asOf.dayOfMonth < b.dayOfMonth) m--;
  return math.max(0, m);
}

enum LifeStage { baby, growing, adult, senior }

/// Months a pet keeps growing: cats and toy to medium dogs about 12, large dogs 15 to 18,
/// giant dogs 18 to 24 (review section 5, layer 1). The middle of each range.
int growingUntilMonths(Species sp, SizeClass? size) => sp == Species.cat
    ? 12
    : switch (size) {
        SizeClass.large => 16,
        SizeClass.giant => 21,
        _ => 12,
      };

/// Senior from: cats about 11 years; dogs 10 (toy, small), 9 (medium), 8 (large), 7 (giant).
int seniorFromYears(Species sp, SizeClass? size) => sp == Species.cat
    ? 11
    : switch (size) {
        SizeClass.large => 8,
        SizeClass.giant => 7,
        SizeClass.medium || null => 9,
        _ => 10,
      };

/// Everything the profile tells us about where the pet is in its life.
class LifeStageInfo {
  final int? months;
  final LifeStage? stage;
  final SizeClass? size;
  const LifeStageInfo(this.months, this.stage, this.size);

  bool get growing => stage == LifeStage.baby || stage == LifeStage.growing;
  bool get senior => stage == LifeStage.senior;

  /// Under 6 months: food and energy change fast, so a shorter baseline (review layer 3).
  bool get young => months != null && months! < 6;
}

LifeStageInfo lifeStageOf(Pet p, Day asOf) {
  final size = sizeOf(p, asOf: asOf);
  final m = ageInMonths(p, asOf);
  if (m == null) return LifeStageInfo(null, null, size);
  final stage = m < 4
      ? LifeStage.baby
      : m < growingUntilMonths(p.species, size)
          ? LifeStage.growing
          : m >= seniorFromYears(p.species, size) * 12
              ? LifeStage.senior
              : LifeStage.adult;
  return LifeStageInfo(m, stage, size);
}

/// What the detector needs to know about the pet. Plain values, so it can cross to a
/// background isolate.
class PetFacts {
  final bool growing;
  final bool young;
  final bool senior;
  const PetFacts({this.growing = false, this.young = false, this.senior = false});

  factory PetFacts.of(Pet p, Day asOf) {
    final l = lifeStageOf(p, asOf);
    return PetFacts(growing: l.growing, young: l.young, senior: l.senior);
  }
}

/// Resting energy need, kcal a day (AAHA 2021, PNA): 70 x kg^0.75.
double restingEnergy(double kg) => 70 * math.pow(kg, 0.75).toDouble();

/// The life-stage factor range (AAHA 2021 table, PNA). Growth under 4 months x3, from 4
/// months x2; neutered adult dog 1.4 to 1.6, intact 1.6 to 1.8; neutered adult cat 1.2 to
/// 1.4, intact 1.4 to 1.6. Unknown neutering gives the whole range.
(double, double) energyFactor(Pet p, LifeStageInfo l) {
  if (l.stage == LifeStage.baby) return (3, 3);
  if (l.stage == LifeStage.growing) return (2, 2);
  final dog = p.species == Species.dog;
  return switch (p.neutered) {
    true => dog ? (1.4, 1.6) : (1.2, 1.4),
    false => dog ? (1.6, 1.8) : (1.4, 1.6),
    null => dog ? (1.4, 1.8) : (1.2, 1.6),
  };
}

/// Rough daily energy need as a range in kcal, rounded to 10. Null with no weight.
(int, int)? dailyEnergyNeed(Pet p, Day asOf, {double? weightKg}) {
  final kg = weightKg ?? p.weightKg;
  if (kg == null || kg <= 0) return null;
  final l = lifeStageOf(p, asOf);
  final (lo, hi) = energyFactor(p, l);
  int r(double x) => (x / 10).round() * 10;
  final rer = restingEnergy(kg);
  return (r(rer * lo), r(rer * hi));
}
