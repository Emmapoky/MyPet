import SwiftUI

/// Quick-entry behaviour logging.
///
/// This is the highest-frequency screen in the app and the one the whole model
/// depends on — an anomaly detector with no data detects nothing. So it is
/// built to be finished in under twenty seconds: every field arrives pre-filled
/// from the pet's recent pattern, so a normal day is *confirmed* rather than
/// typed, and only the things that actually differ need touching.
struct QuickLogView: View {

    @Environment(MyPetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let pet: Pet

    @State private var log: BehaviorLog
    @State private var day: Date
    @State private var recordWeight = false
    @State private var hasLoaded = false

    init(pet: Pet) {
        self.pet = pet
        // Placeholder; replaced in `.task` once the store is reachable, because
        // the sensible defaults depend on the pet's own recent history.
        _log = State(initialValue: BehaviorLog(petID: pet.id, day: .now))
        _day = State(initialValue: Calendar.current.startOfDay(for: .now))
    }

    var body: some View {
        NavigationStack {
            Form {
                daySection
                appetiteSection
                restSection
                wellbeingSection
                bodySection
                notesSection
            }
            .navigationTitle("Log \(pet.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.record(log: log)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                guard !hasLoaded else { return }
                log = store.draftLog(for: pet, on: day)
                recordWeight = log.weightKg != nil
                hasLoaded = true
            }
            .onChange(of: day) { _, newDay in
                log = store.draftLog(for: pet, on: newDay)
                recordWeight = log.weightKg != nil
            }
        }
    }

    // MARK: Day

    private var daySection: some View {
        Section {
            DatePicker(
                "Day",
                selection: $day,
                in: ...Date.now,
                displayedComponents: .date
            )

            if store.log(for: pet.id, on: day) != nil {
                Label("Updating the existing log for this day", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Appetite

    private var appetiteSection: some View {
        Section {
            Stepper(value: $log.mealsOffered, in: 1...6) {
                LabeledContent("Meals offered", value: "\(log.mealsOffered)")
            }

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Meals eaten") {
                    Text(String(format: "%.1f", log.mealsEaten))
                        .monospacedDigit()
                }

                Slider(
                    value: $log.mealsEaten,
                    in: 0...Double(log.mealsOffered),
                    step: 0.25
                )
                .tint(pet.accent)

                HStack {
                    Text("Nothing")
                    Spacer()
                    Text("\(Int((log.appetiteRatio * 100).rounded()))% of what was offered")
                        .foregroundStyle(appetiteColor)
                    Spacer()
                    Text("All")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            LabeledContent("Water") {
                HStack(spacing: 6) {
                    TextField(
                        "ml",
                        value: Binding(
                            get: { log.waterMl ?? 0 },
                            set: { log.waterMl = $0 > 0 ? $0 : nil }
                        ),
                        format: .number.precision(.fractionLength(0))
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                    Text("ml").foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Food and water", systemImage: "fork.knife")
        } footer: {
            Text("Eating less is the earliest and most reliable signal MyPet watches for. Even a rough estimate helps.")
        }
    }

    private var appetiteColor: Color {
        switch log.appetiteRatio {
        case 0.8...: Theme.positive
        case 0.5..<0.8: Theme.watch
        default: Theme.concern
        }
    }

    // MARK: Rest and movement

    private var restSection: some View {
        Section {
            LabeledContent("Sleep") {
                HStack(spacing: 6) {
                    TextField(
                        "hours",
                        value: Binding(
                            get: { log.sleepHours ?? 0 },
                            set: { log.sleepHours = $0 > 0 ? $0 : nil }
                        ),
                        format: .number.precision(.fractionLength(1))
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 70)
                    Text("h").foregroundStyle(.secondary)
                }
            }

            LabeledContent("Active time") {
                HStack(spacing: 6) {
                    TextField(
                        "minutes",
                        value: Binding(
                            get: { log.activityMinutes ?? 0 },
                            set: { log.activityMinutes = $0 > 0 ? $0 : nil }
                        ),
                        format: .number.precision(.fractionLength(0))
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 70)
                    Text("min").foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Rest and movement", systemImage: "moon.zzz.fill")
        }
    }

    // MARK: Wellbeing

    private var wellbeingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Energy", value: energyDescription)

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { level in
                        Button {
                            log.energyLevel = level
                        } label: {
                            Image(systemName: level <= log.energyLevel ? "bolt.fill" : "bolt")
                                .font(.title3)
                                .foregroundStyle(level <= log.energyLevel ? pet.accent : Color.secondary.opacity(0.4))
                                .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Energy level \(level) of 5")
                    }
                }
            }

            Picker("Mood", selection: $log.mood) {
                ForEach(Mood.allCases) { mood in
                    Text("\(mood.emoji)  \(mood.displayName)").tag(mood)
                }
            }

            Toggle("Toileting normal", isOn: $log.eliminationNormal)
                .tint(Theme.positive)
        } header: {
            Label("How they seem", systemImage: "heart.fill")
        }
    }

    private var energyDescription: String {
        switch log.energyLevel {
        case 1: "Flat"
        case 2: "Subdued"
        case 3: "Normal"
        case 4: "Lively"
        default: "Bouncing"
        }
    }

    // MARK: Body

    private var bodySection: some View {
        Section {
            Toggle("Weighed today", isOn: $recordWeight)
                .tint(pet.accent)
                .onChange(of: recordWeight) { _, isOn in
                    log.weightKg = isOn ? (log.weightKg ?? pet.weightKg) : nil
                }

            if recordWeight {
                LabeledContent("Weight") {
                    HStack(spacing: 6) {
                        TextField(
                            "kg",
                            value: Binding(
                                get: { log.weightKg ?? pet.weightKg },
                                set: { log.weightKg = $0 }
                            ),
                            format: .number.precision(.fractionLength(2))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Label("Weight", systemImage: "scalemass.fill")
        } footer: {
            Text("Weekly is plenty. MyPet looks at the trend across weigh-ins, not any single number.")
        }
    }

    // MARK: Notes

    private var notesSection: some View {
        Section {
            TextField("Anything else worth remembering", text: $log.notes, axis: .vertical)
                .lineLimit(2...5)
        } header: {
            Label("Notes", systemImage: "note.text")
        } footer: {
            Text("Notes are for you and your vet. They are never fed into the behaviour model.")
        }
    }
}
