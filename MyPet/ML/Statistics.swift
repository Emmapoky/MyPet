import Foundation

/// Small, dependency-free statistics helpers used by the baseline model.
///
/// Everything here is deliberately robust (median-based) rather than
/// mean-based. Pet care data is short, gappy and full of legitimate one-off
/// extremes — a fasting day before surgery, a birthday steak — and mean/σ
/// statistics handle those badly at these sample sizes.
enum Statistics {

    /// Constant that makes the median absolute deviation a consistent estimator
    /// of σ for normally distributed data.
    static let madToSigma = 1.4826

    /// Median of `values`. Returns `nil` for an empty input.
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    /// Median absolute deviation, scaled to be comparable with a standard
    /// deviation. Returns `nil` for an empty input, and `0` when every value is
    /// identical — callers must apply their own floor.
    static func scaledMAD(_ values: [Double]) -> Double? {
        guard let m = median(values) else { return nil }
        let deviations = values.map { abs($0 - m) }
        guard let mad = median(deviations) else { return nil }
        return mad * madToSigma
    }

    static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func standardDeviation(_ values: [Double]) -> Double? {
        guard values.count > 1, let mu = mean(values) else { return nil }
        let variance = values.reduce(0) { $0 + ($1 - mu) * ($1 - mu) } / Double(values.count - 1)
        return variance.squareRoot()
    }

    /// Exponentially weighted moving average over `values` in chronological
    /// order, with the smoothing factor derived from `span` the usual way
    /// (`alpha = 2 / (span + 1)`).
    static func ewma(_ values: [Double], span: Int) -> Double? {
        guard let first = values.first else { return nil }
        guard span > 0 else { return first }
        let alpha = 2.0 / (Double(span) + 1.0)
        var accumulator = first
        for value in values.dropFirst() {
            accumulator = alpha * value + (1 - alpha) * accumulator
        }
        return accumulator
    }

    /// Ordinary-least-squares slope of `values` against their index, i.e. the
    /// per-step trend. Used for weight drift, where direction over a fortnight
    /// matters more than any single day's deviation.
    static func linearSlope(_ values: [Double]) -> Double? {
        guard values.count > 1 else { return nil }
        let n = Double(values.count)
        let xs = (0..<values.count).map(Double.init)
        let xMean = xs.reduce(0, +) / n
        let yMean = values.reduce(0, +) / n

        var numerator = 0.0
        var denominator = 0.0
        for (x, y) in zip(xs, values) {
            numerator += (x - xMean) * (y - yMean)
            denominator += (x - xMean) * (x - xMean)
        }
        guard denominator != 0 else { return nil }
        return numerator / denominator
    }

    /// Clamps `value` into `range`.
    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
