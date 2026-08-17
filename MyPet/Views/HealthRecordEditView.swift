import SwiftUI

struct HealthRecordEditView: View {

    @Environment(MyPetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let petID: UUID
    private let existing: HealthRecord?

    @State private var draft: HealthRecord
    @State private var hasNextDue: Bool
    @State private var nextDue: Date
    @State private var hasCost: Bool
    @State private var cost: Double
    @State private var hasWeight: Bool
    @State private var weight: Double
    @State private var showDeleteConfirmation = false

    init(petID: UUID, record: HealthRecord?) {
        self.petID = petID
        self.existing = record

        let seed = record ?? HealthRecord(petID: petID, kind: .vetVisit, title: "", date: .now)
        _draft = State(initialValue: seed)
        _hasNextDue = State(initialValue: record?.nextDueDate != nil)
        _nextDue = State(initialValue: record?.nextDueDate
            ?? Calendar.current.date(byAdding: .day, value: 365, to: .now) ?? .now)
        _hasCost = State(initialValue: record?.cost != nil)
        _cost = State(initialValue: record?.cost ?? 0)
        _hasWeight = State(initialValue: record?.weightKg != nil)
        _weight = State(initialValue: record?.weightKg ?? 0)
    }

    private var isValid: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $draft.kind) {
                        ForEach(HealthRecordKind.allCases) { kind in
                            Label(kind.displayName, systemImage: kind.symbolName).tag(kind)
                        }
                    }
                    .onChange(of: draft.kind) { _, newKind in
                        // Offer the conventional interval for this record type,
                        // so the carer confirms a date rather than computing one.
                        if let days = newKind.suggestedIntervalDays {
                            hasNextDue = true
                            nextDue = Calendar.current.date(byAdding: .day, value: days, to: draft.date) ?? nextDue
                        }
                        hasWeight = newKind == .weighIn
                    }

                    TextField("Title", text: $draft.title)
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                }

                Section {
                    Toggle("Due again later", isOn: $hasNextDue)
                    if hasNextDue {
                        DatePicker("Next due", selection: $nextDue, displayedComponents: .date)
                    }
                } footer: {
                    Text("Anything with a next-due date appears in the dashboard's health strip, and turns red once it lapses.")
                }

                Section {
                    TextField("Details", text: $draft.detail, axis: .vertical)
                        .lineLimit(2...6)
                    TextField("Vet clinic", text: $draft.vetClinic)
                }

                Section {
                    Toggle("Record weight", isOn: $hasWeight)
                    if hasWeight {
                        LabeledContent("Weight") {
                            HStack(spacing: 6) {
                                TextField("kg", value: $weight, format: .number.precision(.fractionLength(2)))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 80)
                                Text("kg").foregroundStyle(.secondary)
                            }
                        }
                    }

                    Toggle("Record cost", isOn: $hasCost)
                    if hasCost {
                        LabeledContent("Cost") {
                            TextField("0", value: $cost, format: .number.precision(.fractionLength(2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                        }
                    }
                }

                if existing != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete record", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New record" : "Edit record")
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
                "Delete this record?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let existing { store.delete(record: existing) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespaces)
        draft.nextDueDate = hasNextDue ? nextDue : nil
        draft.cost = hasCost ? cost : nil
        draft.weightKg = hasWeight ? weight : nil
        store.upsert(record: draft)
        dismiss()
    }
}
