import Foundation

/// Tuning for the whole detection pipeline. Exposed as a value type so tests
/// can shrink the windows and the Settings screen can expose sensitivity
/// without any of the maths reaching for a global.
struct DetectionConfig: Codable, Hashable {

    /// Days of history used to learn normal, for metrics logged most days.
    var baselineWindowDays: Int = 28

    /// Longer window for sparse metrics like weight, where a month might hold
    /// only two or three weigh-ins.
    var sparseBaselineWindowDays: Int = 120

    /// The recent days under evaluation. Kept short: the point is to catch a
    /// change while it is still new.
    var evaluationWindowDays: Int = 3

    /// Robust z beyond which a single day counts as deviating.
    var dayAnomalyThreshold: Double = 1.8

    /// Syndrome score, `0...1`, above which a day counts as tripping.
    var syndromeTripThreshold: Double = 0.45

    /// Global sensitivity multiplier applied to every z-score.
    /// `< 1` is more forgiving, `> 1` more twitchy. Driven by the Settings slider.
    var sensitivity: Double = 1.0

    /// Below this confidence a flag is downgraded rather than shown at full
    /// strength — we know too little about the pet to be assertive.
    var minimumConfidence: Double = 0.25

    static let `default` = DetectionConfig()

    /// A tighter configuration used by the unit tests, so fixtures stay small.
    static let testing = DetectionConfig(
        baselineWindowDays: 21,
        sparseBaselineWindowDays: 60,
        evaluationWindowDays: 3,
        dayAnomalyThreshold: 1.8,
        syndromeTripThreshold: 0.45,
        sensitivity: 1.0,
        minimumConfidence: 0.2
    )
}

/// Learns each pet's individual normal from its own history.
///
/// Nothing here is shared across pets. A greyhound that sleeps 16 hours and a
/// terrier that sleeps 9 are both entirely normal — the only meaningful
/// question is whether *this* animal has changed. That per-subject framing is
/// what makes the detector usable without a labelled training set.
struct BaselineModel {

    var config: DetectionConfig = .default

    /// Builds baselines for one pet from its logs.
    ///
    /// - Parameters:
    ///   - logs: every log for the pet; unsorted input is fine.
    ///   - species: used only to seed a fallback centre when the pet has no
    ///     history at all for a metric.
    ///   - asOf: treated as "now"; injectable so tests are deterministic.
    ///
    /// The evaluation window is **excluded** from the baseline. If it were
    /// included, a pet that stopped eating for three days would quietly pull its
    /// own baseline down and the anomaly would shrink each day it persisted —
    /// exactly backwards from what a carer needs.
    func buildBaseline(
        logs: [BehaviorLog],
        species: Species,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> PetBaseline {

        let today = calendar.startOfDay(for: asOf)
        let evaluationStart = calendar.date(
            byAdding: .day, value: -(config.evaluationWindowDays - 1), to: today
        ) ?? today

        var metrics: [BehaviorMetric: MetricBaseline] = [:]

        for metric in BehaviorMetric.allCases {
            let windowDays = metric.isSparse ? config.sparseBaselineWindowDays : config.baselineWindowDays
            let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: evaluationStart) ?? today

            // History strictly before the evaluation window.
            let samples = logs
                .filter { $0.day >= windowStart && $0.day < evaluationStart }
                .sorted { $0.day < $1.day }
                .compactMap { $0.value(for: metric) }

            guard !samples.isEmpty else { continue }

            let centre = Statistics.median(samples) ?? seedCentre(for: metric, species: species)
            let spread = Statistics.scaledMAD(samples) ?? 0
            let smoothed = Statistics.ewma(samples, span: min(7, samples.count)) ?? centre

            metrics[metric] = MetricBaseline(
                metric: metric,
                median: centre,
                scaledMAD: spread,
                ewma: smoothed,
                sampleCount: samples.count,
                windowDays: windowDays,
                computedAt: asOf
            )
        }

        let distinctDays = Set(logs.map(\.day)).count

        return PetBaseline(
            petID: logs.first?.petID ?? UUID(),
            metrics: metrics,
            daysObserved: distinctDays,
            computedAt: asOf
        )
    }

    /// Species-typical starting point, used only when a pet has literally no
    /// history for a metric. It is never used for scoring — a baseline with no
    /// samples is not `isEstablished`, so the detector refuses to flag on it.
    private func seedCentre(for metric: BehaviorMetric, species: Species) -> Double {
        switch metric {
        case .appetite: 0.95
        case .water: 400
        case .sleep: species.typicalSleepHours
        case .activity: species.typicalActivityMinutes
        case .energy: 3.5
        case .weight: 0
        }
    }
}

// MARK: - Feature extraction

/// Turns raw logs into the aligned, gap-aware daily series the detector scores.
///
/// Missing values are left missing rather than interpolated. A day a carer
/// forgot to log is not evidence of anything, and filling it with the median
/// would manufacture reassurance the data does not support.
struct FeatureExtractor {

    /// Ordered `(day, value)` pairs for one metric within a date range.
    static func series(
        from logs: [BehaviorLog],
        metric: BehaviorMetric,
        in interval: DateInterval
    ) -> [(day: Date, value: Double)] {
        logs
            .filter { interval.contains($0.day) }
            .sorted { $0.day < $1.day }
            .compactMap { log in
                guard let value = log.value(for: metric) else { return nil }
                return (log.day, value)
            }
    }

    /// The evaluation-window logs for one pet, most recent last.
    static func evaluationLogs(
        from logs: [BehaviorLog],
        config: DetectionConfig,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> [BehaviorLog] {
        let today = calendar.startOfDay(for: asOf)
        guard let start = calendar.date(
            byAdding: .day, value: -(config.evaluationWindowDays - 1), to: today
        ) else { return [] }

        return logs
            .filter { $0.day >= start && $0.day <= today }
            .sorted { $0.day < $1.day }
    }

    /// Fraction of the evaluation window that actually has a log. Feeds
    /// confidence: three days of data supports a firmer claim than one.
    static func coverage(
        logs: [BehaviorLog],
        config: DetectionConfig,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        let window = evaluationLogs(from: logs, config: config, asOf: asOf, calendar: calendar)
        guard config.evaluationWindowDays > 0 else { return 0 }
        return min(Double(window.count) / Double(config.evaluationWindowDays), 1.0)
    }
}
