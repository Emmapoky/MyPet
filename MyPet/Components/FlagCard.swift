import SwiftUI

/// The card that presents one behaviour flag.
///
/// The design brief for this card was: a worried owner should be able to read
/// it in ten seconds and know three things — what changed, how sure the app is,
/// and what to do next. Everything else (the raw z-scores, the window
/// arithmetic) is available on expand, but never in the way.
struct FlagCard: View {

    let flag: BehaviorFlag
    let pet: Pet
    var showPetName = true

    var onAcknowledge: (() -> Void)?
    var onDismiss: (() -> Void)?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Text(flag.headline)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if !flag.evidence.isEmpty {
                evidenceRows
            }

            Text(flag.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isExpanded {
                expandedDetail
            }

            recommendation

            controls
        }
        .petCard(accent: flag.severity.color)
        .animation(.snappy(duration: 0.22), value: isExpanded)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: flag.kind.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(flag.severity.color)

            VStack(alignment: .leading, spacing: 1) {
                Text(flag.kind.displayName)
                    .font(.subheadline.weight(.semibold))
                if showPetName {
                    Text(pet.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if flag.status == .acknowledged {
                Label("Acknowledged", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Acknowledged")
            }

            SeverityBadge(severity: flag.severity)
        }
    }

    // MARK: Evidence

    private var evidenceRows: some View {
        VStack(spacing: 6) {
            ForEach(flag.evidence.prefix(3)) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.metric.symbolName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Text(item.metric.displayName)
                        .font(.caption)

                    Spacer()

                    Text(item.metric.format(item.observed))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()

                    Image(systemName: item.directionSymbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(flag.severity.color)

                    Text("usually \(item.metric.format(item.expected))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item.summary)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Expanded detail

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            ConfidenceBar(confidence: flag.confidence)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                GridRow {
                    Text("Pattern held").font(.caption2).foregroundStyle(.secondary)
                    Text("\(flag.persistenceDays) of \(flag.windowDays) days")
                        .font(.caption2.weight(.medium)).monospacedDigit()
                }
                GridRow {
                    Text("Anomaly score").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.2f of 1.00", flag.score))
                        .font(.caption2.weight(.medium)).monospacedDigit()
                }
                GridRow {
                    Text("Detected").font(.caption2).foregroundStyle(.secondary)
                    Text(flag.detectedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2.weight(.medium))
                }
            }

            ForEach(flag.evidence) { item in
                if let percent = item.percentChange {
                    Text("\(item.metric.displayName): \(String(format: "%+.0f%%", percent)) versus this pet's own baseline (robust z \(String(format: "%+.1f", item.z)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Scored against \(pet.name)'s own recent history, not against a breed average. MyPet flags changes in routine; it does not diagnose.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Recommendation

    private var recommendation: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(Theme.watch)
            Text(flag.recommendation)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.watch.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                isExpanded.toggle()
            } label: {
                Label(isExpanded ? "Less detail" : "Why this flag?",
                      systemImage: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            if flag.status == .active, let onAcknowledge {
                Button("Noted", action: onAcknowledge)
                    .font(.caption.weight(.medium))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if let onDismiss {
                Button("Expected", action: onDismiss)
                    .font(.caption.weight(.medium))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}
