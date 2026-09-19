import Foundation

/// What a behaviour check says: how likely each everyday state is right now.
///
/// Scope agreed with Dr Yam on 18 Sep 2026:
/// - behaviour only ("possibly hungry"), never a disease or a diagnosis;
/// - photo or sound first, video as a later enhancement;
/// - machine learning that runs on the phone, not a paid generative AI.
///
/// PROTOTYPE: the scores below come from a stand-in that blends the pet's most
/// recent log with a seeded jitter per capture, so the screen, the flow and the
/// wording can be tested now. In FYP2 `analyse` is replaced by a trained
/// image / audio classifier (Li Shen is shortlisting Hugging Face models)
/// converted to Core ML. The input and output types stay the same.
enum BehaviourCheckModel {

    enum Mode: String, CaseIterable, Identifiable {
        case photo = "Photo"
        case sound = "Sound"
        var id: String { rawValue }

        var symbolName: String { self == .photo ? "camera.fill" : "waveform" }
    }

    enum State: String, CaseIterable, Identifiable {
        case hungry, playful, content, wantsAttention, anxious, tired

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .hungry: "Hungry"
            case .playful: "Playful"
            case .content: "Content"
            case .wantsAttention: "Wants attention"
            case .anxious: "Anxious"
            case .tired: "Tired"
            }
        }

        var emoji: String {
            switch self {
            case .hungry: "🍖"
            case .playful: "🎾"
            case .content: "😌"
            case .wantsAttention: "🙋"
            case .anxious: "😟"
            case .tired: "😴"
            }
        }
    }

    struct Likelihood: Identifiable, Hashable {
        let state: State
        let probability: Double
        var id: State { state }
    }

    /// Minimum sound clip before analysis is allowed. Dr Yam's working figure
    /// is 10 seconds; Li Shen is confirming the real minimum from the models.
    static let minimumSoundSeconds = 10

    static func analyse(mode: Mode, pet: Pet, recentLog: BehaviorLog?, seed: UInt64) -> [Likelihood] {
        var generator = SeededGenerator(seed: seed)
        var scores: [State: Double] = [:]
        for state in State.allCases {
            scores[state] = Double.random(in: 0.2...1.0, using: &generator)
        }

        if let log = recentLog {
            if log.appetiteRatio < 0.6 { scores[.hungry, default: 0] += 1.2 }
            if log.energyLevel <= 2 { scores[.tired, default: 0] += 1.0 }
            if log.energyLevel >= 4 { scores[.playful, default: 0] += 1.0 }
            switch log.mood {
            case .restless, .irritable: scores[.anxious, default: 0] += 0.9
            case .clingy: scores[.wantsAttention, default: 0] += 0.9
            case .playful: scores[.playful, default: 0] += 0.6
            case .content: scores[.content, default: 0] += 0.6
            case .withdrawn: scores[.tired, default: 0] += 0.5
            }
        }
        if mode == .sound {
            // Vocalising usually means asking for something.
            scores[.hungry, default: 0] += 0.4
            scores[.wantsAttention, default: 0] += 0.4
        }

        let total = scores.values.reduce(0, +)
        return scores
            .map { Likelihood(state: $0.key, probability: $0.value / total) }
            .sorted { $0.probability > $1.probability }
    }

    /// The one-line summary, worded as a possibility, never a verdict.
    static func headline(for results: [Likelihood], petName: String) -> String {
        guard let top = results.first else { return "No result" }
        let prefix = top.probability >= 0.35 ? "High possibility" : "Possibly"
        return "\(prefix) \(petName) is \(top.state.displayName.lowercased())"
    }
}

/// Small deterministic RNG so a capture's result is reproducible in tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
