import SwiftUI

/// FR04: a summary for the vet, covering a date range the carer picks,
/// readable without the app. It is shared as plain text, so it opens in any
/// email, message or notes app on any phone.
struct VetExportView: View {

    @Environment(MyPetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let pet: Pet

    @State private var from = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var to = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("From", selection: $from, in: ...to, displayedComponents: .date)
                    DatePicker("To", selection: $to, in: from...Date.now, displayedComponents: .date)
                    HStack(spacing: 8) {
                        ForEach([7, 30, 90], id: \.self) { days in
                            Button("\(days) days") {
                                to = .now
                                from = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
                            }
                            .buttonStyle(.bordered)
                            .tint(pet.accent)
                        }
                    }
                } header: {
                    Text("Date range")
                }

                Section {
                    Text(summary)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                } header: {
                    Text("Preview")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.pageGradient.ignoresSafeArea())
            .navigationTitle("Vet summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: summary, subject: Text("\(pet.name): MyPet summary")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var summary: String {
        VetSummary.make(
            pet: pet,
            logs: store.logs(for: pet.id),
            flags: store.flags(for: pet.id, includeResolved: true),
            records: store.records(for: pet.id),
            from: from,
            to: to
        )
    }
}

/// Builds the plain-text vet summary. Kept separate from the view so it can
/// be unit-tested.
enum VetSummary {

    static func make(
        pet: Pet,
        logs: [BehaviorLog],
        flags: [BehaviorFlag],
        records: [HealthRecord],
        from: Date,
        to: Date,
        calendar: Calendar = .current
    ) -> String {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        let dayCount = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        let inRange = logs.filter { $0.day >= start && $0.day <= end }.sorted { $0.day < $1.day }
        let date: (Date) -> String = { $0.formatted(date: .abbreviated, time: .omitted) }

        var lines: [String] = []
        lines.append("MyPet summary for \(pet.name)")
        lines.append("\(pet.species.displayName)\(pet.breed.isEmpty ? "" : ", \(pet.breed)") · \(pet.sex.displayName) · \(pet.ageDescription)\(pet.isNeutered ? " · neutered/spayed" : "")")
        if pet.weightKg > 0 { lines.append("Latest weight: \(String(format: "%.2f", pet.weightKg)) kg") }
        if !pet.allergies.isEmpty { lines.append("Allergies / conditions: \(pet.allergies)") }
        if !pet.microchipID.isEmpty { lines.append("Microchip: \(pet.microchipID)") }
        lines.append("Period: \(date(start)) to \(date(end)) · \(inRange.count) of \(dayCount) days logged")
        lines.append("")

        lines.append("DAILY LOG")
        if inRange.isEmpty {
            lines.append("No entries in this period.")
        }
        for log in inRange {
            var parts = [
                date(log.day),
                "ate \(Int((log.appetiteRatio * 100).rounded()))%",
                "energy \(log.energyLevel)/5",
                log.mood.displayName.lowercased(),
                log.eliminationNormal ? "toileting normal" : "toileting NOT normal"
            ]
            if let weight = log.weightKg { parts.append(String(format: "%.2f kg", weight)) }
            lines.append("• " + parts.joined(separator: " · "))
            if !log.notes.isEmpty { lines.append("   Note: \(log.notes.replacingOccurrences(of: "\n", with: " / "))") }
        }
        lines.append("")

        let flagsInRange = flags.filter { $0.detectedAt >= start && calendar.startOfDay(for: $0.detectedAt) <= end }
        lines.append("CHANGES MYPET NOTICED")
        if flagsInRange.isEmpty { lines.append("None in this period.") }
        for flag in flagsInRange.sorted(by: { $0.detectedAt < $1.detectedAt }) {
            lines.append("• \(date(flag.detectedAt)) · \(flag.severity.displayName) · \(flag.headline)")
            lines.append("   \(flag.explanation)")
        }
        lines.append("")

        let recordsInRange = records.filter { $0.date >= start && calendar.startOfDay(for: $0.date) <= end }
        lines.append("HEALTH RECORDS")
        if recordsInRange.isEmpty { lines.append("None in this period.") }
        for record in recordsInRange.sorted(by: { $0.date < $1.date }) {
            lines.append("• \(date(record.date)) · \(record.kind.displayName) · \(record.title)")
        }
        lines.append("")
        lines.append("Recorded by the owner in MyPet. MyPet points out changes against this pet's own usual routine. It does not diagnose.")
        return lines.joined(separator: "\n")
    }
}
