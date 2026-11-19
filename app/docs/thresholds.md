# Detector thresholds (NFR09)

Every number the change detector uses, where it comes from, and whether the team has agreed it.
The values live in `lib/config/thresholds.dart`.

| Value | Setting | Source | Status |
|---|---|---|---|
| Recent window | last 3 days | Report 4.1, FR13 | Agreed (report) |
| Baseline window | the 28 days before the recent window | Report 4.1, FR13 | Agreed (report) |
| Minimum history | 7 logged days before any flag or Insights | Report 4.1, NFR07 | NFR07 Pending sign-off |
| Unusual score | robust score below -3 (median and MAD) | Report 4.1, Leys et al. (2013) | Agreed (report) |
| MAD scale | 1.4826 | Report 4.1 pseudocode | Agreed (report) |
| Persistence | 2 unusual days out of the last 3 | FR14 | Agreed (report) |
| Direction | energy lower, weight lower, ate "no", toileting "no" only | FR-N03 | Proposed: weight direction to confirm |
| Minimum energy spread | 0.5 points on the 1 to 5 scale | Stack plan open question 10 (MAD can be 0) | Proposed |
| Minimum weight spread | 1.5% of usual weight | Scale error of home scales | Proposed |
| Rare "no" | "no" on at most 1 baseline day in 7 | Report 4.1 ("no is rare in the baseline") | Proposed |
| Thin baseline | under 14 baseline days, shown as an early sign | FR16 | Proposed |

## Why these proposed values

- **Energy spread 0.5.** A pet whose energy is always 4 has a MAD of 0, so any change would score
  infinitely high. With a floor of 0.5, one point lower scores -2 (ignored) and two points lower
  scores -4 (unusual). The report asks for a very conservative cut-off, so a one-point dip is left alone.
- **Weight spread 1.5%.** Home scales wobble by about this much, so a steady pet is flagged once it is
  more than about 4.5% under its usual weight on 2 of the last 3 weigh-ins.
- **Rare "no" at 1 in 7.** "Less than once a week" is a plain rule an owner can understand.
- **Thin baseline at 14 days.** Half of the 28-day window. The flag still shows, with softer wording.

## Synthetic check (report Table 3.2, FR13 and FR14)

`test/synthetic_evaluation_test.dart` makes 600 pets with 60 days of logs each (300 with one planted
change, 300 without) and runs the detector on every day. Results are written to
`test/results/synthetic_evaluation.json`.

| Measure | Result (19 Nov 2026) | Target |
|---|---|---|
| Planted changes flagged within 7 days | 277 of 300 (92%) | at least 80% |
| Eating / energy / toileting | 98% / 79% / 100% | |
| Median days from onset to flag | 1 | |
| Flags before 7 logged days | 0 | 0 (NFR07) |
| Pets without a change that got a flag at some point | 91 of 300, on 158 of 18,000 pet-days | report it |

**Limits worth discussing as a team**

- The synthetic owners are assumptions (logging on 90% of days, 3% ordinary "no" days, energy noise of
  1 point on 30% of days and 2 points on 10%). Changing these changes the numbers.
- Energy is the weakest measure (79%), because a pet whose energy naturally moves by 2 points has a wider
  spread, so a 2-point fall does not stand out.
- False flags: about 1 pet-day in 110 shows a flag on a pet with no real change. Most come from two ordinary
  "no" days close together. A stricter rare rule lowers this but also lowers the hit rate.
- Weight is usually logged weekly, so it rarely has 2 readings in 3 days and is seldom flagged. The team
  should decide whether weight uses its last 3 weigh-ins instead of the last 3 days.
