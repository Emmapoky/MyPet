# MyPet app (FIT3162)

The real MyPet app, built in Flutter from the submitted proposal report (FIT3161, 2 Nov 2026).
The SwiftUI app at the repo root is the earlier "imagination prototype" and is kept only for reference.

Built in the order of report Table 4.5.

| Stage | What | RTM | State |
|---|---|---|---|
| 1 Foundation | Data model (report Fig 4.3), backend interface, Firebase Spark backend, local backend, security rules with tests | NFR06, NFR08, FR-N04 | Done |
| 2 Profiles and log | Pet profiles, 3-tap quick log with "same as last entry", voice note, timeline, offline queue | FR01, FR03, FR05, FR06, FR18, NFR01 | In progress |
| 3 Reminders | Recurring care, notifications, missed items, missed-day reminder | FR10 to FR12, FR21 | Not started |
| 4 Baseline and flags | Detector done and tested; Insights screen to do | FR13 to FR16, NFR07 | Detector done |
| 5 Behaviour check | Record and Result using `ml/flutter/behaviour_bench` | FR02, FR20, NFR03 | Not started |

## Run it

```sh
cd app
flutter pub get
flutter test                       # detector, timeline and synthetic check
flutter run                        # keeps data on the phone (no Firebase needed)
flutter run --dart-define=BACKEND=firebase   # after docs/firebase-setup.md
```

## Where things are

| Folder | What |
|---|---|
| `lib/models` | Pet, CareEntry (append-only timeline), Reminder, Timeline (edit and conflict rules) |
| `lib/data` | `Backend` interface (NFR08), `FirestoreBackend`, `LocalBackend`, start-up choice |
| `lib/detection` | Change detector (report 4.1) and the synthetic log maker |
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
