import SwiftUI

/// The live dashboard — the screen the whole app is arranged around.
///
/// Order is the design. Flags first (something may be wrong), then overdue
/// tasks (something was missed), then what is due next, then per-pet status.
/// A carer opening the app at 7am and a carer opening it because they are
/// worried both find what they need at the top.
struct DashboardView: View {

    @Environment(MyPetStore.self) private var store
    var onQuickLog: (Pet) -> Void
    var onQuickCapture: () -> Void = {}

    @State private var now = Date.now
    @State private var showSettings = false
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.sectionSpacing) {
                    if store.pets.isEmpty {
                        EmptyStateView(
                            symbol: "pawprint.circle",
                            title: "No pets yet",
                            message: "Add your first pet and MyPet will start learning what normal looks like for them.",
                            actionTitle: nil,
                            action: nil
                        )
                    } else {
                        heroHeader
                        quickCaptureCard
                        flagsSection
                        overdueSection
                        upcomingSection
                        petsSection
                        healthDueSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Theme.pageGradient.ignoresSafeArea())
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        BrandLogo(size: 30)
                        Text("MyPet").font(.headline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        syncIndicator
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .refreshable {
                await store.syncNow()
                await store.runAnalysis()
            }
            .onReceive(ticker) { now = $0 }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: Hero

    /// Greeting, today's progress, and the three promises in one glance.
    private var heroHeader: some View {
        let loggedToday = store.pets.filter { store.log(for: $0.id, on: now) != nil }.count
        let todays = store.occurrences(on: now)
        let done = todays.filter(\.isCompleted).count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.system(.title, design: .rounded).weight(.bold))
                    Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.subheadline)
                        .opacity(0.9)
                }
                Spacer()
                BrandLogo(size: 52)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }

            HStack(spacing: 10) {
                HeroStat(value: "\(loggedToday)/\(store.pets.count)", caption: "pets logged")
                HeroStat(value: todays.isEmpty ? "—" : "\(done)/\(todays.count)", caption: "tasks done")
                HeroStat(value: "\(store.activeFlags.filter { $0.severity >= .watch }.count)", caption: "to look at")
            }

            HStack(spacing: 6) {
                PromiseChip(text: "Free", symbol: "banknote")
                PromiseChip(text: "No collar", symbol: "sensor.tag.radiowaves.forward")
                PromiseChip(text: "~3 taps", symbol: "hand.tap")
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.brand.opacity(0.3), radius: 14, y: 8)
    }

    // MARK: Quick capture

    /// Entry point for Lingsha's one-sentence logging idea.
    private var quickCaptureCard: some View {
        Button(action: onQuickCapture) {
            HStack(spacing: 12) {
                Image(systemName: "text.bubble.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Theme.brandLavender, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick capture")
                        .font(.subheadline.weight(.semibold))
                    Text("“Biscuit ate half, a bit sleepy”. Say it in one line and MyPet fills in the log.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "mic.fill")
                    .foregroundStyle(Theme.brandLavender)
            }
            .petCard(accent: Theme.brandLavender)
        }
        .buttonStyle(.plain)
    }

    // MARK: Sync indicator

    private var syncIndicator: some View {
        HStack(spacing: 5) {
            if store.isSyncing || store.isAnalyzing {
                ProgressView().controlSize(.mini)
            } else if let status = store.syncStatus {
                Image(systemName: status.state.symbolName)
                    .font(.caption)
                    .foregroundStyle(status.pending > 0 ? Theme.watch : .secondary)
            }

            if let status = store.syncStatus, status.pending > 0 {
                Text("\(status.pending)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.watch)
            }
        }
        .accessibilityLabel(syncAccessibilityLabel)
    }

    private var syncAccessibilityLabel: String {
        if store.isAnalyzing { return "Analysing behaviour" }
        if store.isSyncing { return "Syncing" }
        guard let status = store.syncStatus else { return "Sync idle" }
        return status.pending > 0
            ? "\(status.state.displayName), \(status.pending) changes pending"
            : status.state.displayName
    }

    // MARK: Flags

    @ViewBuilder
    private var flagsSection: some View {
        let flags = store.activeFlags.filter { $0.severity >= .watch }

        if flags.isEmpty {
            allClearCard
        } else {
            VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                SectionHeader(
                    "Needs a look",
                    subtitle: "\(flags.count) pattern\(flags.count == 1 ? "" : "s") outside normal"
                )

                ForEach(flags) { flag in
                    if let pet = store.pet(id: flag.petID) {
                        FlagCard(
                            flag: flag,
                            pet: pet,
                            onAcknowledge: { store.acknowledge(flag: flag) },
                            onDismiss: { store.dismiss(flag: flag) }
                        )
                    }
                }
            }
        }
    }

    private var allClearCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(Theme.positive)

            VStack(alignment: .leading, spacing: 2) {
                Text("Everything looks normal")
                    .font(.subheadline.weight(.semibold))
                Text(allClearSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .petCard(accent: Theme.positive)
    }

    private var allClearSubtitle: String {
        let analysed = store.pets.filter { store.loggingStreak(for: $0.id, days: 14) >= 7 }.count
        if analysed == 0 {
            return "Keep logging daily — the model needs about a week per pet before it can judge."
        }
        return "\(analysed) of \(store.pets.count) pets have an established baseline. No routine shifts detected."
    }

    // MARK: Overdue

    @ViewBuilder
    private var overdueSection: some View {
        let overdue = store.overdueOccurrences(now: now)

        if !overdue.isEmpty {
            VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                SectionHeader("Overdue", subtitle: "\(overdue.count) missed today")

                VStack(spacing: 0) {
                    ForEach(Array(overdue.enumerated()), id: \.element.id) { index, occurrence in
                        OccurrenceRow(occurrence: occurrence, pet: store.pet(id: occurrence.petID), now: now) {
                            store.toggleCompletion(of: occurrence)
                        }
                        if index < overdue.count - 1 { Divider().padding(.leading, 44) }
                    }
                }
                .petCard(accent: Theme.concern, padding: 12)
            }
        }
    }

    // MARK: Upcoming

    @ViewBuilder
    private var upcomingSection: some View {
        let upcoming = store.upcomingOccurrences(limit: 4, now: now)

        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                SectionHeader("Up next")

                VStack(spacing: 0) {
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, occurrence in
                        OccurrenceRow(occurrence: occurrence, pet: store.pet(id: occurrence.petID), now: now) {
                            store.toggleCompletion(of: occurrence)
                        }
                        if index < upcoming.count - 1 { Divider().padding(.leading, 44) }
                    }
                }
                .petCard(padding: 12)
            }
        }
    }

    // MARK: Pets

    private var petsSection: some View {
        VStack(alignment: .leading, spacing: Theme.stackSpacing) {
            SectionHeader("Your pets", subtitle: "Tap to log today")

            ForEach(store.pets) { pet in
                PetStatusCard(pet: pet, now: now, onQuickLog: { onQuickLog(pet) })
            }
        }
    }

    // MARK: Health due

    @ViewBuilder
    private var healthDueSection: some View {
        let due = store.upcomingHealthDue()

        if !due.isEmpty {
            VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                SectionHeader("Health coming up")

                VStack(spacing: 10) {
                    ForEach(due) { record in
                        HStack(spacing: 10) {
                            Image(systemName: record.kind.symbolName)
                                .font(.caption)
                                .foregroundStyle(record.isOverdue ? Theme.concern : .secondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(record.title)
                                    .font(.subheadline)
                                if let pet = store.pet(id: record.petID) {
                                    Text(pet.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if let days = record.daysUntilDue() {
                                Text(days < 0 ? "\(-days)d overdue" : (days == 0 ? "Today" : "in \(days)d"))
                                    .font(.caption.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(record.isOverdue ? Theme.concern : .secondary)
                            }
                        }
                    }
                }
                .petCard()
            }
        }
    }
}

// MARK: - PetStatusCard

/// One pet's at-a-glance row: today's logging state, severity, and a
/// seven-day appetite sparkline against the learned normal band.
struct PetStatusCard: View {

    @Environment(MyPetStore.self) private var store
    let pet: Pet
    let now: Date
    var onQuickLog: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                PetAvatar(pet: pet, size: 46)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(pet.name)
                            .font(.headline)
                        if let severity = store.worstSeverity(for: pet.id) {
                            SeverityBadge(severity: severity, compact: true)
                        }
                    }
                    Text("\(pet.species.displayName) · \(pet.ageDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink {
                    PetDetailView(petID: pet.id)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .accessibilityLabel("Open \(pet.name)'s profile")
            }

            HStack(spacing: 0) {
                StatPill(
                    symbol: "fork.knife",
                    value: todayAppetite,
                    caption: "eaten today",
                    tint: pet.accent
                )
                StatPill(
                    symbol: "checklist",
                    value: taskProgress,
                    caption: "tasks done",
                    tint: pet.accent
                )
                StatPill(
                    symbol: "calendar",
                    value: "\(store.loggingStreak(for: pet.id))/7",
                    caption: "days logged",
                    tint: pet.accent
                )
            }

            appetiteTrend

            Button(action: onQuickLog) {
                Label(
                    store.log(for: pet.id, on: now) == nil ? "Log today" : "Update today's log",
                    systemImage: "square.and.pencil"
                )
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(minHeight: Theme.minimumTapTarget - 8)
            }
            .buttonStyle(.bordered)
            .tint(pet.accent)
        }
        .petCard(accent: pet.accent)
    }

    private var todayAppetite: String {
        guard let log = store.log(for: pet.id, on: now) else { return "—" }
        return "\(Int((log.appetiteRatio * 100).rounded()))%"
    }

    private var taskProgress: String {
        let occurrences = store.occurrences(for: pet.id, on: now)
        guard !occurrences.isEmpty else { return "—" }
        return "\(occurrences.filter(\.isCompleted).count)/\(occurrences.count)"
    }

    @ViewBuilder
    private var appetiteTrend: some View {
        let recent = store.logs(for: pet.id).prefix(14).reversed().map(\.appetiteRatio)
        let baseline = store.baseline(for: pet)

        if recent.count >= 3 {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Appetite, last \(recent.count) logs")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let appetiteBaseline = baseline[.appetite], appetiteBaseline.isEstablished {
                        Text("normal \(BehaviorMetric.appetite.format(appetiteBaseline.median))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("learning normal…")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Sparkline(
                    values: Array(recent),
                    band: baseline[.appetite].map {
                        (centre: $0.median, spread: $0.effectiveSpread)
                    },
                    tint: pet.accent,
                    height: 30
                )
            }
        }
    }
}

// MARK: - OccurrenceRow

struct OccurrenceRow: View {

    let occurrence: TaskOccurrence
    let pet: Pet?
    let now: Date
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: occurrence.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(occurrence.isCompleted ? Theme.positive : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 32, height: Theme.minimumTapTarget)
            .contentShape(Rectangle())
            .accessibilityLabel(occurrence.isCompleted ? "Mark \(occurrence.title) not done" : "Mark \(occurrence.title) done")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: occurrence.category.symbolName)
                        .font(.caption2)
                        .foregroundStyle(pet?.accent ?? .secondary)
                    Text(occurrence.title)
                        .font(.subheadline)
                        .strikethrough(occurrence.isCompleted, color: .secondary)
                        .foregroundStyle(occurrence.isCompleted ? .secondary : .primary)
                }

                HStack(spacing: 5) {
                    if let pet { Text(pet.name) }
                    if !occurrence.detail.isEmpty {
                        Text("·")
                        Text(occurrence.detail).lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(occurrence.dueAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(occurrence.isOverdue(now: now) ? Theme.concern : .secondary)

                if occurrence.isSeriouslyOverdue(now: now) {
                    Text(occurrence.category.isCritical ? "Missed" : "Late")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.concern)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Hero pieces

private struct HeroStat: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(caption)
                .font(.caption2)
                .opacity(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PromiseChip: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.white.opacity(0.22), in: Capsule())
    }
}
