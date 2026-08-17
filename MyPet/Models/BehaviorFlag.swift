import Foundation
import SwiftUI

/// A detected departure from a pet's own normal routine, raised by
/// `AnomalyDetector` and surfaced on the dashboard.
///
/// A flag is always *explainable*: it carries the evidence that produced it, so
/// a carer (or a vet) can see exactly which metrics moved, by how much, and
/// against what expectation. A score with no evidence would be worse than no
/// flag at all — it would be an unfalsifiable claim about someone's pet.
struct BehaviorFlag: Identifiable, Codable, Hashable {

    var id: UUID = UUID()
    var petID: UUID
    var kind: FlagKind

    var severity: FlagSeverity
    var detectedAt: Date

    /// Composite anomaly score, `0...1`. Higher means further from baseline
    /// across more of the syndrome's metrics, for more of the window.
    var score: Double

    /// How much history backs this call, `0...1`. Low confidence means the
    /// baseline is still thin — the flag is shown, but softened.
    var confidence: Double

    /// Days of the evaluation window on which the syndrome tripped.
    var persistenceDays: Int

    /// Length of the evaluation window in days.
    var windowDays: Int

    /// Which metrics moved, and by how much.
    var evidence: [MetricEvidence]

    var status: FlagStatus = .active
    var acknowledgedAt: Date?

    /// Copy is generated at detection time so the dashboard stays dumb and the
    /// wording lives next to the maths that justifies it.
    var headline: String
    var explanation: String
    var recommendation: String

    /// A flag is "the same flag" as another when it concerns the same pet and
    /// the same syndrome. Used to update an ongoing flag in place rather than
    /// pile up a new card every time the detector runs.
    var dedupeKey: String { "\(petID.uuidString)-\(kind.rawValue)" }

    var isActionable: Bool { status == .active && severity >= .watch }
}

// MARK: - FlagKind

/// The syndromes the detector recognises. Each one is a named, weighted
/// combination of metric deviations — see `AnomalyDetector.syndromes`.
enum FlagKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case appetiteLoss
    case hydrationChange
    case sleepDisruption
    case lethargy
    case weightTrend
    case eliminationChange
    case multiSystem

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appetiteLoss: "Appetite drop"
        case .hydrationChange: "Water intake shift"
        case .sleepDisruption: "Sleep pattern shift"
        case .lethargy: "Lethargy"
        case .weightTrend: "Weight trend"
        case .eliminationChange: "Toileting change"
        case .multiSystem: "Multiple systems affected"
        }
    }

    var symbolName: String {
        switch self {
        case .appetiteLoss: "fork.knife.circle.fill"
        case .hydrationChange: "drop.triangle.fill"
        case .sleepDisruption: "moon.zzz.fill"
        case .lethargy: "battery.25percent"
        case .weightTrend: "scalemass.fill"
        case .eliminationChange: "exclamationmark.triangle.fill"
        case .multiSystem: "waveform.path.ecg"
        }
    }
}

// MARK: - FlagSeverity

enum FlagSeverity: Int, Codable, CaseIterable, Comparable, Hashable {
    case info = 0
    case watch = 1
    case concern = 2
    case urgent = 3

    static func < (lhs: FlagSeverity, rhs: FlagSeverity) -> Bool { lhs.rawValue < rhs.rawValue }

    var displayName: String {
        switch self {
        case .info: "Noticed"
        case .watch: "Watch"
        case .concern: "Concern"
        case .urgent: "Urgent"
        }
    }

    var color: Color {
        switch self {
        case .info: Theme.info
        case .watch: Theme.watch
        case .concern: Theme.concern
        case .urgent: Theme.urgent
        }
    }

    var symbolName: String {
        switch self {
        case .info: "info.circle.fill"
        case .watch: "eye.fill"
        case .concern: "exclamationmark.triangle.fill"
        case .urgent: "exclamationmark.octagon.fill"
        }
    }

    /// Only `concern` and above are worth interrupting someone's day for.
    var warrantsNotification: Bool { self >= .concern }
}

// MARK: - FlagStatus

enum FlagStatus: String, Codable, CaseIterable, Hashable {
    /// Currently tripping.
    case active
    /// Carer has seen it and chosen to keep watching.
    case acknowledged
    /// The metrics came back inside baseline on their own.
    case resolved
    /// Carer said this is expected — e.g. a planned diet change.
    case dismissed

    var displayName: String {
        switch self {
        case .active: "Active"
        case .acknowledged: "Acknowledged"
        case .resolved: "Resolved"
        case .dismissed: "Dismissed"
        }
    }
}

// MARK: - MetricEvidence

/// One metric's contribution to a flag: what we saw, what we expected, and how
/// far apart those are in robust standard deviations.
struct MetricEvidence: Codable, Hashable, Identifiable {
    var metric: BehaviorMetric

    /// Mean of the metric across the evaluation window.
    var observed: Double

    /// The pet's own baseline centre (median of the trailing window).
    var expected: Double

    /// Signed robust z-score. Negative means below baseline.
    var z: Double

    var id: String { metric.rawValue }

    /// Signed percentage change from baseline, `nil` when baseline is zero.
    var percentChange: Double? {
        guard expected != 0 else { return nil }
        return (observed - expected) / abs(expected) * 100
    }

    var directionSymbol: String { z < 0 ? "arrow.down" : "arrow.up" }

    /// "Appetite 42% of meals vs 91% usual"
    var summary: String {
        "\(metric.displayName) \(metric.format(observed)) vs \(metric.format(expected)) usual"
    }
}

// MARK: - Baselines

/// What "normal" looks like for one pet on one metric.
///
/// Built from a trailing window using the **median** and **median absolute
/// deviation** rather than mean and standard deviation. That choice is the
/// whole ballgame: one vet day with zero food would drag a mean baseline down
/// far enough to mask the next week of genuinely reduced eating. The median
/// shrugs it off.
struct MetricBaseline: Codable, Hashable {
    var metric: BehaviorMetric

    /// Robust centre — the median of observed values in the window.
    var median: Double

    /// Median absolute deviation, already scaled by 1.4826 so it estimates the
    /// standard deviation of a normal distribution.
    var scaledMAD: Double

    /// Exponentially weighted moving average, weighting recent days more.
    /// Used to describe drift, not to score anomalies.
    var ewma: Double

    /// How many days actually carried a value for this metric.
    var sampleCount: Int

    var windowDays: Int
    var computedAt: Date

    /// A baseline needs enough days before it is allowed to accuse anyone of
    /// anything. Sparse metrics like weight get a lower bar.
    var isEstablished: Bool { sampleCount >= (metric.isSparse ? 4 : 7) }

    /// Effective spread used for scoring: never below the metric's noise floor,
    /// so a pet with an unusually rigid routine does not trip on trivia.
    var effectiveSpread: Double { max(scaledMAD, metric.noiseFloor) }

    /// Signed robust z-score of `value` against this baseline.
    func z(for value: Double) -> Double {
        (value - median) / effectiveSpread
    }

    /// Confidence contribution from sample size, saturating at 21 days.
    var sampleConfidence: Double {
        min(Double(sampleCount) / 21.0, 1.0)
    }
}

/// The full per-pet picture: one baseline per metric it has data for.
struct PetBaseline: Codable, Hashable {
    var petID: UUID
    var metrics: [BehaviorMetric: MetricBaseline]
    var daysObserved: Int
    var computedAt: Date

    subscript(metric: BehaviorMetric) -> MetricBaseline? { metrics[metric] }

    /// True once at least one metric has enough history to score against.
    var isEstablished: Bool { metrics.values.contains { $0.isEstablished } }

    /// Fraction of all metrics with an established baseline — the headline
    /// "how well do we know this pet yet" number.
    var coverage: Double {
        guard !BehaviorMetric.allCases.isEmpty else { return 0 }
        let established = metrics.values.filter(\.isEstablished).count
        return Double(established) / Double(BehaviorMetric.allCases.count)
    }
}
