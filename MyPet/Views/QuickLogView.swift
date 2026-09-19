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
                wellbeingSection
                bodySection
                notesSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.pageGradient.ignoresSafeArea())
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

    /// "Have you fed them today?" — Dr Yam's framing. One tap on how much they
    /// ate instead of typing grams or dragging a slider.
    private var appetiteSection: some View {
        Section {
            Stepper(value: $log.mealsOffered, in: 1...6) {
                LabeledContent("Meals given today", value: "\(log.mealsOffered)")
            }
            .onChange(of: log.mealsOffered) { _, offered in
                log.mealsEaten = min(log.mealsEaten, Double(offered))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("How much did \(pet.name) eat?")
                    .font(.subheadline)

                HStack(spacing: 6) {
                    ForEach(EatenAmount.allCases) { amount in
                        let isSelected = abs(log.appetiteRatio - amount.fraction) < 0.13
                        Button {
                            log.mealsEaten = Double(log.mealsOffered) * amount.fraction
                        } label: {
                            VStack(spacing: 3) {
                                Text(amount.emoji).font(.title3)
                                Text(amount.label).font(.caption2.weight(.medium))
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? amount.tint.opacity(0.25) : Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(isSelected ? amount.tint : .clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ate \(amount.label)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Label("Fed today?", systemImage: "fork.knife")
        } footer: {
            Text("Eating less is the earliest signal MyPet watches for. A rough guess is fine.")
        }
    }

    private enum EatenAmount: CaseIterable, Identifiable {
        case none, little, half, most, all
        var id: Self { self }
        var fraction: Double {
            switch self {
            case .none: 0
            case .little: 0.25
            case .half: 0.5
            case .most: 0.75
            case .all: 1
            }
        }
        var label: String {
            switch self {
            case .none: "None"
            case .little: "A little"
            case .half: "Half"
            case .most: "Most"
            case .all: "All"
            }
        }
        var emoji: String {
            switch self {
            case .none: "🚫"
            case .little: "🥄"
            case .half: "🌓"
            case .most: "🍽️"
            case .all: "✅"
            }
        }
        var tint: Color {
            switch self {
            case .none, .little: Theme.concern
            case .half: Theme.watch
            case .most, .all: Theme.positive
            }
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Mood").font(.subheadline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(Mood.allCases) { mood in
                        let isSelected = log.mood == mood
                        Button {
                            log.mood = mood
                        } label: {
                            Text("\(mood.emoji) \(mood.displayName)")
                                .font(.caption.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(
                                    Capsule().fill(isSelected ? pet.accent.opacity(0.22) : Color.secondary.opacity(0.08))
                                )
                                .overlay(Capsule().strokeBorder(isSelected ? pet.accent : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .padding(.vertical, 4)

            Picker("Toileting normal?", selection: $log.eliminationNormal) {
                Text("👍 Yes").tag(true)
                Text("⚠️ No").tag(false)
            }
            .pickerStyle(.segmented)
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
