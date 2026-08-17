import SwiftUI

struct TaskEditView: View {

    @Environment(MyPetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: CareTask?

    @State private var draft: CareTask
    @State private var recurrenceKind: RecurrenceKind
    @State private var intervalDays: Int
    @State private var weekdays: Set<Int>
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var showDeleteConfirmation = false

    enum RecurrenceKind: String, CaseIterable, Identifiable {
        case daily = "Every day"
        case interval = "Every N days"
        case weekdays = "Certain days"
        case once = "Once"

        var id: String { rawValue }
    }

    init(task: CareTask?) {
        self.existing = task
        let seed = task ?? CareTask(petID: UUID(), title: "")
        _draft = State(initialValue: seed)

        switch seed.recurrence {
        case .daily:
            _recurrenceKind = State(initialValue: .daily)
            _intervalDays = State(initialValue: 2)
            _weekdays = State(initialValue: [2, 3, 4, 5, 6])
        case .everyNDays(let n):
            _recurrenceKind = State(initialValue: .interval)
            _intervalDays = State(initialValue: n)
            _weekdays = State(initialValue: [2, 3, 4, 5, 6])
        case .weekdays(let days):
            _recurrenceKind = State(initialValue: .weekdays)
            _intervalDays = State(initialValue: 2)
            _weekdays = State(initialValue: days)
        case .once:
            _recurrenceKind = State(initialValue: .once)
            _intervalDays = State(initialValue: 2)
            _weekdays = State(initialValue: [2, 3, 4, 5, 6])
        }

        _hasEndDate = State(initialValue: task?.endDate != nil)
        _endDate = State(initialValue: task?.endDate
            ?? Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now)
    }

    private var isValid: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
            && store.pets.contains { $0.id == draft.petID }
            && !draft.times.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                basicsSection
                timesSection
                recurrenceSection
                remindersSection
                if existing != nil { deleteSection }
            }
            .navigationTitle(existing == nil ? "New task" : "Edit task")
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
            .task {
                // A new task has no pet yet; default to the first one so the
                // form is immediately valid rather than starting in an error state.
                if existing == nil, let first = store.pets.first {
                    draft.petID = first.id
                }
            }
            .confirmationDialog(
                "Delete this task?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let existing { store.delete(task: existing) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its reminders will be cancelled. Completion history for this task is removed too.")
            }
        }
    }

    // MARK: Sections

    private var basicsSection: some View {
        Section {
            Picker("Pet", selection: $draft.petID) {
                ForEach(store.pets) { pet in
                    Text(pet.name).tag(pet.id)
                }
            }

            Picker("Type", selection: $draft.category) {
                ForEach(TaskCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.symbolName).tag(category)
                }
            }

            TextField("Title", text: $draft.title)

            TextField("Detail (dose, portion, distance…)", text: $draft.detail, axis: .vertical)
                .lineLimit(1...3)

            Toggle("Active", isOn: $draft.isActive)
        }
    }

    private var timesSection: some View {
        Section {
            ForEach(Array(draft.times.enumerated()), id: \.offset) { index, time in
                DatePicker(
                    "Time \(index + 1)",
                    selection: Binding(
                        get: { time.asDate() },
                        set: { draft.times[index] = TimeOfDay(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .swipeActions {
                    if draft.times.count > 1 {
                        Button(role: .destructive) {
                            draft.times.remove(at: index)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }

            Button {
                let next = draft.times.sorted().last.map {
                    TimeOfDay(hour: min($0.hour + 6, 23), minute: $0.minute)
                } ?? TimeOfDay(hour: 8, minute: 0)
                draft.times.append(next)
            } label: {
                Label("Add another time", systemImage: "plus.circle")
            }
        } header: {
            Text("Times of day")
        } footer: {
            Text("Twice-daily medication means two times here, not two separate tasks.")
        }
    }

    private var recurrenceSection: some View {
        Section {
            Picker("Repeats", selection: $recurrenceKind) {
                ForEach(RecurrenceKind.allCases) { Text($0.rawValue).tag($0) }
            }

            switch recurrenceKind {
            case .interval:
                Stepper(value: $intervalDays, in: 2...30) {
                    LabeledContent("Every", value: "\(intervalDays) days")
                }
            case .weekdays:
                weekdayPicker
            case .daily, .once:
                EmptyView()
            }

            DatePicker("Starts", selection: $draft.startDate, displayedComponents: .date)

            Toggle("Has an end date", isOn: $hasEndDate)
            if hasEndDate {
                DatePicker("Ends", selection: $endDate, in: draft.startDate..., displayedComponents: .date)
            }
        } header: {
            Text("Repeat")
        } footer: {
            Text("A course of antibiotics wants an end date. A daily feed does not.")
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                Button {
                    if weekdays.contains(weekday) {
                        if weekdays.count > 1 { weekdays.remove(weekday) }
                    } else {
                        weekdays.insert(weekday)
                    }
                } label: {
                    Text(Recurrence.shortWeekdayName(weekday).prefix(1))
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            weekdays.contains(weekday) ? Theme.petAccents[0] : Color.secondary.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .foregroundStyle(weekdays.contains(weekday) ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Recurrence.shortWeekdayName(weekday))
                .accessibilityAddTraits(weekdays.contains(weekday) ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private var remindersSection: some View {
        Section {
            Toggle("Send a reminder", isOn: $draft.remindersEnabled)

            if !store.notificationsAuthorized && draft.remindersEnabled {
                Button {
                    Task { await store.requestNotificationAuthorization() }
                } label: {
                    Label("Allow notifications", systemImage: "bell.badge")
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text(store.notificationsAuthorized
                 ? "MyPet schedules the next three days of alerts and re-arms them each time you open the app."
                 : "Notifications are not enabled yet, so reminders will not appear.")
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete task", systemImage: "trash")
            }
        }
    }

    // MARK: Save

    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespaces)
        draft.times = Array(Set(draft.times)).sorted()
        draft.endDate = hasEndDate ? endDate : nil

        switch recurrenceKind {
        case .daily: draft.recurrence = .daily
        case .interval: draft.recurrence = .everyNDays(intervalDays)
        case .weekdays: draft.recurrence = .weekdays(weekdays)
        case .once: draft.recurrence = .once
        }

        store.upsert(task: draft)
        dismiss()
    }
}
