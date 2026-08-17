import SwiftUI

/// Add or edit a pet. Also the only route to deleting one.
struct PetEditView: View {

    @Environment(MyPetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: Pet?
    @State private var draft: Pet
    @State private var hasBirthDate: Bool
    @State private var birthDate: Date
    @State private var hasTargetWeight: Bool
    @State private var targetWeight: Double
    @State private var showDeleteConfirmation = false

    init(pet: Pet?) {
        self.existing = pet
        let seed = pet ?? Pet(name: "", species: .dog, accentIndex: Int.random(in: 0..<Theme.petAccents.count))
        _draft = State(initialValue: seed)
        _hasBirthDate = State(initialValue: pet?.birthDate != nil)
        _birthDate = State(initialValue: pet?.birthDate ?? Calendar.current.date(byAdding: .year, value: -2, to: .now) ?? .now)
        _hasTargetWeight = State(initialValue: pet?.targetWeightKg != nil)
        _targetWeight = State(initialValue: pet?.targetWeightKg ?? pet?.weightKg ?? 5)
    }

    private var isValid: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                appearanceSection
                bodySection
                careSection
                if existing != nil { deleteSection }
            }
            .navigationTitle(existing == nil ? "New pet" : "Edit \(existing?.name ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .confirmationDialog(
                "Delete \(draft.name)?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(draft.name) and all their data", role: .destructive) {
                    if let existing { store.delete(pet: existing) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes every behaviour log, care task and health record for \(draft.name). It cannot be undone.")
            }
        }
    }

    // MARK: Sections

    private var identitySection: some View {
        Section {
            TextField("Name", text: $draft.name)

            Picker("Species", selection: $draft.species) {
                ForEach(Species.allCases) { species in
                    Label(species.displayName, systemImage: species.symbolName).tag(species)
                }
            }
            .onChange(of: draft.species) { _, newValue in
                draft.symbolName = newValue.symbolName
            }

            TextField("Breed", text: $draft.breed)

            Picker("Sex", selection: $draft.sex) {
                ForEach(Sex.allCases) { sex in Text(sex.displayName).tag(sex) }
            }

            Toggle("Neutered / spayed", isOn: $draft.isNeutered)

            Toggle("Birth date known", isOn: $hasBirthDate)
            if hasBirthDate {
                DatePicker("Born", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
            }
        } header: {
            Text("About")
        }
    }

    private var appearanceSection: some View {
        Section {
            HStack(spacing: 10) {
                ForEach(Theme.petAccents.indices, id: \.self) { index in
                    Button {
                        draft.accentIndex = index
                    } label: {
                        Circle()
                            .fill(Theme.petAccents[index])
                            .frame(width: 30, height: 30)
                            .overlay {
                                if draft.accentIndex == index {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(minWidth: Theme.minimumTapTarget, minHeight: Theme.minimumTapTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Colour \(index + 1)")
                }
            }
            .frame(maxWidth: .infinity)
        } header: {
            Text("Colour")
        } footer: {
            Text("Each pet gets its own colour so a household with several animals stays scannable at a glance.")
        }
    }

    private var bodySection: some View {
        Section {
            LabeledContent("Current weight") {
                HStack(spacing: 6) {
                    TextField("kg", value: $draft.weightKg, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                    Text("kg").foregroundStyle(.secondary)
                }
            }

            Toggle("Set a target weight", isOn: $hasTargetWeight)
            if hasTargetWeight {
                LabeledContent("Target") {
                    HStack(spacing: 6) {
                        TextField("kg", value: $targetWeight, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 80)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Body")
        }
    }

    private var careSection: some View {
        Section {
            TextField("Vet clinic", text: $draft.vetClinic)
            TextField("Vet phone", text: $draft.vetPhone)
                .keyboardType(.phonePad)
            TextField("Microchip ID", text: $draft.microchipID)
            TextField("Allergies", text: $draft.allergies, axis: .vertical)
                .lineLimit(1...3)
            TextField("Notes", text: $draft.notes, axis: .vertical)
                .lineLimit(1...5)
        } header: {
            Text("Care details")
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete pet", systemImage: "trash")
            }
        }
    }

    // MARK: Save

    private func save() {
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        draft.birthDate = hasBirthDate ? birthDate : nil
        draft.targetWeightKg = hasTargetWeight ? targetWeight : nil
        store.upsert(pet: draft)
        dismiss()
    }
}
