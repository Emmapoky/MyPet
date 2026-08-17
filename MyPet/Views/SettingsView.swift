import SwiftUI

/// Settings, and the window onto the distributed layer.
///
/// The sync, event-bus and notification sections are deliberately visible
/// rather than hidden behind a debug flag: for a project whose brief is a
/// *distributed* system with *asynchronous background processing*, being able
/// to point at the outbox draining and the event feed filling is the difference
/// between claiming an architecture and demonstrating one.
struct SettingsView: View {

    @Environment(MyPetStore.self) private var store

    @State private var pendingAlerts: [String] = []
    @State private var showResetConfirmation = false
    @State private var showReseedConfirmation = false
    @State private var isOffline = false
    @State private var backendFailing = false

    var body: some View {
        NavigationStack {
            Form {
                detectionSection
                syncSection
                activitySection
                notificationsSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .task { await refreshAlerts() }
        }
    }

    // MARK: Detection

    private var detectionSection: some View {
        @Bindable var store = store

        return Section {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Sensitivity", value: sensitivityLabel)
                Slider(value: $store.config.sensitivity, in: 0.6...1.6, step: 0.1)
                Text("Higher catches smaller changes and raises more false alarms. Lower only reacts to clear shifts.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Stepper(value: $store.config.evaluationWindowDays, in: 2...7) {
                LabeledContent("Days evaluated", value: "\(store.config.evaluationWindowDays)")
            }

            Stepper(value: $store.config.baselineWindowDays, in: 14...90, step: 7) {
                LabeledContent("Baseline window", value: "\(store.config.baselineWindowDays) days")
            }

            if store.isAnalyzing {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Re-analysing…").font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Behaviour detection")
        } footer: {
            Text("Changing any of these re-runs the model across every pet immediately.")
        }
    }

    private var sensitivityLabel: String {
        switch store.config.sensitivity {
        case ..<0.85: "Relaxed"
        case 0.85..<1.15: "Balanced"
        case 1.15..<1.4: "Alert"
        default: "Very alert"
        }
    }

    // MARK: Sync

    private var syncSection: some View {
        Section {
            if let status = store.syncStatus {
                LabeledContent("Status") {
                    Label(status.state.displayName, systemImage: status.state.symbolName)
                        .font(.subheadline)
                        .foregroundStyle(status.pending > 0 ? Theme.watch : .secondary)
                }

                LabeledContent("Queued changes", value: "\(status.pending)")

                if let last = status.lastSyncedAt {
                    LabeledContent("Last synced", value: last.formatted(date: .omitted, time: .shortened))
                }

                LabeledContent("This device", value: String(status.nodeID.suffix(8)))
                LabeledContent("Lamport clock", value: "\(status.lamport)")

                if !status.conflicts.isEmpty {
                    DisclosureGroup("Conflicts resolved (\(status.conflicts.count))") {
                        ForEach(status.conflicts, id: \.self) { conflict in
                            Text(conflict)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button {
                Task { await store.syncNow() }
            } label: {
                Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(store.isSyncing)

            Toggle("Offline mode", isOn: $isOffline)
                .onChange(of: isOffline) { _, value in
                    Task { await store.setOfflineMode(value) }
                }

            Toggle("Simulate backend failure", isOn: $backendFailing)
                .onChange(of: backendFailing) { _, value in
                    Task { await store.setBackendFailing(value) }
                }
        } header: {
            Text("Sync")
        } footer: {
            Text("Turn on offline mode, make some edits, then turn it off and press Sync — the queued changes drain in order. Conflicts resolve last-writer-wins, ordered by Lamport clock rather than device time.")
        }
    }

    // MARK: Activity feed

    private var activitySection: some View {
        Section {
            if store.eventFeed.isEmpty {
                Text("No activity yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.eventFeed.prefix(12)) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.event.symbolName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        Text(entry.event.label)
                            .font(.caption)

                        Spacer()

                        Text(entry.at.formatted(date: .omitted, time: .standard))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            Text("Event stream")
        } footer: {
            Text("Every domain event flowing through the app's internal bus. Writing a log publishes an event; the analysis service picks it up and re-scores that pet on a background executor.")
        }
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        Section {
            LabeledContent("Permission") {
                Label(
                    store.notificationsAuthorized ? "Granted" : "Not granted",
                    systemImage: store.notificationsAuthorized ? "checkmark.circle.fill" : "xmark.circle"
                )
                .font(.subheadline)
                .foregroundStyle(store.notificationsAuthorized ? Theme.positive : .secondary)
            }

            if !store.notificationsAuthorized {
                Button {
                    Task {
                        await store.requestNotificationAuthorization()
                        await refreshAlerts()
                    }
                } label: {
                    Label("Request permission", systemImage: "bell.badge")
                }
            }

            if pendingAlerts.isEmpty {
                Text("No alerts scheduled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                DisclosureGroup("Scheduled alerts (\(pendingAlerts.count))") {
                    ForEach(pendingAlerts, id: \.self) { summary in
                        Text(summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                Task { await refreshAlerts() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Alerts")
        } footer: {
            Text("iOS caps an app at 64 pending notifications, so MyPet schedules a rolling three-day horizon and re-arms it whenever you open the app.")
        }
    }

    // MARK: Data

    private var dataSection: some View {
        Section {
            LabeledContent("Pets", value: "\(store.pets.count)")
            LabeledContent("Behaviour logs", value: "\(store.logs.count)")
            LabeledContent("Care tasks", value: "\(store.tasks.count)")
            LabeledContent("Health records", value: "\(store.healthRecords.count)")
            LabeledContent("Flags", value: "\(store.flags.count)")

            if !store.storageDescription.isEmpty {
                DisclosureGroup("Storage location") {
                    Text(store.storageDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Button {
                showReseedConfirmation = true
            } label: {
                Label("Reload demo household", systemImage: "arrow.counterclockwise")
            }

            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("Delete all data", systemImage: "trash")
            }
        } header: {
            Text("Data")
        }
        .confirmationDialog(
            "Reload the demo household?",
            isPresented: $showReseedConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace everything with demo data", role: .destructive) {
                Task { await store.reseedDemoData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces every pet, log, task and record you currently have with the seeded demo household.")
        }
        .confirmationDialog(
            "Delete all data?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) {
                Task { await store.resetEverything() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every pet, behaviour log, care task and health record is removed from this device. This cannot be undone.")
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: "1.0")
            LabeledContent("Data stays", value: "On this device")

            VStack(alignment: .leading, spacing: 6) {
                Text("MyPet flags changes in your pet's routine against their own baseline. It is a monitoring aid, not a diagnostic tool, and it cannot tell you what a change means.")
                Text("If you are worried about your animal, call your vet. Do not wait for the app to escalate.")
                    .fontWeight(.medium)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
            Text("About")
        } footer: {
            Text("Built for FIT3161 Computer Science Project 1 — topic 22, MyPet: A Distributed Pet Monitoring System.")
        }
    }

    private func refreshAlerts() async {
        pendingAlerts = await store.pendingNotificationSummaries()
    }
}
