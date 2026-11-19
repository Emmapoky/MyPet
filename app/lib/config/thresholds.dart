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
}
