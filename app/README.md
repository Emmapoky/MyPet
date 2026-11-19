# MyPet app (FIT3162)

The real MyPet app, built in Flutter from the submitted proposal report (FIT3161, 2 Nov 2026).
The SwiftUI app at the repo root is the earlier "imagination prototype" and is kept only for reference.

Built in the order of report Table 4.5.

| Stage | What | RTM | State |
|---|---|---|---|
| 1 Foundation | Data model (report Fig 4.3), backend interface, Firebase Spark backend, local backend, security rules with tests | NFR06, NFR08, FR-N04 | Done |
| 2 Profiles and log | Pet profiles (add, edit, archive, rehomed, passed away), quick log with "same as last entry" (2 taps on a routine day), health records, one timeline with edit and delete, offline queue and "waiting to sync" badge. Voice: keyboard dictation for now | FR01, FR02, FR03, FR05, FR06, FR19 (status part), NFR01 | Done, needs iPhone check |
| 3 Reminders | Recurring care with start, end and frequency; today's checklist; missed items; phone notifications with Log now and Later | FR10, FR11, FR12, FR21 | Done, needs iPhone check |
| 4 Baseline and flags | Detector in a background isolate, flags with evidence on Today and Insights, Insights hidden before 7 days, 7 or 30 day energy chart, normal against today | FR13 to FR16, NFR03, NFR07 | Done |
| 5 Behaviour check | Check tab: record 10 s or choose a video or audio file, CLAP on the phone, result with likelihoods and sounds heard, clip deleted. Rules from `ml/flutter/behaviour_bench` (did not hear the pet, cat non-meow sounds, not sure under 50%) | FR02, FR20, FR-N01, FR-N02, NFR03 | Done, needs iPhone check |

## Run it

```sh
cd app
flutter pub get
tool/get_behaviour_model.sh        # model files for the Check tab (not in git), see below
flutter test                       # 39 tests: detector, timeline, synthetic check, behaviour rules, screens
flutter run                        # keeps data on the phone (no Firebase needed)
flutter run --dart-define=BACKEND=firebase   # after docs/firebase-setup.md
```

The Check tab needs three files that are not in git: the CLAP model (downloaded) and
`classifiers.json` plus `sound_evidence.json`, built on the Mac by
`ml/flutter/behaviour_bench/tool/build_test_library.py --sound-evidence`.
`tool/get_behaviour_model.sh` copies them into `assets/`. Without them the tab says the check is not ready.

## Tests that match report Table 3.2

| Test | Checks |
|---|---|
| `test/app_flow_test.dart` NFR01 | A routine day is logged in 2 taps from opening the app (Log now, Save) |
| `test/app_flow_test.dart` NFR07 | Insights stay hidden with 6 logged days |
| `test/app_flow_test.dart` FR12 | A reminder not ticked by its time shows as missed |
| `test/synthetic_evaluation_test.dart` FR13, FR14 | 92% of planted changes flagged within 7 days; 0 flags before 7 days |
| `test/wording_test.dart` FR-N01, FR15 | No flag sentence names a condition; every flag shows its evidence |
| `test/timeline_test.dart` FR03, FR09, FR-N04 | Newest first; same conflict winner on every phone; nothing lost |
| `test/behaviour_test.dart` FR20, FR-N02 | Each result rule (feeling, did not hear, cat purring, not sure); a saved result holds no audio; record, result, save to timeline |
| `firebase/rules_test` NFR06, FR-N04 | 10 rules tests on the Firestore emulator |

The five-owner timing for NFR01 still has to happen in FIT3162 with real owners.

## Where things are

| Folder | What |
|---|---|
| `lib/models` | Pet, CareEntry (append-only timeline), Reminder, Timeline (edit and conflict rules) |
| `lib/data` | `Backend` interface (NFR08), `FirestoreBackend`, `LocalBackend`, start-up choice |
| `lib/behaviour` | Behaviour check: models and decision rules (pure Dart, tested) and the phone engine (record, file pick, ONNX) |
| `lib/detection` | Change detector (report 4.1) and the synthetic log maker |
| `lib/state` | `AppState` (what the screens show) and the demo pets |
| `lib/ui` | Screens; `theme.dart` holds the design tokens, `wording.dart` every sentence built from data |
| `lib/config/thresholds.dart` | Every detector number, with its reason (NFR09); see `docs/thresholds.md` |
| `firebase/` | `firestore.rules` and the emulator rules tests (NFR06-1 to 4, FRN04-1) |
| `test/` | Unit tests and the synthetic evaluation (`test/results/`) |

## Design decisions

- **Append-only timeline (FR-N04, FR09).** An edit writes a new entry that names the one it replaces; a
  delete writes a "voided" entry. If two carers edit the same entry at once, every phone picks the same
  winner (newest, then larger id) and keeps the other version recoverable. The rules block updates and deletes.
- **Offline queue (FR06).** Firestore's own cache on the phone is the queue: writes land locally at once and
  sync when back online. The app shows "waiting to sync" while writes are pending.
- **Two backends behind one interface (NFR08).** `LocalBackend` doubles as the offline demo mode and the test fake
  (stack plan, demo fallbacks).
- **Quick log fields.** Ate today (yes/no), energy (1 to 5), toileting normal (yes/no), optional weight and note,
  from report Table 3.1, Fig 4.5 screen 3 and the vault notes. Values are range-checked (report 4.4).
