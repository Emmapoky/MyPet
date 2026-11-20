> **In one line:** A full review of the MyPet app (20 Nov 2026 build) through the eyes of six real pet owners, a comparison with five pet apps on the App Store, and a concrete plan for how MyPet should know what is "normal" for each pet as it grows, by species, size, weight and age.

*Written with AI help (Claude) on 2026-11-20, from the app code on main (commit 70e58e2), the v3 and v5 screenshots, the report and vault notes, App Store listings read on 2026-11-20, and the Pet Nutrition Alliance and AAHA 2021 energy tables. Numbers about food are vet guideline averages; individual pets vary by up to 50%. Check anything you quote.*

# FIT3162 MyPet Pet Owner Review and Baselines

## 1. Verdict in short

MyPet is already stronger than most pet apps in two ways: logging takes 3 taps, and it compares a pet with its own history instead of storing records only. No app we checked (PetNoter, My Pet record maker, 11pets, PetnotePlus, Petfetti) learns a pet's normal or flags change. That is a real, defendable gap.

The weak point is that "normal" is only a 28-day median of the pet's own logs. That breaks for the owners who need the app most: a new pet (7 days of silence), a growing puppy or kitten (growth looks like change), a slowly declining senior (the decline becomes the new normal), and any pet whose weight is logged weekly (weight can never flag). "Ate today: yes/no" also hides half meals and skipped meals.

The top fixes, in order:

1. Weight as a trend, in both directions, with a chart (catches the kidney cat, the stalled puppy and the gaining Labrador).
2. "Ate: All / Some / None" instead of yes/no (still one tap).
3. A starter picture of normal from the profile (species, life stage, size, weight) for the first weeks, then the pet's own baseline.
4. Growth-aware and senior-aware baselines.
5. Simple fact flags from day 1 ("Did not eat 2 days in a row").
6. Household sharing with "logged by" on the timeline.

## 2. How the app works today (what the review is based on)

- Quick log: Ate today Y/N, Energy 1 to 5, Toileting normal Y/N, optional weight, note with mic. "Same as last entry" fills Ate and Toileting.
- Detector (`app/lib/detection/change_detector.dart`): last 3 days against the 28 days before, median and MAD, score above 3 on 2 of the 3 days, nothing before 7 logged days, falls only for energy and weight. Eating is only checked when "No" was rare (1 day in 7 or fewer) in the baseline.
- Insights "Usual range" shows Energy and Ate only. No weight or toileting row, no weight chart.
- The profile weight is set once and the vet PDF prints it as "(profile)" forever. Breed, birth date, notes and health records are never used by the detector.
- No screen invites a second carer; `createdBy` is stored but never shown. On one device, the last log of the day wins.
- Real entry from 19 Nov: "Ate · Energy 5 of 5 · Toileting normal", note "Pooped on the couch". The accident lives only in a note the app cannot read.

## 3. Six owners living with the app

Each persona was followed through day 1, week 1, month 1, month 6 and a sick day.

| Owner and pet | What helps | What confuses or annoys | When they would stop |
|---|---|---|---|
| First-time owner, 10-week toy poodle, 1.2 kg, 4 meals | Adding a pet is easy; "a guess is fine" on birth date | Breed and age change nothing. "Ate today" is wrong for 4 meals: missing breakfast and lunch still logs Yes. Logging at 8 am answers before most meals. No growth chart | Day 4 sick day: two missed meals, floppy, and the app can only say "Insights unlock after 7 days" |
| Experienced owner, 7-year Labrador, 38 kg, gains weight easily | 3 taps; vet export | Weight gain, his main worry, is ignored by design. A vet-ordered diet that works could later show as a warning. Weighed on Sundays only, so weight can never meet "2 of 3 days" | Month 1, when Insights still has no weight line |
| Adopted shy adult cat, unknown age | Gentle tone | No "about 3 to 5 years" option. Cat hides, so "Ate?" is a guess; no "Didn't see". Silent cat, so Check gives nothing. A week of red "Missed" rows | Week 1, put off by guilt rows |
| 15-year cat with early kidney trouble, plus a young cat | Save moves to the next pet; medicine reminders; vet PDF import | No drinking question, the key sign. Shared litter tray makes "Toileting normal" a guess for each cat. Usual energy 2 is called "low" by the wording (3 is hard-coded "usual") | Month 6, when the vet finds 10% weight loss the app never mentioned |
| Busy family, mixed-breed dog, 4 feeders | Quick log | Nobody knows who logged; no invite; the 6 pm log overwrites the 7 am log; double feeding goes unseen; nobody owns the 9 pm reminder | Week 1 |
| 6-month Great Dane, 20 kg heading to 60 kg | Weight field exists | Profile weight frozen at 20 kg; only drops count, against a median he has already outgrown; she wants "growing too fast or too slow?" which matters for giant breeds | Month 2 |

### Where the current detector is wrong, day by day

| Case | What happens | Result |
|---|---|---|
| A. Kidney cat weighed weekly: 4.00, 3.97, 3.93, 3.90, 3.86 kg... about 1.5% a month | Only 1 weight in any 3-day window, so "2 of 3 unusual" can never be met. Even daily, each window sits about 1.5% under a median that falls with her, short of the 4.5% needed | Six months later, 3.6 kg (10% down) and "Everything looks like usual". **Missed** |
| B. Fussy cat skipped 5 of 28 baseline days (18%) | Over the 1-in-7 rare share, so eating checks switch off. Then 3 days of "No" in a row | No flag. **Missed** |
| C. Poodle with energy 5 every day, then vaccine day 29, energy 3 on days 29 and 30 | MAD 0, spread floor 0.5, score -4 twice | "Change noticed: Energy lower". **False alarm** (the vaccine is in Health records but ignored) |
| D. Poodle skips breakfast and lunch, eats dinner | Logged "Ate: Yes" | **Missed**, and risky for a toy breed |
| E. Owner stops logging because the pet is at the vet | Last 3 days empty | No flag possible. **Missed** |
| F. "Toileting normal" plus "Pooped on the couch" | Note not read | Nothing in Insights; one line of text in the PDF. **Missed** |

## 4. How other pet apps compare

| App | Tracks | Sharing | Vet / documents | Normal or baseline? | Notes from reviews |
|---|---|---|---|---|---|
| PetNoter | Vaccines, meds, weight, vet records, expenses, photos | Not mentioned | PDF health report; documents are Premium | None; weight and growth charts only | Duplicate vaccine entry, no vaccine expiry |
| My Pet, The Pet Record Maker | Vitals, weight, measurements, feeding, exercise, meds, incidents, glucose, heat cycles | Cloud sync, share with vet | PDF or HTML emergency and boarding file; document import | Ideal-weight calculator, body condition guides, breed lists (guidance, not personal) | Lost years of data after a phone change; cluttered |
| 11pets | Weight, vitals, activities, meds, documents | Share with vet; more than one pet is paid | Vaccination records, documents | None | Data loss in a migration; limited charts |
| PetnotePlus | Weight, temperature, stool, custom items, routines | Up to 15 family members; alert when someone logs | Documents and CSV export are Premium | None; trend graphs | Wants "every other day" reminders; unclear sharing |
| Petfetti | Meals with calories, water, weight, temperature, glucose, symptoms, poop, pee, meds, grooming, daily check-in | Up to 5 people, 10 pets | Vet-ready PDF | None; condition tracker (diabetes, seizures) | Home-screen widgets and Quick Actions; confirm button hidden under keyboard |

What this tells us:

- **No competitor learns a pet's normal.** MyPet's own-baseline flags are the unique selling point. Keep them central in the pitch.
- **Table stakes MyPet still lacks:** a weight chart, household sharing with alerts, widgets or notification quick actions (being built in the app thread), and "every other day" style schedules.
- **The biggest complaint across apps is lost data** after a phone change or migration. MyPet's Firebase sync and append-only log answer this; say so in the pitch and test a phone swap.
- **Paywalls on sharing and documents annoy users.** MyPet is free; say it.
- **Petfetti logs calories and water.** MyPet should not copy detailed food tracking (out of scope, Dr Yam 1 Oct), but a relative amount (All / Some / None) and an optional drinking question give most of the value for one tap.

## 5. How MyPet should know what is "normal"

### The problem in numbers

Daily energy need from the vet formula used by both the Pet Nutrition Alliance and AAHA (2021): resting need RER = 70 × weight(kg)^0.75 kcal, then multiplied by a life-stage factor (growth under 4 months ×3, growth from 4 months ×2, neutered adult dog ×1.4 to 1.6, neutered adult cat ×1.2 to 1.4, weight-gain-prone dog ×1.0 to 1.2).

| Pet | Rough daily need | 5 g of dry food (~18 kcal) is |
|---|---|---|
| 10-week toy poodle, 1.2 kg (×3) | ~240 kcal | ~8% of the day |
| Neutered adult cat, 4 kg (×1.2) | ~240 kcal | ~8% |
| 6-month Great Dane, 20 kg (×2) | ~1,320 kcal | ~1.4% |
| Neutered Labrador, 38 kg (×1.6) | ~1,710 kcal | ~1% |

So your example is exactly right: the same 5 g is a meaningful change for a small pet and noise for a big dog. And a puppy's need roughly halves per kilo between 3 months and adulthood, while its total keeps rising as it grows.

**Conclusion: never compare absolute amounts across pets.** Compare each pet with its own portion, as a share. That is also how owners think: "she ate half her bowl".

### Recommended approach: three layers

**Layer 1. Starter picture (day 1 to about day 14), from the profile.**

- Use what the profile already holds, plus two small additions: species, birth date (or an "about N years" option for adopted pets), current weight, neutered yes/no, and an optional "usual portion" (amount and meals a day, in the owner's own units: grams, cups, scoops, cans).
- Work out life stage and size class:
  - Size class from expected adult weight (breed list or the owner's guess): toy under 5 kg, small 5 to 10, medium 10 to 25, large 25 to 45, giant over 45.
  - Growing: cats and toy to medium dogs under 12 months; large dogs under 15 to 18 months; giant dogs under 18 to 24 months.
  - Senior: cats from about 11 years; dogs from about 10 (small), 8 (large) and 7 (giant).
- Show it as context, never a judgement, and never as a flag (Dr Yam: no clinical thresholds, FR14). Example card: "Getting to know Coco. Puppies her size usually eat 3 to 4 small meals and gain weight every week. Check the food bag for her daily amount. After 7 days of logs, MyPet learns Coco's own normal."
- Cite the source in the app's About page (AAHA/PNA formula, WSAVA body condition score). This is guidance from a vet body, not a diagnosis.

**Layer 2. The pet's own baseline (from day 7), but measured as shares and trends.**

| Measure | Today | Proposed |
|---|---|---|
| Food | Ate yes/no | "Ate: All / Some / None" (still one tap), optionally per meal for pets with 3 or more meals. Scored as a share of the pet's usual portion, so a toy puppy and a Great Dane are judged on the same scale. If the owner set a portion, the PDF can show "about 50% of usual on 3 days" |
| Weight | Median, falls only, 2 of 3 days | Fit a trend line through all weights (any spacing). Compare the newest weight with the line and with 30 and 90 days ago, as a % of body weight. Each reading counts on its own. Show both directions as neutral facts ("3.1 kg heavier than 3 months ago") |
| Weight noise | Floor 1.5% of median | Floor = max(1.5% of weight, scale resolution: 0.05 kg kitchen scale, 0.3 to 0.5 kg bathroom scale), so a 60 kg dog weighed on a bathroom scale is not flagged for noise |
| Energy | 28-day median, "3 = usual" wording | Keep median and MAD; describe energy relative to the pet ("usual for Biscuit"), never fixed words, so a sleepy senior is not called "low" every day |
| Toileting | Yes/no | Keep, add "Didn't see"; optional "accident indoors" check per pet |

**Layer 3. Baselines that move with the pet's life.**

- **Growing pets:** expect weight to rise. Use the weekly growth rate (% per week) as the measure. Flag gently when growth stalls for 2 weeks or weight falls ("Coco's weight has not gone up for 2 weeks"). Use a shorter baseline window (14 days) for energy and food under 6 months. Every 4 weeks, ask once: "Coco is growing. Has her portion changed?"
- **Change points:** when the owner changes the portion, the food, neuters the pet, moves house, adds a pet or starts medicine, offer a one-tap "Something changed" tag. Start a fresh baseline for the affected measure and note it on flags. Days within 2 days of a vaccination or vet visit (already in Health records) are left out of the baseline and mentioned on any flag ("2 days after vaccination").
- **Seniors:** add a slow 90-day comparison next to the 28-day one, so gradual decline cannot be absorbed into "normal". Prompt a weekly weigh-in. This is case A, the kidney cat, Fafa's story.
- **Adults:** weight gain counts too (relevant to obesity-prone breeds and dieting dogs), worded as a fact, never as a warning. When a vet-set diet is recorded, weight loss is shown as progress, not change.

**Layer 4 (safety net, day 1). Simple fact flags that need no baseline.**

"Did not eat 2 days in a row", "Energy 1 two days running", "Toileting not normal 2 days running". These are counts of what the owner logged, not clinical thresholds, so they stay within Dr Yam's rule. Fixed vet-sourced notes for clear emergencies (for example a male cat straining to pee, Cornell) only if Dr Yam agrees, minuted.

### Report wording

"MyPet starts from what is typical for a pet's species, age and size, using the AAHA and Pet Nutrition Alliance energy guidelines, and after 7 days learns the pet's own normal. Because each measure is a share of the pet's own portion or body weight, a toy poodle and a Great Dane are judged on the same scale, and the baseline moves with the pet as it grows, ages or changes diet."

## 6. Other things missing for an official app

| Area | Gap | Priority |
|---|---|---|
| Household | Invite carers, "logged by" on each entry, a "No" from anyone that day is kept (not overwritten by the last log), one named owner of the reminder | High |
| Gentle logging | "Didn't see" option; replace 7 red "Missed" rows with one line "3 days not logged"; a missed day never feels like failure | High |
| Optional per-pet checks | "Drinking more?", "Accident indoors?", "Vomited?" switched on per pet (seniors, kidney, diabetes, puppies in house training). Each one tap, scored like toileting | Medium |
| Notes that count | The note "Pooped on the couch" should be offered as a tag ("Accident indoors?") so it reaches Insights and the PDF. Voice quick-fill (app thread) can do this | Medium |
| Weight chart | In Insights and the vet PDF; profile weight updates from the latest log | High |
| Store readiness | Privacy policy and data deletion, account export, onboarding that says what MyPet does and does not do, accessibility (200% text), app icon, crash reporting, phone-swap restore test | Before any public release |
| Trust in Check | 98% "Happy or playful" looks more certain than any clip deserves; cap or round shown confidence and say "likely"; silent pets need a picture-only path | Medium |
| Demo data | The "healthy puppy" demo (Pepper) has a flat weight; give it a realistic growth curve so the demo teaches the right normal. Some dog avatars look like cats in the screenshots | Low |
| Reminders | "Every other day" and "every N weeks" schedules (a common request on competitors) | Low |

## 7. Ranked change list for the app

| # | Change | Why | Effort |
|---|---|---|---|
| 1 | Weight trend line, each reading counts, both directions, neutral wording | Catches slow loss (kidney cat), stalled growth, gain in prone breeds | M |
| 2 | Weight chart in Insights and PDF; profile weight follows the latest log | What puppy, diet and senior owners look for first | S |
| 3 | "Ate: All / Some / None" (one tap), scored as a share | Half meals and skipped meals become visible; works for every size | S |
| 4 | Fact flags from day 1 ("Did not eat 2 days in a row") | New owners get help in week 1 | S |
| 5 | Starter picture from the profile (life stage, size, optional portion, neutered, "about N years") | Answers "is this normal for a puppy?" on day 1 | M |
| 6 | Growth mode under 12 to 24 months; 90-day senior comparison | Baseline moves with the pet's life | M |
| 7 | Leave vaccination and vet days out of the baseline; "Something changed" tag resets a measure | Removes false alarms like case C | S |
| 8 | "Didn't see" option and one-line missed days | Honest data, less guilt, fewer drop-outs | S |
| 9 | Household sharing with "logged by" and keep any "No" of the day | Families can use it | L |
| 10 | Optional per-pet checks (drinking, accidents) | Covers kidney and house-training cases without extra taps for others | M |

Items 1 to 4, 7 and 8 fit inside Stage 4 (baseline and flags) and do not change the 3-tap promise (NFR01). Items 5, 6 and 10 need Dr Yam's sign-off because they add profile fields; minute it. Item 9 is Stage 6 and already in the cut order.

## Sources

- Pet Nutrition Alliance, Calculating calories based on pet needs: https://petnutritionalliance.org/wp-content/uploads/2023/03/MER.RER_.PNA_.pdf
- AAHA 2021 Nutrition and Weight Management Guidelines, Box 1: https://www.aaha.org/globalassets/02-guidelines/2021-nutrition-and-weight-management/resourcepdfs/nutritiongl_box1.pdf
- WSAVA body condition score charts (see [[FIT3162 Pet Health Research]])
- App Store listings, read 2026-11-20: PetNoter https://apps.apple.com/app/id1580581463 ; My Pet, The Pet Record Maker https://apps.apple.com/us/app/id566849086 ; 11pets https://apps.apple.com/us/app/id1232470530 ; PetnotePlus https://apps.apple.com/us/app/id1553584485 ; Petfetti https://apps.apple.com/us/app/pet-health-tracker-petfetti/id6471319447

## Related

- [[FIT3162 Context]]
- [[FIT3162 Pet Health Research]]
- [[FIT3162 MyPet Walkthrough and Free Stack Plan]]
- [[FIT3162 Break Plan and Next Steps]]
