import SwiftUI

// MARK: - SeverityBadge

/// Small pill showing a flag's severity.
///
/// Colour is never the only channel — every badge also carries a distinct SF
/// Symbol and the severity word — so the state survives colour blindness and a
/// greyscale screenshot.
struct SeverityBadge: View {
    let severity: FlagSeverity
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: severity.symbolName)
                .font(.caption2.weight(.bold))
            if !compact {
                Text(severity.displayName)
                    .font(.caption2.weight(.semibold))
            }
        }
        .foregroundStyle(severity.color)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, 4)
        .background(severity.color.opacity(0.14), in: Capsule())
        .accessibilityLabel("\(severity.displayName) severity")
    }
}

// MARK: - PetAvatar

struct PetAvatar: View {
    let pet: Pet
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(pet.accent.opacity(0.18))
            Image(systemName: pet.symbolName)
                .font(.system(size: size * 0.45))
                .foregroundStyle(pet.accent)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - StatPill

/// One labelled number. Used in rows across the dashboard and pet detail.
struct StatPill: View {
    let symbol: String
    let value: String
    let caption: String
    var tint: Color = .secondary

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption): \(value)")
    }
}

// MARK: - Sparkline

/// Tiny trend line with the baseline's normal band behind it.
///
/// Drawn by hand rather than with Swift Charts: at this size Charts' axes and
/// padding cost more space than the data, and the band needs to sit visually
/// *behind* the line rather than as a separate series.
struct Sparkline: View {
    let values: [Double]
    /// Baseline centre and spread, used to draw the shaded normal band.
    var band: (centre: Double, spread: Double)?
    var tint: Color = .accentColor
    var height: CGFloat = 34

    var body: some View {
        GeometryReader { geometry in
            let bounds = valueBounds
            let width = geometry.size.width
            let h = geometry.size.height

            ZStack(alignment: .topLeading) {
                if let band, bounds.upper > bounds.lower {
                    let top = yPosition(band.centre + band.spread, bounds: bounds, height: h)
                    let bottom = yPosition(band.centre - band.spread, bounds: bounds, height: h)
                    Rectangle()
                        .fill(tint.opacity(0.12))
                        .frame(width: width, height: max(bottom - top, 2))
                        .offset(y: top)
                }

                if values.count > 1 {
                    linePath(width: width, height: h, bounds: bounds)
                        .stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private var valueBounds: (lower: Double, upper: Double) {
        var candidates = values
        if let band {
            candidates.append(band.centre + band.spread)
            candidates.append(band.centre - band.spread)
        }
        guard let minimum = candidates.min(), let maximum = candidates.max() else { return (0, 1) }
        // Pad by 8% so the line never sits flush against the edge.
        let padding = max((maximum - minimum) * 0.08, 0.001)
        return (minimum - padding, maximum + padding)
    }

    private func yPosition(_ value: Double, bounds: (lower: Double, upper: Double), height: CGFloat) -> CGFloat {
        let span = bounds.upper - bounds.lower
        guard span > 0 else { return height / 2 }
        let fraction = (value - bounds.lower) / span
        return height * (1 - fraction)
    }

    private func linePath(width: CGFloat, height: CGFloat, bounds: (lower: Double, upper: Double)) -> Path {
        Path { path in
            let step = width / CGFloat(max(values.count - 1, 1))
            for (index, value) in values.enumerated() {
                let point = CGPoint(x: CGFloat(index) * step, y: yPosition(value, bounds: bounds, height: height))
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
        }
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 38))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
}

// MARK: - SectionHeader

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var trailing: AnyView?

    init(_ title: String, subtitle: String? = nil, trailing: AnyView? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let trailing { trailing }
        }
    }
}

// MARK: - ConfidenceBar

/// Shows how much history backs a flag. Deliberately prominent: a claim about
/// someone's animal should always arrive with how sure the model is.
struct ConfidenceBar: View {
    let confidence: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Model confidence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int((confidence * 100).rounded()))%")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(confidenceColor)
                        .frame(width: geometry.size.width * min(max(confidence, 0), 1))
                }
            }
            .frame(height: 5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Model confidence \(Int((confidence * 100).rounded())) percent")
    }

    private var confidenceColor: Color {
        switch confidence {
        case 0.7...: Theme.positive
        case 0.4..<0.7: Theme.watch
        default: Theme.concern
        }
    }
}
