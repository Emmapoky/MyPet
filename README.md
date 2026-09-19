# MyPet 🐾

**A distributed pet monitoring system.** Built for **FIT3161 Computer Science Project 1**, topic 22.

MyPet is a multi-pet care platform: a live dashboard, health records, recurring feeding and
medication schedules with real-time alerts, quick-entry behaviour logging, and a background
machine-learning module that learns each animal's own normal routine and flags when it shifts.

Native iOS, SwiftUI, Swift 5, **no third-party dependencies**. Everything runs on device.

> **Note on the stack.** The Master App Discovery Prompt in your Downloads folder specifies
> React Native / Expo / TypeScript. This is built as a **native SwiftUI app** instead, because
> you asked for a README covering how to launch and play with it *in Xcode*. If the team later
> needs Android too, section 11 covers what that would take.

---

## What changed in September 2026

These updates follow team Meetings 1–3 and the supervisor meetings with Dr Yam
on 17 Aug and 18 Sep 2026.

| Change | Why |
| --- | --- |
| **One app, no hardware and no AI account.** A "Why MyPet" section in Settings and chips on Today spell it out: free, no collar, about 3 taps a day, private, not a diagnosis | Affordability was the main pitch feedback, and Dr Yam ruled out anything that needs a ChatGPT account or paid tokens |
| **Simpler daily log.** Did they eat (None, A little, Half, Most, All), energy, mood chips, toileting yes/no, an optional weigh-in, and notes. **Sleep, water and active minutes are gone** | Dr Yam asked for "have you fed them today", not detail, and to drop sleep. The engine still accepts older data with those fields |
| **New Check tab (middle).** Photo mode with a live camera viewfinder, or Sound mode with a waveform. A **timer at the bottom** runs a 3-second hold for photos or a 10-second minimum for sound. The result is a behaviour likelihood such as "High possibility Biscuit is hungry" | Dr Yam's behaviour feature. It starts with photo or sound, and video comes later. The result is behaviour only, never a diagnosis. It uses a placeholder model for now; FYP2 swaps in a trained Core ML classifier |
| **Quick capture (Lingsha's idea).** Type or dictate one sentence and MyPet fills in the log. You confirm, then save. It also runs from Siri or Shortcuts ("Log my pet in MyPet") | This is Lingsha's Shortcut demo rebuilt to run inside the app, on the phone, with no external AI |
| **Cats and dogs only.** The species picker offers Dog or Cat and nothing else. The demo household is Biscuit (dog) and Mochi (cat); Pip the rabbit is gone | Scope decision on 27 Aug, confirmed by Dr Yam |
| **Vet summary (FR04).** Pet → ⋯ → *Summary for the vet*. Pick a date range (7, 30 or 90 days, or custom) and share it as plain text that opens without the app | Listed in scope but missing from the build |
| **Daily "haven't logged yet" reminder at 8 PM**, skipped once every pet is logged that day | The users-stop-logging risk, rated increased at M3. Dr Yam: remind people, you can't force them |
| **Insights charts wait for 7 logged days** before showing (NFR07). This may rise to about 15 if the team agrees | So a couple of odd days don't worry an owner |
| **Pet profile has "Allergies or existing conditions"**, and no flag advice names a disease | Pre-existing conditions come from Erwyna's prototype. No disease names comes from FR-N01 |
| **More colour and room for the logo.** A coral, teal and sun palette, a gradient hero on Today, and tinted pages. Settings moved behind the gear on Today | This was feedback on the plain white UI. To use your logo, drop the image from the slides into `Assets.xcassets/AppLogo` and it replaces the paw placeholder everywhere |

Camera and microphone are only used while the Check tab is open and only after you tap. The
Simulator has no camera, so the viewfinder shows a placeholder there, with a "Choose a photo" button.

Debug launch arguments (Scheme → Run → Arguments) for demos: `-MyPetInitialTab check`, or
`-MyPetQuickCapture "Biscuit ate half, a bit sleepy"`.

## Table of contents

1. [Get it running (5 minutes)](#1-get-it-running-5-minutes)
2. [Things to try, in order](#2-things-to-try-in-order)
3. [What's in the repo](#3-whats-in-the-repo)
4. [Architecture](#4-architecture)
5. [The behaviour model, explained](#5-the-behaviour-model-explained)
6. [The distributed layer](#6-the-distributed-layer)
7. [Notifications and alerts](#7-notifications-and-alerts)
8. [The seeded demo household](#8-the-seeded-demo-household)
9. [Tests](#9-tests)
10. [Mapping to the FIT3161 deliverables](#10-mapping-to-the-fit3161-deliverables)
11. [Known limits and where it goes next](#11-known-limits-and-where-it-goes-next)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Get it running (5 minutes)

**You need:** a Mac and **Xcode 26 or later**. Nothing else — no package manager, no backend,
no accounts, no API keys.

```bash
open ~/Desktop/App_Creation/MyPet/MyPet.xcodeproj
```

Then in Xcode:

1. Pick a simulator from the dropdown at the top — **iPhone 17 Pro** is what this was verified on.
2. Press **⌘R**.
3. It builds and launches straight onto the dashboard, already populated.

**Run the tests:** press **⌘U**. **54 tests across 12 suites** should pass in well under a second.

### Verified state

As committed, on Xcode 26.6 / iOS 26.5 simulator:

| Check | Result |
| --- | --- |
| `xcodebuild build` | ✅ succeeds, no errors |
| `xcodebuild test` | ✅ 54/54 pass |
| Launch on iPhone 17 Pro | ✅ dashboard renders, detector fires on seed data |
| Runtime log | ✅ no exceptions, no crashes |

### If the project won't open

`.xcodeproj` files are fiddly. The Swift source is the real deliverable; the project file is
just packaging. This fallback always works:

1. Xcode → **File → New → Project → iOS → App**
2. Product Name `MyPet` · Interface **SwiftUI** · Language **Swift** · Testing System **Swift Testing** · Storage **None**
3. Save it somewhere temporary.
4. Delete the generated `ContentView.swift` and `MyPetApp.swift` (**Move to Trash**).
5. Drag this repo's `MyPet` folder into the Xcode sidebar. Tick **Copy items if needed** and
   **Create groups**; make sure the `MyPet` target is checked.
6. Do the same with `MyPetTests`, targeting the `MyPetTests` target.
7. Select the project → **Info** → set **iOS Deployment Target** to **18.0**.
8. ⌘R.

---

## 2. Things to try, in order

The app opens with ten weeks of seeded history, so there is something to look at immediately.

### a. Read the flags on the dashboard

**Biscuit** (golden retriever) has been declining for four days. You should see several cards:
**Lethargy**, **Appetite drop**, and a red **Multiple systems affected**.

Tap **"Why this flag?"** on any card. It expands to show model confidence, how many days of the
window the pattern held, the raw anomaly score, and each metric's percentage change and robust
z-score against that pet's own baseline. Nothing is hidden.

### b. Watch the model change its mind

Go to **Insights** (bottom tab) and pick a pet from the top-right menu. Each metric is charted
with the pet's learned **normal band** shaded behind it. Where the line leaves the band, the
points turn amber or orange — that is precisely what the detector reacts to.

Now go to **Settings → Behaviour detection** and drag **Sensitivity** to *Relaxed*. Return to the
dashboard: some flags drop away. Drag it to *Very alert*: more appear. Every change re-runs the
model across all pets immediately.

### c. Log a day and watch the pipeline fire

From the dashboard tap **Log today** on any pet. Everything is pre-filled from that pet's recent
pattern, so a normal day takes two taps. Drag **Meals eaten** down to near zero and save.

Then go to **Settings → Event stream**. You will see the event chain that just ran:

```
Behaviour logged  →  Analysis started  →  Watch: Appetite drop  →  Analysis finished · 2 flags
```

That is the asynchronous background pipeline. The view never asked for an analysis; it published
an event, and the analysis service picked it up on a background executor.

### d. Trigger a decline on demand

Open any pet → **⋯ menu** → **Simulate a decline (demo)**. This writes three days of reduced
appetite and low energy into that pet's history and re-runs the model. Good for
demonstrating detection live without waiting a week.

### e. Break the network on purpose

**Settings → Sync**:

1. Turn on **Offline mode**.
2. Go and edit a pet, tick off some tasks, log a day.
3. Come back — **Queued changes** is counting up, and the dashboard's cloud icon has an amber badge.
4. Turn **Offline mode** off and press **Sync now**.
5. The queue drains to zero and **Lamport clock** advances.

Also try **Simulate backend failure** — the sync fails, the state goes red, and *the outbox is
still intact*. Nothing is lost.

### f. Merge an edit from another carer's device

Open a pet → **⋯ menu** → **Simulate another carer's edit**. This injects a change into the
backend as though a second device made it, then syncs. The weight updates and a note appears.
If you had a conflicting local edit queued, **Settings → Sync → Conflicts resolved** shows which
version won and why.

### g. Schedule something

**Schedule** tab → **+**. Add a twice-daily medication with an end date. Switch to **All tasks**
to see the rule; switch back to **By day** and step forward with the arrows to see it expand
across days, then stop at the end date.

---

## 3. What's in the repo

```
MyPet/
├─ MyPet.xcodeproj/          Xcode project (+ shared scheme, so ⌘U works from a clean checkout)
├─ MyPet/
│  ├─ MyPetApp.swift         App entry; re-syncs and re-analyses on foreground
│  ├─ Models/
│  │  ├─ Pet.swift              Pet aggregate + Syncable protocol
│  │  ├─ BehaviorLog.swift      Daily observations + BehaviorMetric (units, directionality)
│  │  ├─ CareTask.swift         Recurrence rules → TaskOccurrence expansion
│  │  ├─ HealthRecord.swift     Vaccinations, medication, vet visits, weigh-ins
│  │  └─ BehaviorFlag.swift     Flags, severity, evidence, baselines
│  ├─ ML/
│  │  ├─ Statistics.swift       Median, MAD, EWMA, OLS slope
│  │  ├─ BaselineModel.swift    Per-pet baselines + DetectionConfig + FeatureExtractor
│  │  └─ AnomalyDetector.swift  Syndrome scoring, severity, explanation generation
│  ├─ Services/
│  │  ├─ EventBus.swift              Actor-based pub/sub (AsyncStream)
│  │  ├─ PersistenceService.swift    Atomic JSON snapshot store
│  │  ├─ SyncService.swift           Outbox, Lamport clocks, LWW conflict resolution
│  │  ├─ NotificationService.swift   Rolling-horizon local alert scheduling
│  │  └─ BehaviorAnalysisService.swift  Debounced background analysis + flag merging
│  ├─ Store/MyPetStore.swift    @MainActor @Observable coordinator — the only mutator
│  ├─ Views/                    Dashboard, Pets, PetDetail, Tasks, QuickLog, Insights, Settings
│  ├─ Components/               FlagCard, sparkline, badges, shared pieces
│  └─ Support/                  Theme (light+dark tokens), DemoData (seeded household)
└─ MyPetTests/MyPetTests.swift  54 tests, 12 suites
```

---

## 4. Architecture

Modular services behind a single coordinator. **No view ever touches a service.**

```
        ┌──────────────── SwiftUI Views ────────────────┐
        │  Dashboard · Pets · Schedule · Insights · ⚙︎  │
        └───────────────────┬───────────────────────────┘
                            │  read state / call intents
                ┌───────────▼────────────┐
                │      MyPetStore        │  @MainActor @Observable
                │  single source of truth│  updates UI first, fans work out after
                └───┬───┬───┬───┬────────┘
        ┌───────────┘   │   │   └────────────────┐
        ▼               ▼   ▼                    ▼
 ┌────────────┐ ┌───────────┐ ┌──────────────┐ ┌──────────────┐
 │Persistence │ │   Sync    │ │ Notification │ │  Behaviour   │
 │  (actor)   │ │  (actor)  │ │   (actor)    │ │  Analysis    │
 │            │ │           │ │              │ │   (actor)    │
 │atomic JSON │ │ outbox +  │ │ 3-day rolling│ │ debounced,   │
 │write-then- │ │ Lamport + │ │ horizon, 64- │ │ off main     │
 │move        │ │ LWW merge │ │ alert budget │ │ actor        │
 └────────────┘ └─────┬─────┘ └──────────────┘ └──────┬───────┘
                      │                               │
                      ▼                               ▼
              ┌───────────────┐              ┌──────────────────┐
              │ SyncBackend   │              │ AnomalyDetector  │
              │ (protocol)    │              │ + BaselineModel  │
              │ InMemory impl │              │ pure value types │
              └───────────────┘              └──────────────────┘
                      ▲                               ▲
                      └────────── EventBus ───────────┘
                          actor pub/sub, AsyncStream
```

**Why it is shaped this way:**

- **Every service is an `actor`.** File I/O, network simulation and model scoring all run off the
  main actor, so the UI never blocks. The compiler enforces the isolation rather than a convention.
- **The store updates its own state first, then dispatches.** A carer taps *save* and the screen
  changes immediately; persistence, sync enqueue, re-analysis and alert rescheduling all happen
  behind it. Nothing user-facing waits on I/O.
- **The event bus decouples writes from reactions.** `record(log:)` does not know the analysis
  service exists. It publishes `.logRecorded`; whoever cares, reacts. Adding a new reaction means
  adding a subscriber, not editing the write path.
- **The detector is a pure value type.** No I/O, no clock of its own (`asOf` is always injected),
  no shared state — which is why the model is testable in microseconds and why swapping in a
  Core ML implementation touches exactly one call site.

---

## 5. The behaviour model, explained

### What it is

An **unsupervised, per-subject anomaly detector**. It learns each pet's own baseline, converts
recent days into robust z-scores against it, and combines correlated metrics into named
*syndromes*.

### Why not a trained classifier

A supervised model needs labelled sick/healthy days *per animal*. No household has that, and no
public dataset supplies it at the granularity of "this specific cat". Per-subject anomaly
detection sidesteps the labelling problem entirely and works for any species from day one.

The honest trade-off: it detects **change**, not **diagnosis**. That is exactly the claim the app
makes to the user — and no more.

### The pipeline

```
BehaviorLogs
   │
   ├─ FeatureExtractor ──► per-metric daily series (gaps preserved, never interpolated)
   │
   ├─ BaselineModel ─────► median + scaled MAD + EWMA per metric
   │                       over a 28-day trailing window
   │                       ⚠️ EXCLUDING the evaluation window
   │
   ├─ AnomalyDetector
   │     ├─ robust z per metric per day:  z = (x − median) / max(scaledMAD, noiseFloor)
   │     ├─ directional gate: only concerning directions count
   │     ├─ syndrome score: Σ(weight × min(|z|/4, 1)) / Σweight, primary metric must fire
   │     ├─ persistence gate: how many days of the 3-day window tripped
   │     ├─ severity: 0.65 × score + 0.35 × persistenceRatio, then confidence downgrade
   │     └─ special cases: weight (OLS slope, %/week) · elimination (rate comparison)
   │
   └─ BehaviorFlags with evidence, confidence, and generated explanation
```

### Four decisions that carry most of the weight

**1. Robust statistics, not mean and σ.** Median and MAD instead. One fasting day before surgery
would drag a mean baseline down far enough to mask the following week of genuinely reduced eating.
The median shrugs it off. There is a test for exactly this (`scaledMAD` vs `standardDeviation`
under a single outlier).

**2. The evaluation window is excluded from its own baseline.** If it weren't, a pet that stopped
eating for three days would quietly pull its own baseline down, and the anomaly would *shrink*
each day it persisted — precisely backwards from what a carer needs.

**3. Persistence gating.** A syndrome must trip on ≥2 of the 3 evaluation days before it escalates
past *Watch*. Animals have off days, and a detector that cries wolf gets muted — which is worse
than one that says nothing, because a muted app gives no medication reminders either.

**4. Directionality.** Eating *less* is a symptom; eating slightly more is not. Every metric
declares which direction of deviation is clinically concerning, so the model never raises an alarm
about a good week.

### Guards against nonsense

| Failure mode | Guard |
| --- | --- |
| Pet with a rigid routine → MAD = 0 → infinite z | Per-metric `noiseFloor`; `effectiveSpread` never below it |
| Not enough history → confident nonsense | `isEstablished` needs ≥7 days (≥4 for sparse metrics); nothing is flagged without it |
| Sparse metrics (weight logged weekly) | Longer 120-day window; slope-based rule instead of day-level z |
| Thin baseline → overconfident wording | Confidence blends baseline depth and window coverage; <0.4 downgrades severity a level |
| Weak signals inventing a syndrome | A **primary** metric must exceed threshold; supporting signals alone score zero |
| Several syndromes from one bad day | Multi-system escalation requires each constituent to have persisted ≥2 days |

### The syndromes

| Syndrome | Primary metrics | Supporting |
| --- | --- | --- |
| **Appetite drop** | appetite ↓ | energy ↓, weight ↓ |
| **Lethargy** | activity ↓, energy ↓ | sleep ↑, appetite ↓ |
| **Sleep pattern shift** | sleep ↕ | energy ↓, activity ↕ |
| **Water intake shift** | water ↕ | appetite ↓ |
| **Weight trend** | OLS slope over 30 days, as % body weight per week | — |
| **Toileting change** | abnormal-day rate vs that pet's own historical rate | — |
| **Multiple systems** | ≥3 persistent syndromes at once | — |

### Swapping in Core ML

`AnomalyDetector` is a value type behind `BehaviorAnalysisService`. A Core ML replacement conforms
to the same `analyze(pet:logs:asOf:) -> [BehaviorFlag]` shape. Nothing in the views, the store or
persistence knows which implementation is running.

---

## 6. The distributed layer

The brief calls for a *distributed* system with real-time synchronisation. Here is what is real
and what is simulated, stated plainly.

**Real:** the outbox, offline-first write path, Lamport clock ordering, last-writer-wins conflict
resolution, convergence guarantees, the event bus, and the whole async pipeline. All unit-tested.

**Simulated:** the server. `InMemorySyncBackend` is an actor with artificial latency and an
injectable failure mode, standing behind a three-method `SyncBackend` protocol.

That split is deliberate. It makes the distributed *behaviour* demonstrable and testable without
provisioning infrastructure for a student project, and swapping in Firebase, Supabase or a bespoke
API means writing one conforming actor — nothing above that line changes.

### Why Lamport clocks rather than timestamps

Device clocks disagree. A phone running five minutes fast would win every conflict forever, and
its stale edits would keep overwriting a correct device. A Lamport clock gives a consistent causal
ordering regardless of wall-clock skew. Ties (genuine concurrent edits) break on node ID, so
**every device independently reaches the same answer** — that is what makes it converge rather
than oscillate.

### Why last-writer-wins

LWW can lose a concurrent edit's content, but it always converges, needs no user intervention, and
cannot corrupt a record. For a household care log — where two carers editing the *same field* of
the *same record* in the same instant is rare — that is the right exchange. A field-level CRDT
would preserve more, at a complexity cost this project does not need. The trade-off is documented
in `SyncResolver` rather than hidden.

---

## 7. Notifications and alerts

Two constraints shape the scheduler:

**iOS allows 64 pending notifications per app.** Several pets on twice-daily medication hits that
fast. MyPet schedules a rolling **3-day horizon** with a 48-alert budget, re-armed every time the
app opens.

**Alert fatigue is a real safety failure.** A carer who mutes MyPet because it nags then receives
*no* medication reminders — strictly worse than a quieter app. So:

- Only `Concern` and above produce a behaviour notification.
- Each flag notifies at most once, unless it worsens.
- Dismissing a flag as "Expected" stops it re-alerting while the pattern persists.
- The permission prompt is **not** shown at launch. It appears in Settings, or when a carer first
  enables a reminder — when there is a visible reason for it.

Rescheduling rebuilds all pending task alerts rather than diffing them. A schedule edit invalidates
an unknown subset of pending requests, and a stale medication reminder is a genuine safety problem;
cancelling and re-deriving is cheap and cannot leave a ghost behind.

---

## 8. The seeded demo household

First launch seeds two pets, **one dog and one cat** (MyPet is cats and dogs only), with **ten weeks of plausible daily history**, generated from a
deterministic PRNG (SplitMix64, fixed seed) so it is **identical on every machine** — a demo that
looks different each launch is impossible to discuss with a supervisor.

| Pet | Species | The story it tells |
| --- | --- | --- |
| **Biscuit** | Golden Retriever, 5y | Four-day decline: appetite and energy down. Trips lethargy, appetite and multi-system. |
| **Mochi** | British Shorthair, 2y8m | Day-to-day normal, but gaining ~0.5%/week. Only the **weight-trend** rule catches this. Also has an **overdue** FVRCP booster. |

The generator deliberately **skips roughly one day in nine**, so the model's gap handling is
exercised rather than being handed perfect data it will never see in the field.

There is a test (`demoProducesAFlag`) asserting the seeded household actually trips the detector —
if that ever breaks, the app opens on an empty dashboard with nothing to show a marker.

**Settings → Data** has *Reload demo household* and *Delete all data*, both behind confirmations.

---

## 9. Tests

```bash
xcodebuild -project MyPet.xcodeproj -scheme MyPet \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

**54 tests, 12 suites** (Swift Testing, not XCTest):

| Suite | Covers |
| --- | --- |
| Robust statistics | Median, MAD outlier resistance vs σ, EWMA recency, OLS slope |
| Baseline model | Establishment thresholds, evaluation-window exclusion, noise floor |
| Anomaly detector | Healthy pet stays quiet · appetite loss caught · lethargy caught · single bad day never escalates · directionality · no baseline → no flags · weight trend · sensitivity · explainability |
| Flag merge rules | Dismissed stays dismissed · acknowledged re-activates only on escalation · stale flags resolve not delete · identity stable |
| Care task recurrence | Daily/interval/end-date expansion · inactive silent · completion by due date · grace periods |
| Distributed sync | Lamport ordering · deterministic tiebreak convergence · offline queue drains · failure ≠ data loss · peer edit decodes |
| Persistence | Round-trip, empty load |
| Seeded demo household | Determinism · trips the detector · referential integrity |
| Domain model | Appetite clamping · day normalisation · revisions · severity ordering · directionality |

Every test injects `asOf` rather than using `Date.now`, so results never depend on when the suite
runs.

> One of these caught a real bug during development: the multi-system escalation path bypassed the
> persistence gate every other flag obeys, so a single genuinely bad day could produce a *Concern*.
> Fixed in `evaluateMultiSystem`.

---

## 10. Mapping to the FIT3161 deliverables

The topic 22 brief, line by line:

| Required | Where it lives |
| --- | --- |
| "Full-stack pet monitoring platform" | Complete app: models, services, persistence, sync, UI |
| "Modular service architecture" | Five independent actors behind one coordinator (§4) |
| "Real-time data synchronisation" | `EventBus` + `SyncService`; UI updates from events, not polling |
| "Asynchronous background processing" | `BehaviorAnalysisService` — debounced, off main actor, concurrent across pets |
| "Live, interactive dashboard" | `DashboardView` — flags, overdue, up-next, per-pet status, sparklines |
| "Comprehensive pet information management" | `PetDetailView` + `HealthRecord` (7 record types, due tracking) |
| "Dynamic task scheduling" | `CareTask` recurrence rules → on-demand occurrence expansion |
| "Quick-entry behaviour logging" | `QuickLogView` — pre-filled from the pet's own recent pattern |
| "AI-backed behaviour monitoring in the background" | `AnomalyDetector` via `BehaviorAnalysisService` |
| "Evaluate daily logs against individual pet baselines" | `BaselineModel` — strictly per-subject (§5) |
| "Loss of appetite, altered sleep, elevated lethargy" | Exactly three of the seven syndromes, by name |
| "Automatically flags issues directly on the dashboard" | `FlagCard`, sorted worst-first, with evidence |
| "Automated real-time alerts for feeding and medication" | `NotificationService`, rolling horizon |
| "Cross-platform (web and mobile)" | ⚠️ **iOS only.** See §11 — this is the one gap. |

### Honest note for your report

Two claims in the brief are **partially** met, and it is better to say so in the pitch than be
asked about it in Q&A:

1. **"Cross-platform across web and mobile."** This is iOS only. The domain and service layers are
   pure Swift with no UIKit dependency, so they port to a Swift package shared with a macOS or
   visionOS target — but web would mean reimplementing the model.
2. **"Distributed."** The sync *protocol* is real and tested; the *server* is an in-memory
   simulation. §6 says exactly which is which.

The GenAI acknowledgement you will need for the pitch: this codebase was written with Claude (AI)
on 2026-08-17. Per the unit's policy, you must be able to explain and justify any of it in Q&A —
§4 and §5 exist to make that possible, and every non-obvious decision is commented at its site.

---

## 11. Known limits and where it goes next

**Limits, stated plainly:**

- iOS only.
- The sync backend is in-memory: data does not survive between two *real* devices.
- No photos on pet profiles.
- No multi-user accounts — carers are display names, not authenticated identities.
- The detector is statistical, not learned from a training corpus. It cannot diagnose.
- No background refresh: analysis runs on foreground, not while the app is suspended.

**Sequenced next steps, cheapest first:**

1. `BGTaskScheduler` for genuine background analysis while suspended.
2. Photos on pet profiles (`PhotosPicker`, files on disk, paths in the snapshot).
3. Extract `Models/`, `ML/`, `Services/` into a Swift package — one line of work, and it makes the
   model reusable across targets.
4. A real backend behind `SyncBackend` (Supabase is the least work: Postgres + row-level security
   maps cleanly onto the per-household isolation this already assumes).
5. Accounts and per-carer permissions.
6. A Core ML model trained on aggregated anonymised data, swapped in behind the same interface.
7. HealthKit-style integrations with smart feeders and activity collars, to replace manual logging
   with measurement.

---

## 12. Troubleshooting

**"No such module 'Charts'"** — Swift Charts needs iOS 16+. Check the deployment target is 18.0
(project → Info).

**Tests won't run / no scheme** — the shared scheme is committed at
`MyPet.xcodeproj/xcshareddata/xcschemes/MyPet.xcscheme`. If Xcode does not see it:
Product → Scheme → Manage Schemes → tick **Shared** next to MyPet.

**Dashboard is empty on launch** — the seed only runs on a genuine first launch. Settings → Data →
**Reload demo household**.

**No notifications arriving** — the prompt is deliberately not shown at launch. Settings → Alerts →
**Request permission**. On a simulator, alerts appear only if the Simulator window is not
foregrounded.

**Flags won't appear after editing logs** — the model needs ≥7 logged days per metric before it
will judge anything. Insights → the progress bar shows how much baseline is established. To skip
the wait: pet → ⋯ → **Simulate a decline**.

**"Sync failed"** — check Settings → Sync → **Simulate backend failure** is off.

**Clean build** — ⇧⌘K, then delete DerivedData:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/MyPet-*
```

---

## Disclaimer

MyPet flags **changes in routine** against a pet's own baseline. It is a monitoring aid, not a
diagnostic tool, and it cannot tell you what a change means. If you are worried about an animal,
call a vet — do not wait for an app to escalate.

---

*Built for FIT3161 Computer Science Project 1 (S2 2026), Monash University Malaysia — topic 22,
"MyPet: A Distributed Pet Monitoring System". Written with Claude (AI), 2026-08-17.*
