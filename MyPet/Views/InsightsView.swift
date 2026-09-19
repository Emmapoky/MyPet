import Charts
import SwiftUI

/// Where the model shows its working.
///
/// Every chart draws the pet's learned *normal band* behind the observed line,
/// so the question "is this unusual?" is answerable by eye. A flag then reads
/// as a description of something already visible rather than a verdict handed
/// down by a black box.
struct InsightsView: View {

    @Environment(MyPetStore.self) private var store

    @State private var selectedPetID: UUID?
    @State private var range: Range = .month

    enum Range: String, CaseIterable, Identifiable {
        case fortnight = "14 days"
        case month = "30 days"
        case quarter = "90 days"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .fortnight: 14
            case .month: 30
            case .quarter: 90
            }
        }
    }

    private var selectedPet: Pet? {
        if let selectedPetID, let pet = store.pet(id: selectedPetID) { return pet }
        return store.pets.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let pet = selectedPet {
                    content(for: pet)
                } else {
                    EmptyStateView(
                        symbol: "chart.xyaxis.line",
                        title: "Nothing to chart yet",
                        message: "Add a pet and log a few days to see trends against their learned baseline."
                    )
                }
            }
            .background(Theme.pageGradient.ignoresSafeArea())
            .navigationTitle("Insights")
            .toolbar {
                if store.pets.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ForEach(store.pets) { pet in
                                Button {
                                    selectedPetID = pet.id
                                } label: {
                                    Label(pet.name, systemImage: pet.symbolName)
                                }
                            }
                        } label: {
                            Label(selectedPet?.name ?? "Pet", systemImage: "pawprint.fill")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
    }

    private func content(for pet: Pet) -> some View {
        ScrollView {
            VStack(spacing: Theme.sectionSpacing) {
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                baselineSummary(for: pet)

                if store.baseline(for: pet).daysObserved >= Self.minimumDaysBeforeCharts {
                    ForEach(BehaviorMetric.tracked) { metric in
                        MetricChartCard(pet: pet, metric: metric, days: range.days)
                    }
                } else {
                    notEnoughDaysCard(for: pet)
                }

                methodNote
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    /// Charts stay hidden until there is enough history to read them. A graph
    /// after two days swings wildly and worries owners for no reason (Erwyna,
    /// Supervisor Meeting 2). 7 matches NFR07; the team may raise it to ~15.
    static let minimumDaysBeforeCharts = 7

    private func notEnoughDaysCard(for pet: Pet) -> some View {
        let days = store.baseline(for: pet).daysObserved
        return VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(pet.accent)
            Text("Still learning \(pet.name)'s normal")
                .font(.headline)
            Text("Charts appear after \(Self.minimumDaysBeforeCharts) logged days, so a couple of odd days don't look alarming. \(days) of \(Self.minimumDaysBeforeCharts) so far.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ProgressView(value: Double(min(days, Self.minimumDaysBeforeCharts)), total: Double(Self.minimumDaysBeforeCharts))
                .tint(pet.accent)
        }
        .frame(maxWidth: .infinity)
        .petCard(accent: pet.accent)
    }

    // MARK: Baseline summary

    private func baselineSummary(for pet: Pet) -> some View {
        let baseline = store.baseline(for: pet)
        let established = BehaviorMetric.tracked.filter { baseline[$0]?.isEstablished == true }.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("What MyPet knows about \(pet.name)")
                        .font(.subheadline.weight(.semibold))
                    Text("\(baseline.daysObserved) days logged · \(established) of \(BehaviorMetric.tracked.count) baselines established")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(pet.accent)
                        .frame(width: geometry.size.width * baseline.coverage)
                }
            }
            .frame(height: 7)

            if !baseline.isEstablished {
                Label(
                    "Not enough history yet. MyPet needs about seven logged days per metric before it will flag anything.",
                    systemImage: "hourglass"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .petCard(accent: pet.accent)
    }

    // MARK: Method note

    private var methodNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How the flags are worked out", systemImage: "brain.head.profile")
                .font(.subheadline.weight(.semibold))

            Text("""
                MyPet learns each pet's own normal from the median and spread of their last few \
                weeks, then measures how far the last three days sit from it. Related signals are \
                combined — eating less *and* moving less *and* sleeping more is treated as one \
                pattern, not three coincidences. A change has to hold for more than one day before \
                it escalates.

                Shaded bands on these charts are the normal range. A line leaving its band is what \
                the model reacts to.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("MyPet is a monitoring aid, not a diagnostic tool. It flags changes in routine. Only a vet can say what a change means.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .petCard()
    }
}

// MARK: - MetricChartCard

/// One metric over time, with the learned normal band behind it.
struct MetricChartCard: View {

    @Environment(MyPetStore.self) private var store

    let pet: Pet
    let metric: BehaviorMetric
    let days: Int

    private var points: [(day: Date, value: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -days, to: today) else { return [] }

        return FeatureExtractor.series(
            from: store.logs(for: pet.id),
            metric: metric,
            in: DateInterval(start: start, end: today)
        )
    }

    private var baseline: MetricBaseline? {
        store.baseline(for: pet)[metric]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if points.count < 2 {
                Text("Not enough data in this range.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                chart
            }
        }
        .petCard()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(metric.displayName, systemImage: metric.symbolName)
                .font(.subheadline.weight(.semibold))

            Spacer()

            if let baseline, baseline.isEstablished {
                Text("normal \(metric.format(baseline.median))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Text("learning…")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var chart: some View {
        Chart {
            if let baseline, baseline.isEstablished {
                // The normal band: baseline centre ± one robust spread.
                RectangleMark(
                    xStart: .value("Start", points.first?.day ?? .now),
                    xEnd: .value("End", points.last?.day ?? .now),
                    yStart: .value("Low", baseline.median - baseline.effectiveSpread),
                    yEnd: .value("High", baseline.median + baseline.effectiveSpread)
                )
                .foregroundStyle(pet.accent.opacity(0.13))

                RuleMark(y: .value("Baseline", baseline.median))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(pet.accent.opacity(0.55))
            }

            ForEach(points, id: \.day) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value(metric.displayName, point.value)
                )
                .foregroundStyle(pet.accent)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Day", point.day),
                    y: .value(metric.displayName, point.value)
                )
                .symbolSize(points.count > 30 ? 8 : 22)
                .foregroundStyle(colour(for: point.value))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .frame(height: 120)
        .accessibilityLabel("\(metric.displayName) over the last \(days) days for \(pet.name)")
    }

    /// Points outside the normal band, in the concerning direction, are tinted
    /// so an anomaly is visible before anyone reads a word.
    private func colour(for value: Double) -> Color {
        guard let baseline, baseline.isEstablished else { return pet.accent }
        let z = baseline.z(for: value)
        guard metric.concerningDirection.admits(z), abs(z) >= 1.8 else { return pet.accent }
        return abs(z) >= 3 ? Theme.concern : Theme.watch
    }
}
