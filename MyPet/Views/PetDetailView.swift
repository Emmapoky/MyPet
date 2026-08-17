import SwiftUI

/// Everything about one pet: status, flags, today's schedule, recent logs and
/// the full health record.
struct PetDetailView: View {

    @Environment(MyPetStore.self) private var store
    let petID: UUID

    @State private var isEditing = false
    @State private var isLogging = false
    @State private var editingRecord: HealthRecord?
    @State private var isAddingRecord = false
    @State private var section: Section = .overview

    enum Section: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case logs = "Logs"
        case health = "Health"

        var id: String { rawValue }
    }

    private var pet: Pet? { store.pet(id: petID) }

    var body: some View {
        Group {
            if let pet {
                content(for: pet)
            } else {
                EmptyStateView(
                    symbol: "questionmark.circle",
                    title: "Pet not found",
                    message: "This pet may have been removed on another device."
                )
            }
        }
        .background(Theme.background)
        .navigationTitle(pet?.name ?? "Pet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let pet {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { isLogging = true } label: { Label("Log today", systemImage: "square.and.pencil") }
                        Button { isEditing = true } label: { Label("Edit pet", systemImage: "pencil") }
                        Button { isAddingRecord = true } label: { Label("Add health record", systemImage: "cross.case") }
                        Divider()
                        Button {
                            Task { await store.injectAnomaly(for: pet) }
                        } label: {
                            Label("Simulate a decline (demo)", systemImage: "waveform.path.ecg")
                        }
                        Button {
                            Task { await store.simulatePeerEdit(on: pet) }
                        } label: {
                            Label("Simulate another carer's edit", systemImage: "iphone.gen3.radiowaves.left.and.right")
                        }
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $isEditing) { if let pet { PetEditView(pet: pet) } }
        .sheet(isPresented: $isLogging) { if let pet { QuickLogView(pet: pet) } }
        .sheet(isPresented: $isAddingRecord) { HealthRecordEditView(petID: petID, record: nil) }
        .sheet(item: $editingRecord) { record in HealthRecordEditView(petID: petID, record: record) }
    }

    // MARK: Content

    private func content(for pet: Pet) -> some View {
        ScrollView {
            VStack(spacing: Theme.sectionSpacing) {
                headerCard(for: pet)

                Picker("Section", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch section {
                case .overview: overviewSection(for: pet)
                case .logs: logsSection(for: pet)
                case .health: healthSection(for: pet)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: Header

    private func headerCard(for pet: Pet) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                PetAvatar(pet: pet, size: 62)

                VStack(alignment: .leading, spacing: 3) {
                    Text(pet.name).font(.title2.weight(.semibold))
                    Text("\(pet.species.displayName)\(pet.breed.isEmpty ? "" : " · \(pet.breed)")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(pet.ageDescription) · \(pet.sex.displayName)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            HStack(spacing: 0) {
                StatPill(
                    symbol: "scalemass.fill",
                    value: String(format: "%.2f", pet.weightKg),
                    caption: weightCaption(for: pet),
                    tint: weightTint(for: pet)
                )
                StatPill(
                    symbol: "calendar",
                    value: "\(store.loggingStreak(for: pet.id))/7",
                    caption: "days logged",
                    tint: pet.accent
                )
                StatPill(
                    symbol: "brain.head.profile",
                    value: "\(Int((store.baseline(for: pet).coverage * 100).rounded()))%",
                    caption: "baseline built",
                    tint: pet.accent
                )
            }

            if !pet.allergies.isEmpty {
                Label(pet.allergies, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.watch)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .petCard(accent: pet.accent)
    }

    private func weightCaption(for pet: Pet) -> String {
        guard let deviation = pet.weightDeviationFraction else { return "kg" }
        let percent = Int((abs(deviation) * 100).rounded())
        if percent < 3 { return "kg · on target" }
        return deviation > 0 ? "kg · \(percent)% over" : "kg · \(percent)% under"
    }

    private func weightTint(for pet: Pet) -> Color {
        guard let deviation = pet.weightDeviationFraction else { return .secondary }
        return abs(deviation) < 0.05 ? Theme.positive : Theme.watch
    }

    // MARK: Overview

    private func overviewSection(for pet: Pet) -> some View {
        VStack(spacing: Theme.sectionSpacing) {
            let flags = store.flags(for: pet.id)
            if !flags.isEmpty {
                VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                    SectionHeader("Behaviour flags")
                    ForEach(flags) { flag in
                        FlagCard(
                            flag: flag,
                            pet: pet,
                            showPetName: false,
                            onAcknowledge: flag.status == .active ? { store.acknowledge(flag: flag) } : nil,
                            onDismiss: flag.status != .dismissed ? { store.dismiss(flag: flag) } : nil
                        )
                    }
                }
            }

            let occurrences = store.occurrences(for: pet.id)
            if !occurrences.isEmpty {
                VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                    SectionHeader(
                        "Today's schedule",
                        subtitle: "\(occurrences.filter(\.isCompleted).count) of \(occurrences.count) done"
                    )
                    VStack(spacing: 0) {
                        ForEach(Array(occurrences.enumerated()), id: \.element.id) { index, occurrence in
                            OccurrenceRow(occurrence: occurrence, pet: pet, now: .now) {
                                store.toggleCompletion(of: occurrence)
                            }
                            if index < occurrences.count - 1 { Divider().padding(.leading, 44) }
                        }
                    }
                    .petCard(padding: 12)
                }
            }

            if !pet.notes.isEmpty || !pet.vetClinic.isEmpty {
                VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                    SectionHeader("Care details")
                    VStack(alignment: .leading, spacing: 8) {
                        if !pet.vetClinic.isEmpty {
                            LabeledContent("Vet", value: pet.vetClinic)
                        }
                        if !pet.vetPhone.isEmpty {
                            LabeledContent("Phone", value: pet.vetPhone)
                        }
                        if !pet.microchipID.isEmpty {
                            LabeledContent("Microchip", value: pet.microchipID)
                        }
                        if !pet.notes.isEmpty {
                            Text(pet.notes)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if pet.carers.count > 1 {
                            LabeledContent("Shared with", value: pet.carers.joined(separator: ", "))
                        }
                    }
                    .font(.subheadline)
                    .petCard()
                }
            }
        }
    }

    // MARK: Logs

    private func logsSection(for pet: Pet) -> some View {
        let entries = store.logs(for: pet.id).prefix(30)

        return VStack(alignment: .leading, spacing: Theme.stackSpacing) {
            SectionHeader("Recent logs", subtitle: "\(store.logs(for: pet.id).count) total")

            if entries.isEmpty {
                EmptyStateView(
                    symbol: "square.and.pencil",
                    title: "No logs yet",
                    message: "Log a day and MyPet starts learning \(pet.name)'s normal.",
                    actionTitle: "Log today",
                    action: { isLogging = true }
                )
                .petCard()
            } else {
                ForEach(Array(entries)) { entry in
                    LogRow(log: entry, pet: pet)
                }
            }
        }
    }

    // MARK: Health

    private func healthSection(for pet: Pet) -> some View {
        let records = store.records(for: pet.id)

        return VStack(alignment: .leading, spacing: Theme.stackSpacing) {
            SectionHeader(
                "Health record",
                subtitle: "\(records.count) entr\(records.count == 1 ? "y" : "ies")",
                trailing: AnyView(
                    Button {
                        isAddingRecord = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                )
            )

            if records.isEmpty {
                EmptyStateView(
                    symbol: "cross.case",
                    title: "No health records",
                    message: "Vaccinations, medication courses, vet visits and weigh-ins all live here.",
                    actionTitle: "Add a record",
                    action: { isAddingRecord = true }
                )
                .petCard()
            } else {
                ForEach(records) { record in
                    Button {
                        editingRecord = record
                    } label: {
                        HealthRecordRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - LogRow

struct LogRow: View {
    let log: BehaviorLog
    let pet: Pet

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(log.day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(log.mood.emoji)
                Text("logged by \(log.loggedBy)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 0) {
                StatPill(
                    symbol: "fork.knife",
                    value: "\(Int((log.appetiteRatio * 100).rounded()))%",
                    caption: "eaten",
                    tint: pet.accent
                )
                if let sleep = log.sleepHours {
                    StatPill(symbol: "moon.zzz.fill", value: String(format: "%.1f", sleep), caption: "hours", tint: pet.accent)
                }
                if let activity = log.activityMinutes {
                    StatPill(symbol: "figure.walk", value: "\(Int(activity))", caption: "min", tint: pet.accent)
                }
                StatPill(symbol: "bolt.fill", value: "\(log.energyLevel)", caption: "energy", tint: pet.accent)
                if let weight = log.weightKg {
                    StatPill(symbol: "scalemass.fill", value: String(format: "%.2f", weight), caption: "kg", tint: pet.accent)
                }
            }

            if !log.eliminationNormal {
                Label("Toileting outside normal", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(Theme.watch)
            }

            if !log.notes.isEmpty {
                Text(log.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .petCard(padding: 12)
    }
}

// MARK: - HealthRecordRow

struct HealthRecordRow: View {
    let record: HealthRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.kind.symbolName)
                .font(.subheadline)
                .foregroundStyle(record.isOverdue ? Theme.concern : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.title).font(.subheadline.weight(.medium))
                Text("\(record.kind.displayName) · \(record.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !record.detail.isEmpty {
                    Text(record.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let days = record.daysUntilDue() {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(days < 0 ? "\(-days)d" : "\(days)d")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(record.isOverdue ? Theme.concern : .secondary)
                    Text(days < 0 ? "overdue" : "until due")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .petCard(padding: 12)
    }
}
