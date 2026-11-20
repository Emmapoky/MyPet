/// Every threshold, weight and window the detector uses (NFR09).
///
/// The reason for each value is written next to it and in app/docs/thresholds.md.
/// Values marked "proposed" are not in the report and need the team's agreement.
class Thresholds {
  /// Days compared against the baseline: "the last three days" (report 4.1, FR13).
  static const int recentDays = 3;

  /// Baseline window: "the 28 days before them" (report 4.1, FR13).
  static const int baselineDays = 28;

  /// No flags and no Insights below 7 days of logs (NFR07, report 4.1).
  static const int minLoggedDays = 7;

  /// A robust score above 3 counts as unusual (report 4.1, Leys et al. 2013).
  static const double scoreCutoff = 3.0;

  /// Makes MAD comparable to a standard deviation for normal data (report 4.1 pseudocode).
  static const double madScale = 1.4826;

  /// A flag needs this many unusual days out of [recentDays] (FR14: 2 of the last 3).
  static const int unusualDaysNeeded = 2;

  /// Proposed. Smallest spread used for energy (1 to 5) when the baseline is perfectly
  /// steady and MAD is 0 (stack plan open question 10). With a steady pet, a drop of
  /// 1 point scores -2 and is ignored, and a drop of 2 points scores -4 and counts as
  /// unusual. Once a pet's energy varies (MAD of 1), the real spread of 1.48 is used.
  /// Kept high on purpose: the report asks for a very conservative cut-off (FR-N03).
  static const double minEnergySpread = 0.5;

  /// Proposed. Smallest spread for weight, as a share of the pet's usual weight. At 1.5%,
  /// a steady pet is flagged once it has lost more than about 4.5% of its usual weight.
  /// Kitchen and bathroom scales vary by about this much, so smaller changes are noise.
  static const double minWeightSpreadShare = 0.015;

  /// Proposed. A yes/no answer counts as unusual when it is the concerning answer and
  /// that answer was given on at most this share of baseline days ("no is rare in the
  /// baseline", report 4.1). One day in seven is "less than once a week".
  static const double rareShare = 1 / 7;

  /// Proposed. Below this many baseline days the flag is labelled early and its wording
  /// is softened (FR16, thin baseline). Half of the 28-day window.
  static const int thinBaselineDays = 14;

  /// Proposed (pet owner review, layer 3). Pets under 6 months change fast, so food and
  /// energy are compared with the last 14 days instead of 28.
  static const int youngBaselineDays = 14;

  /// Proposed. A measure needs this many baseline days before it is judged against them.
  /// Fewer, for example just after a "Something changed" tag, and only day-1 facts apply.
  static const int minBaselineReadings = 4;

  /// Proposed (review change 7). The day of a vet visit, vaccination or procedure and the
  /// 2 days after it are left out of the baseline: pets are often quiet or off food then.
  static const int vetDaysLeftOut = 2;

  /// Proposed (review change 1). How far back weight readings are used for the trend:
  /// 60 days for adults, 28 for growing pets (they change fast), 90 for seniors.
  static const int weightDays = 60;
  static const int growingWeightDays = 28;
  static const int slowWeightDays = 90;

  /// Proposed. A kitchen scale reads to about 0.05 kg, so smaller changes are never news.
  /// The weight noise floor is the larger of this and [minWeightSpreadShare] of the weight.
  static const double scaleResolutionKg = 0.05;

  /// Proposed. A slow change in weight is measured over 30 days (and 90 for seniors), and
  /// needs readings at least 14 days apart. It is reported at 3 times the noise floor,
  /// about 4.5% of body weight, the same size as a single-reading change.
  static const int driftDays = 30;
  static const int minDriftDays = 14;

  /// Proposed (review layer 3). A growing pet whose weight has not gone up for 2 weeks.
  static const int growthStallDays = 14;
}
