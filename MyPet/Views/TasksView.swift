import SwiftUI

/// The care schedule: what is due, when, for whom.
struct TasksView: View {

    @Environment(MyPetStore.self) private var store

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var editingTask: CareTask?
    @State private var isAddingTask = false
    @State private var mode: Mode = .day
    @State private var now = Date.now

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    enum Mode: String, CaseIterable, Identifiable {
        case day = "By day"
        case rules = "All tasks"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                switch mode {
                case .day: dayView
                case .rules: rulesView
                }
            }
            .background(Theme.background)
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingTask = true
                    } label: {
                        Label("Add task", systemImage: "plus")
                    }
                    .disabled(store.pets.isEmpty)
                }
            }
            .sheet(isPresented: $isAddingTask) { TaskEditView(task: nil) }
            .sheet(item: $editingTask) { task in TaskEditView(task: task) }
            .onReceive(ticker) { now = $0 }
        }
    }

    // MARK: Day view

    private var dayView: some View {
        ScrollView {
            VStack(spacing: Theme.stackSpacing) {
                daySelector

                let occurrences = store.occurrences(on: selectedDay)

                if occurrences.isEmpty {
                    EmptyStateView(
                        symbol: "checklist",
                        title: "Nothing scheduled",
                        message: store.pets.isEmpty
                            ? "Add a pet first, then set up feeding and medication times."
                            : "No care tasks fall on this day.",
                        actionTitle: store.pets.isEmpty ? nil : "Add a task",
                        action: store.pets.isEmpty ? nil : { isAddingTask = true }
                    )
                    .petCard()
                } else {
                    progressCard(for: occurrences)

                    ForEach(groupedByPet(occurrences), id: \.pet.id) { group in
                        VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                            SectionHeader(
                                group.pet.name,
                                subtitle: "\(group.occurrences.filter(\.isCompleted).count) of \(group.occurrences.count) done"
                            )

                            VStack(spacing: 0) {
                                ForEach(Array(group.occurrences.enumerated()), id: \.element.id) { index, occurrence in
                                    OccurrenceRow(occurrence: occurrence, pet: group.pet, now: now) {
                                        store.toggleCompletion(of: occurrence)
                                    }
                                    .contextMenu {
                                        if let task = store.tasks.first(where: { $0.id == occurrence.taskID }) {
                                            Button {
                                                editingTask = task
                                            } label: {
                                                Label("Edit task", systemImage: "pencil")
                                            }
                                        }
                                    }
                                    if index < group.occurrences.count - 1 {
                                        Divider().padding(.leading, 44)
                                    }
                                }
                            }
                            .petCard(accent: group.pet.accent, padding: 12)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private var daySelector: some View {
        HStack {
            Button {
                shiftDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
            }
            .accessibilityLabel("Previous day")

            Spacer()

            VStack(spacing: 1) {
                Text(dayLabel).font(.headline)
                Text(selectedDay.formatted(date: .complete, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                shiftDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
            }
            .accessibilityLabel("Next day")
        }
        .petCard(padding: 8)
    }

    private var dayLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDay) { return "Today" }
        if calendar.isDateInTomorrow(selectedDay) { return "Tomorrow" }
        if calendar.isDateInYesterday(selectedDay) { return "Yesterday" }
        return selectedDay.formatted(.dateTime.weekday(.wide))
    }

    private func shiftDay(by days: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: selectedDay) else { return }
        selectedDay = next
    }

    private func progressCard(for occurrences: [TaskOccurrence]) -> some View {
        let done = occurrences.filter(\.isCompleted).count
        let fraction = occurrences.isEmpty ? 0 : Double(done) / Double(occurrences.count)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(done) of \(occurrences.count) done")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(fraction >= 1 ? Theme.positive : .secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(fraction >= 1 ? Theme.positive : Theme.petAccents[0])
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 7)
        }
        .petCard()
    }

    private func groupedByPet(_ occurrences: [TaskOccurrence]) -> [(pet: Pet, occurrences: [TaskOccurrence])] {
        let grouped = Dictionary(grouping: occurrences, by: \.petID)
        return store.pets.compactMap { pet in
            guard let items = grouped[pet.id], !items.isEmpty else { return nil }
            return (pet, items.sorted { $0.dueAt < $1.dueAt })
        }
    }

    // MARK: Rules view

    private var rulesView: some View {
        Group {
            if store.tasks.isEmpty {
                EmptyStateView(
                    symbol: "repeat",
                    title: "No care tasks",
                    message: "Set up recurring feeds, doses, walks and grooming here.",
                    actionTitle: store.pets.isEmpty ? nil : "Add a task",
                    action: store.pets.isEmpty ? nil : { isAddingTask = true }
                )
            } else {
                List {
                    ForEach(store.pets) { pet in
                        let petTasks = store.tasks(for: pet.id)
                        if !petTasks.isEmpty {
                            Section(pet.name) {
                                ForEach(petTasks) { task in
                                    Button {
                                        editingTask = task
                                    } label: {
                                        TaskRuleRow(task: task, pet: pet)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            store.delete(task: task)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - TaskRuleRow

struct TaskRuleRow: View {
    let task: CareTask
    let pet: Pet

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.category.symbolName)
                .font(.subheadline)
                .foregroundStyle(pet.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(task.title).font(.subheadline.weight(.medium))
                    if !task.isActive {
                        Text("Paused")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }

                Text("\(task.recurrence.displayName) · \(task.times.sorted().map(\.displayString).joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if !task.detail.isEmpty {
                    Text(task.detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if task.remindersEnabled && task.isActive {
                Image(systemName: "bell.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Reminders on")
            }
        }
        .padding(.vertical, 3)
    }
}
