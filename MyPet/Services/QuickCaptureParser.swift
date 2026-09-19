import Foundation

/// Turns one plain sentence into a structured daily log.
///
/// This is Lingsha's idea from Meeting 3: say or type what happened
/// ("Biscuit ate half his dinner, a bit sleepy, pooped normally") and let the
/// app fill in the log, which the carer then confirms. Her first version sent
/// the sentence to an external AI through an iOS Shortcut and saved it to the
/// Calendar. Dr Yam (18 Sep) kept the idea but asked for it to live inside the
/// app with no ChatGPT account and no token cost, so this runs entirely on the
/// phone with plain keyword rules. It is deliberately forgiving: anything it
/// does not recognise is left for the carer to fill in.
struct QuickCaptureParser {

    struct Result: Equatable {
        var petID: UUID?
        var eatenFraction: Double?
        var energyLevel: Int?
        var mood: Mood?
        var eliminationNormal: Bool?
        var weightKg: Double?

        /// Human-readable chips for what was understood, in the order found.
        var understood: [String] = []

        var isEmpty: Bool {
            eatenFraction == nil && energyLevel == nil && mood == nil
                && eliminationNormal == nil && weightKg == nil
        }
    }

    let pets: [Pet]

    func parse(_ text: String) -> Result {
        let lower = " " + text.lowercased() + " "
        var result = Result()

        // Pet: by name, or the only pet in the household.
        if let pet = pets.first(where: { lower.contains(" \($0.name.lowercased())") }) {
            result.petID = pet.id
            result.understood.append("🐾 \(pet.name)")
        } else if pets.count == 1 {
            result.petID = pets[0].id
        }

        // Appetite. Negatives first, so "didn't eat all" is not read as "all".
        let appetiteRules: [([String], Double, String)] = [
            (["didn't eat", "did not eat", "didnt eat", "refused", "no appetite", "skipped", "won't eat", "not eating"], 0, "Ate nothing"),
            (["ate a little", "barely", "picked at", "a few bites", "ate a bit", "only a bit", "little food"], 0.25, "Ate a little"),
            (["half"], 0.5, "Ate half"),
            (["most of", "ate most", "mostly"], 0.75, "Ate most"),
            (["ate all", "finished", "cleaned the bowl", "ate everything", "ate well", "ate it all", "full meal", "ate normally"], 1, "Ate everything")
        ]
        for (phrases, fraction, label) in appetiteRules where phrases.contains(where: { lower.contains($0) }) {
            result.eatenFraction = fraction
            result.understood.append("🍽️ \(label)")
            break
        }

        // Energy.
        let energyRules: [([String], Int, String)] = [
            (["exhausted", "very tired", "no energy", "lethargic", "flat"], 1, "Very low energy"),
            (["tired", "sleepy", "slow", "low energy", "quiet", "sluggish"], 2, "Low energy"),
            (["zoomies", "hyper", "bouncy", "very energetic", "crazy"], 5, "Lots of energy"),
            (["energetic", "active", "lively", "playful"], 4, "Good energy")
        ]
        for (phrases, level, label) in energyRules where phrases.contains(where: { lower.contains($0) }) {
            result.energyLevel = level
            result.understood.append("⚡ \(label)")
            break
        }

        // Mood.
        let moodRules: [([String], Mood)] = [
            (["hiding", "withdrawn", "avoiding", "not interested"], .withdrawn),
            (["pacing", "restless", "anxious", "can't settle", "whining"], .restless),
            (["grumpy", "irritable", "hissing", "growling", "snappy", "angry"], .irritable),
            (["clingy", "following me", "needy"], .clingy),
            (["playful", "playing", "zoomies"], .playful),
            (["calm", "content", "happy", "relaxed", "settled"], .content)
        ]
        for (phrases, mood) in moodRules where phrases.contains(where: { lower.contains($0) }) {
            result.mood = mood
            result.understood.append("\(mood.emoji) \(mood.displayName)")
            break
        }

        // Toileting.
        let abnormal = ["vomit", "threw up", "throw up", "sick on", "diarrh", "loose stool", "runny", "constipat",
                        "no poop", "hasn't pooped", "accident", "blood", "straining"]
        let normal = ["pooped", "poop normal", "normal poop", "toilet normal", "toileting normal", "peed", "wee'd", "litter normal"]
        if abnormal.contains(where: { lower.contains($0) }) {
            result.eliminationNormal = false
            result.understood.append("⚠️ Toileting not normal")
        } else if normal.contains(where: { lower.contains($0) }) {
            result.eliminationNormal = true
            result.understood.append("👍 Toileting normal")
        }

        // Weight, e.g. "4.2kg" or "4.2 kg".
        if let match = lower.range(of: #"(\d+(\.\d+)?)\s?kg"#, options: .regularExpression) {
            let number = lower[match].filter { "0123456789.".contains($0) }
            if let kg = Double(number), kg > 0, kg < 150 {
                result.weightKg = kg
                result.understood.append("⚖️ \(String(format: "%.1f", kg)) kg")
            }
        }

        return result
    }

    /// Applies a parse result on top of a draft log. The original sentence is
    /// kept in the notes, so the carer and the vet can always see what was said.
    static func apply(_ result: Result, text: String, to draft: BehaviorLog) -> BehaviorLog {
        var log = draft
        if let fraction = result.eatenFraction {
            log.mealsEaten = Double(log.mealsOffered) * fraction
        }
        if let energy = result.energyLevel { log.energyLevel = energy }
        if let mood = result.mood { log.mood = mood }
        if let normal = result.eliminationNormal { log.eliminationNormal = normal }
        if let weight = result.weightKg { log.weightKg = weight }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let line = "Quick capture: \"\(trimmed)\""
            log.notes = log.notes.isEmpty ? line : log.notes + "\n" + line
        }
        return log
    }
}
