import Foundation

/// The behaviour-monitoring model.
///
/// ## What it is
///
/// An **unsupervised, per-subject anomaly detector**. It learns each pet's own
/// baseline (see `BaselineModel`), converts recent days into robust z-scores
/// against that baseline, and combines correlated metrics into named
/// *syndromes* — appetite loss, lethargy, sleep disruption and so on.
///
/// ## Why not a trained classifier
///
/// A supervised model would need labelled sick/healthy days per animal, which
/// no household has and no public dataset supplies at the granularity of "this
/// specific cat". Per-subject anomaly detection sidesteps the labelling problem
/// entirely and generalises to any species from day one. The trade-off is that
/// it detects *change*, not *diagnosis* — which is exactly the claim the app
/// makes to the user, and no more.
///
/// ## Three design choices that carry most of the weight
///
/// 1. **Robust statistics.** Median and MAD instead of mean and σ, so a single
///    fasting day before a vet visit cannot poison the baseline.
/// 2. **Persistence gating.** A syndrome must trip on multiple days of the
///    evaluation window before it escalates. One-day wobble is normal in
///    animals, and a detector that cries wolf gets muted, which is worse than
///    one that says nothing.
/// 3. **Directionality.** Eating *less* is a symptom; eating slightly more is
///    not. Every metric declares which direction of deviation matters, so the
///    model does not raise alarms about a good week.
///
/// ## Swapping in Core ML
///
/// `AnomalyDetector` is a plain value type behind
/// `BehaviorAnalysisService`. Replacing it with a Core ML model means
/// conforming to the same `analyze(...) -> [BehaviorFlag]` shape; nothing in the
/// UI or persistence layers knows which implementation is running.
struct AnomalyDetector {

    var config: DetectionConfig = .default

    // MARK: - Syndrome definitions

    /// One metric's role inside a syndrome.
    struct Contribution: Hashable {
        var metric: BehaviorMetric
        /// Which direction of deviation counts for *this syndrome*, which is
        /// not always the metric's default. Sleeping more is lethargy;
        /// sleeping less is disruption.
        var direction: BehaviorMetric.Direction
        var weight: Double
    }

    /// A named, weighted combination of metric deviations.
    struct Syndrome {
        var kind: FlagKind
        /// At least one primary metric must deviate for the syndrome to score
        /// at all. Prevents a pile of weak supporting signals from inventing a
        /// syndrome that has no core symptom.
        var primary: [Contribution]
        var supporting: [Contribution]

        var all: [Contribution] { primary + supporting }
    }

    /// The syndromes scored on every run. Weights are clinical priors — how
    /// strongly each observable channel indicates the syndrome — not learned
    /// parameters, and they are deliberately few and legible.
    static let syndromes: [Syndrome] = [
        Syndrome(
            kind: .appetiteLoss,
            primary: [
                Contribution(metric: .appetite, direction: .below, weight: 1.0)
            ],
            supporting: [
                Contribution(metric: .energy, direction: .below, weight: 0.4),
                Contribution(metric: .weight, direction: .below, weight: 0.3)
            ]
        ),
        Syndrome(
            kind: .lethargy,
            primary: [
                Contribution(metric: .activity, direction: .below, weight: 0.9),
                Contribution(metric: .energy, direction: .below, weight: 0.9)
            ],
            supporting: [
                Contribution(metric: .sleep, direction: .above, weight: 0.5),
                Contribution(metric: .appetite, direction: .below, weight: 0.3)
            ]
        ),
        Syndrome(
            kind: .sleepDisruption,
            primary: [
                Contribution(metric: .sleep, direction: .both, weight: 1.0)
            ],
            supporting: [
                Contribution(metric: .energy, direction: .below, weight: 0.35),
                Contribution(metric: .activity, direction: .both, weight: 0.25)
            ]
        ),
        Syndrome(
            kind: .hydrationChange,
            primary: [
                Contribution(metric: .water, direction: .both, weight: 1.0)
            ],
            supporting: [
                Contribution(metric: .appetite, direction: .below, weight: 0.3)
            ]
        )
    ]

    // MARK: - Entry point

    /// Scores one pet's recent behaviour and returns any flags worth showing.
    ///
    /// - Parameters:
    ///   - pet: the subject; species seeds fallbacks, name feeds the copy.
    ///   - logs: all logs for that pet. Unsorted is fine.
    ///   - asOf: injectable "now" so tests and previews are deterministic.
    /// - Returns: flags sorted most severe first. Empty when nothing deviates,
    ///   or when the pet does not yet have enough history to judge.
    func analyze(
        pet: Pet,
        logs: [BehaviorLog],
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> [BehaviorFlag] {

        let baselineModel = BaselineModel(config: config)
        let baseline = baselineModel.buildBaseline(
            logs: logs, species: pet.species, asOf: asOf, calendar: calendar
        )

        guard baseline.isEstablished else { return [] }

        let window = FeatureExtractor.evaluationLogs(
            from: logs, config: config, asOf: asOf, calendar: calendar
        )
        guard !window.isEmpty else { return [] }

        let windowCoverage = FeatureExtractor.coverage(
            logs: logs, config: config, asOf: asOf, calendar: calendar
        )

        var flags: [BehaviorFlag] = []

        for syndrome in Self.syndromes {
            if let flag = evaluate(
                syndrome: syndrome,
                pet: pet,
                baseline: baseline,
                window: window,
                windowCoverage: windowCoverage,
                asOf: asOf
            ) {
                flags.append(flag)
            }
        }

        if let weightFlag = evaluateWeightTrend(
            pet: pet, logs: logs, baseline: baseline, asOf: asOf, calendar: calendar
        ) {
            flags.append(weightFlag)
        }

        if let eliminationFlag = evaluateElimination(
            pet: pet, logs: logs, window: window, asOf: asOf, calendar: calendar
        ) {
            flags.append(eliminationFlag)
        }

        if let multi = evaluateMultiSystem(pet: pet, flags: flags, asOf: asOf) {
            flags.append(multi)
        }

        return flags.sorted {
            ($0.severity, $0.score) > ($1.severity, $1.score)
        }
    }

    // MARK: - Syndrome scoring

    private func evaluate(
        syndrome: Syndrome,
        pet: Pet,
        baseline: PetBaseline,
        window: [BehaviorLog],
        windowCoverage: Double,
        asOf: Date
    ) -> BehaviorFlag? {

        var dayScores: [Double] = []

        for log in window {
            dayScores.append(score(syndrome: syndrome, log: log, baseline: baseline))
        }

        let trippingScores = dayScores.filter { $0 >= config.syndromeTripThreshold }
        let persistence = trippingScores.count
        guard persistence > 0 else { return nil }

        let score = Statistics.mean(trippingScores) ?? 0
        let evidence = buildEvidence(for: syndrome, baseline: baseline, window: window)
        guard !evidence.isEmpty else { return nil }

        let confidence = self.confidence(
            for: syndrome, baseline: baseline, windowCoverage: windowCoverage
        )
        guard confidence >= config.minimumConfidence else { return nil }

        let severity = self.severity(
            score: score,
            persistence: persistence,
            windowDays: window.count,
            confidence: confidence
        )

        let copy = Copy.make(kind: syndrome.kind, pet: pet, evidence: evidence, severity: severity)

        return BehaviorFlag(
            petID: pet.id,
            kind: syndrome.kind,
            severity: severity,
            detectedAt: asOf,
            score: score,
            confidence: confidence,
            persistenceDays: persistence,
            windowDays: window.count,
            evidence: evidence,
            headline: copy.headline,
            explanation: copy.explanation,
            recommendation: copy.recommendation
        )
    }

    /// Scores one syndrome on one day, `0...1`.
    ///
    /// Metrics without a value that day, or without an established baseline,
    /// drop out of both numerator and denominator — so a partially logged day
    /// is scored on what it does contain rather than being penalised or
    /// silently treated as normal.
    func score(syndrome: Syndrome, log: BehaviorLog, baseline: PetBaseline) -> Double {

        var weightedSum = 0.0
        var totalWeight = 0.0
        var primaryFired = false

        for contribution in syndrome.all {
            guard
                let metricBaseline = baseline[contribution.metric],
                metricBaseline.isEstablished,
                let observed = log.value(for: contribution.metric)
            else { continue }

            let z = metricBaseline.z(for: observed) * config.sensitivity
            totalWeight += contribution.weight

            // Deviation in the wrong direction for this syndrome contributes
            // nothing — it is not evidence against, merely irrelevant.
            guard contribution.direction.admits(z) else { continue }

            // |z| of 4 or beyond is saturated: past that point the difference
            // between "very abnormal" and "absurdly abnormal" does not change
            // what a carer should do.
            let magnitude = Statistics.clamp(abs(z) / 4.0, 0, 1)
            weightedSum += magnitude * contribution.weight

            if magnitude > 0,
               abs(z) >= config.dayAnomalyThreshold,
               syndrome.primary.contains(where: { $0.metric == contribution.metric }) {
                primaryFired = true
            }
        }

        guard totalWeight > 0, primaryFired else { return 0 }
        return Statistics.clamp(weightedSum / totalWeight, 0, 1)
    }

    // MARK: - Evidence

    /// Averages each contributing metric across the evaluation window and pairs
    /// it with the baseline it is being judged against.
    private func buildEvidence(
        for syndrome: Syndrome,
        baseline: PetBaseline,
        window: [BehaviorLog]
    ) -> [MetricEvidence] {

        var evidence: [MetricEvidence] = []

        for contribution in syndrome.all {
            guard
                let metricBaseline = baseline[contribution.metric],
                metricBaseline.isEstablished
            else { continue }

            let observations = window.compactMap { $0.value(for: contribution.metric) }
            guard let observed = Statistics.mean(observations) else { continue }

            let z = metricBaseline.z(for: observed) * config.sensitivity

            // Only report metrics that actually moved in the concerning
            // direction. Listing untroubled metrics as "evidence" would pad the
            // card and bury the signal.
            guard contribution.direction.admits(z), abs(z) >= 1.0 else { continue }

            evidence.append(
                MetricEvidence(
                    metric: contribution.metric,
                    observed: observed,
                    expected: metricBaseline.median,
                    z: z
                )
            )
        }

        return evidence.sorted { abs($0.z) > abs($1.z) }
    }

    // MARK: - Confidence and severity

    /// How much the model trusts its own baseline for this syndrome.
    ///
    /// Half comes from how much history backs the contributing metrics, half
    /// from how completely the evaluation window itself was logged.
    private func confidence(
        for syndrome: Syndrome,
        baseline: PetBaseline,
        windowCoverage: Double
    ) -> Double {
        let sampleConfidences = syndrome.all.compactMap { contribution -> Double? in
            guard let metricBaseline = baseline[contribution.metric],
                  metricBaseline.isEstablished else { return nil }
            return metricBaseline.sampleConfidence
        }

        guard let baselineConfidence = Statistics.mean(sampleConfidences) else { return 0 }
        return Statistics.clamp(0.5 * baselineConfidence + 0.5 * windowCoverage, 0, 1)
    }

    /// Blends how far from normal (`score`) with how consistently
    /// (`persistence`), then softens the result when confidence is thin.
    private func severity(
        score: Double,
        persistence: Int,
        windowDays: Int,
        confidence: Double
    ) -> FlagSeverity {

        let persistenceRatio = windowDays > 0 ? Double(persistence) / Double(windowDays) : 0
        let combined = 0.65 * score + 0.35 * persistenceRatio

        var level: FlagSeverity
        switch combined {
        case 0.78...: level = .urgent
        case 0.60..<0.78: level = .concern
        case 0.45..<0.60: level = .watch
        default: level = .info
        }

        // A single deviating day never escalates past "watch", however extreme.
        // Animals have off days, and one data point is not a trend.
        if level > .watch, persistence < 2 { level = .watch }

        // Thin baseline: say something, but say it quietly.
        if confidence < 0.4, level > .info {
            level = FlagSeverity(rawValue: level.rawValue - 1) ?? .info
        }

        return level
    }

    // MARK: - Weight trend (slope-based, not day-based)

    /// Weight moves too slowly for day-level z-scores to be the right tool, so
    /// this looks at the regression slope over the last 30 days and expresses
    /// it as percent of body weight per week — the unit vets actually use.
    private func evaluateWeightTrend(
        pet: Pet,
        logs: [BehaviorLog],
        baseline: PetBaseline,
        asOf: Date,
        calendar: Calendar
    ) -> BehaviorFlag? {

        let today = calendar.startOfDay(for: asOf)
        guard let start = calendar.date(byAdding: .day, value: -30, to: today) else { return nil }

        let series = FeatureExtractor.series(
            from: logs, metric: .weight, in: DateInterval(start: start, end: today)
        )
        guard series.count >= 4 else { return nil }

        let values = series.map(\.value)
        guard
            let firstDay = series.first?.day,
            let lastDay = series.last?.day,
            let slopePerSample = Statistics.linearSlope(values),
            let centre = Statistics.median(values),
            centre > 0
        else { return nil }

        // Convert slope-per-sample into slope-per-day, then per-week, so the
        // number does not depend on how often the carer happened to weigh in.
        let spanDays = max(calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 1, 1)
        let perDay = slopePerSample * Double(values.count - 1) / Double(spanDays)
        let percentPerWeek = (perDay * 7 / centre) * 100

        // Under 1.5% of body weight per week is ordinary fluctuation.
        guard abs(percentPerWeek) >= 1.5 else { return nil }

        let latest = series.last?.value ?? centre
        let evidence = [
            MetricEvidence(
                metric: .weight,
                observed: latest,
                expected: centre,
                z: percentPerWeek < 0 ? -abs(percentPerWeek) / 2 : abs(percentPerWeek) / 2
            )
        ]

        let severity: FlagSeverity
        switch abs(percentPerWeek) {
        case 4...: severity = .concern
        case 2.5..<4: severity = percentPerWeek < 0 ? .concern : .watch
        default: severity = .watch
        }

        let losing = percentPerWeek < 0
        let magnitude = String(format: "%.1f%%", abs(percentPerWeek))

        return BehaviorFlag(
            petID: pet.id,
            kind: .weightTrend,
            severity: severity,
            detectedAt: asOf,
            score: Statistics.clamp(abs(percentPerWeek) / 6, 0, 1),
            confidence: Statistics.clamp(Double(series.count) / 8.0, 0, 1),
            persistenceDays: series.count,
            windowDays: spanDays,
            evidence: evidence,
            headline: "\(pet.name) is \(losing ? "losing" : "gaining") weight steadily",
            explanation: """
                Over the last \(spanDays) days \(pet.name)'s weight has trended \
                \(losing ? "down" : "up") by about \(magnitude) of body weight per week, \
                now \(BehaviorMetric.weight.format(latest)) against a recent typical \
                \(BehaviorMetric.weight.format(centre)). Based on \(series.count) weigh-ins.
                """,
            recommendation: losing
                ? "Unplanned weight loss is worth a vet call even when everything else looks fine. Bring these weigh-ins with you."
                : "If this is not a deliberate change to diet or exercise, mention it at the next check-up."
        )
    }

    // MARK: - Elimination (categorical, not continuous)

    /// Toileting is recorded as a yes/no, so it gets a rate comparison rather
    /// than a z-score: abnormal days in the recent window against the pet's own
    /// historical abnormal rate.
    private func evaluateElimination(
        pet: Pet,
        logs: [BehaviorLog],
        window: [BehaviorLog],
        asOf: Date,
        calendar: Calendar
    ) -> BehaviorFlag? {

        let abnormalRecent = window.filter { !$0.eliminationNormal }.count
        guard abnormalRecent >= 2 else { return nil }

        let today = calendar.startOfDay(for: asOf)
        guard
            let historyStart = calendar.date(byAdding: .day, value: -config.baselineWindowDays, to: today),
            let windowStart = window.first?.day
        else { return nil }

        let history = logs.filter { $0.day >= historyStart && $0.day < windowStart }
        guard history.count >= 7 else { return nil }

        let historicalRate = Double(history.filter { !$0.eliminationNormal }.count) / Double(history.count)
        let recentRate = Double(abnormalRecent) / Double(window.count)

        // Only interesting if this is genuinely unlike the pet's normal.
        guard recentRate > max(historicalRate * 2.5, 0.4) else { return nil }

        let severity: FlagSeverity = abnormalRecent >= 3 ? .concern : .watch

        return BehaviorFlag(
            petID: pet.id,
            kind: .eliminationChange,
            severity: severity,
            detectedAt: asOf,
            score: Statistics.clamp(recentRate, 0, 1),
            confidence: Statistics.clamp(Double(history.count) / 21.0, 0, 1),
            persistenceDays: abnormalRecent,
            windowDays: window.count,
            evidence: [],
            headline: "\(pet.name)'s toileting has changed",
            explanation: """
                \(abnormalRecent) of the last \(window.count) days were logged as outside \
                \(pet.name)'s normal toileting pattern. \(Self.historicalRatePhrase(historicalRate))
                """,
            recommendation: "A sudden toileting change is worth a vet call if it continues past another day or two."
        )
    }

    /// Describes the historical abnormal rate in words.
    ///
    /// Rounding straight to a percentage produced "happens on about 0% of days"
    /// for the most alarming case of all — a pet this has never happened to —
    /// which reads as a rounding error rather than the strongest part of the
    /// finding.
    static func historicalRatePhrase(_ rate: Double) -> String {
        let percent = Int((rate * 100).rounded())
        switch percent {
        case 0: return "That has essentially never happened before."
        case 1...4: return "Historically it happens on only about \(percent)% of days."
        default: return "Historically it happens on about \(percent)% of days."
        }
    }

    // MARK: - Multi-system escalation

    /// Several independent syndromes tripping at once is a stronger signal than
    /// any of them alone — that pattern is what generalised illness looks like
    /// from the outside.
    private func evaluateMultiSystem(
        pet: Pet,
        flags: [BehaviorFlag],
        asOf: Date
    ) -> BehaviorFlag? {

        // Constituent flags must themselves have persisted. Without this the
        // multi-system path would quietly bypass the persistence gate every
        // other flag obeys: one genuinely bad day trips appetite, lethargy and
        // sleep at once — three syndromes, one day — and would escalate to
        // `concern` on the strength of a single data point.
        let significant = flags.filter {
            $0.severity >= .watch && $0.kind != .multiSystem && $0.persistenceDays >= 2
        }
        guard significant.count >= 3 else { return nil }

        let combinedScore = Statistics.mean(significant.map(\.score)) ?? 0
        let combinedConfidence = Statistics.mean(significant.map(\.confidence)) ?? 0
        let names = significant.map { $0.kind.displayName.lowercased() }

        let severity: FlagSeverity = significant.contains { $0.severity >= .concern } ? .urgent : .concern

        return BehaviorFlag(
            petID: pet.id,
            kind: .multiSystem,
            severity: severity,
            detectedAt: asOf,
            score: Statistics.clamp(combinedScore + 0.1, 0, 1),
            confidence: combinedConfidence,
            persistenceDays: significant.map(\.persistenceDays).max() ?? 1,
            windowDays: significant.first?.windowDays ?? config.evaluationWindowDays,
            evidence: significant.flatMap(\.evidence),
            headline: "Several things have changed for \(pet.name) at once",
            explanation: """
                \(significant.count) separate patterns are outside \(pet.name)'s normal at the \
                same time: \(names.formatted(.list(type: .and))). Individually each is mild; \
                together they are the pattern most worth acting on.
                """,
            recommendation: "Book a vet appointment. Take the behaviour history in this app with you — the day-by-day detail is exactly what a vet will ask for."
        )
    }
}

// MARK: - Copy generation

/// Turns a scored syndrome into carer-facing language.
///
/// Kept beside the detector on purpose: the wording makes claims about the
/// animal's health, and those claims should never drift away from the maths
/// that licenses them.
private enum Copy {

    struct Result {
        var headline: String
        var explanation: String
        var recommendation: String
    }

    static func make(
        kind: FlagKind,
        pet: Pet,
        evidence: [MetricEvidence],
        severity: FlagSeverity
    ) -> Result {

        let detail = evidence.prefix(2).map(\.summary).joined(separator: ", and ")
        let name = pet.name

        switch kind {
        case .appetiteLoss:
            return Result(
                headline: "\(name) is eating less than usual",
                explanation: "Over the last few days: \(detail). Eating less is the most common first sign of change in both cats and dogs.",
                recommendation: severity >= .concern
                    ? "If \(name) has eaten noticeably less for more than 48 hours, call your vet — especially for cats, where short fasts carry real risk."
                    : "Keep offering food as normal and log each meal. If this continues another day, call your vet."
            )

        case .lethargy:
            return Result(
                headline: "\(name) seems flatter than normal",
                explanation: "Over the last few days: \(detail). Lower energy against \(name)'s own usual pattern, not against any breed average.",
                recommendation: severity >= .concern
                    ? "Sustained lethargy warrants a vet call, particularly alongside any change in eating or drinking."
                    : "Watch for another day. Note anything else that has changed — heat, a new routine, a recent vaccination."
            )

        case .sleepDisruption:
            return Result(
                headline: "\(name)'s sleep pattern has shifted",
                explanation: "Over the last few days: \(detail). A shift in either direction can point to pain, stress or a change in the household environment.",
                recommendation: "Check for obvious environmental causes — noise, temperature, a new pet or person. If nothing explains it, mention it at the next vet visit."
            )

        case .hydrationChange:
            return Result(
                headline: "\(name)'s water intake has changed",
                explanation: "Over the last few days: \(detail). Drinking noticeably more or less than usual is a signal worth taking seriously in its own right.",
                recommendation: "A lasting change in how much your pet drinks is worth mentioning to your vet if it holds for several more days."
            )

        case .weightTrend, .eliminationChange, .multiSystem:
            // These three build their own copy at detection time, because their
            // wording depends on numbers this generic path does not receive.
            return Result(
                headline: "\(kind.displayName) for \(name)",
                explanation: detail,
                recommendation: "Review with your vet if this continues."
            )
        }
    }
}
