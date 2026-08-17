import SwiftUI

/// Colour, spacing and type tokens.
///
/// Every colour is defined for both appearances. A care app gets opened at 2am
/// by someone worried about their animal, and a screen that blasts white light
/// in a dark bedroom is a real usability failure, not a nicety.
enum Theme {

    // MARK: Severity palette

    /// Deliberately not the default system red/orange/yellow. Those read as
    /// "error" — a destroyed file, a failed payment. These are calmer, because
    /// the message is "look at this", not "something broke".
    static let info = Color(light: .init(red: 0.35, green: 0.47, blue: 0.62),
                            dark: .init(red: 0.55, green: 0.68, blue: 0.85))

    static let watch = Color(light: .init(red: 0.72, green: 0.55, blue: 0.16),
                             dark: .init(red: 0.94, green: 0.78, blue: 0.38))

    static let concern = Color(light: .init(red: 0.80, green: 0.42, blue: 0.16),
                               dark: .init(red: 0.98, green: 0.63, blue: 0.36))

    static let urgent = Color(light: .init(red: 0.75, green: 0.24, blue: 0.24),
                              dark: .init(red: 0.96, green: 0.47, blue: 0.47))

    static let positive = Color(light: .init(red: 0.20, green: 0.53, blue: 0.38),
                                dark: .init(red: 0.42, green: 0.78, blue: 0.60))

    // MARK: Per-pet accents

    /// Six accents, all legible against both backgrounds, all distinguishable
    /// under the common forms of colour blindness — a household with four pets
    /// needs the dashboard to be scannable by colour.
    static let petAccents: [Color] = [
        Color(light: .init(red: 0.18, green: 0.53, blue: 0.48),
              dark: .init(red: 0.37, green: 0.75, blue: 0.68)),
        Color(light: .init(red: 0.55, green: 0.33, blue: 0.64),
              dark: .init(red: 0.74, green: 0.56, blue: 0.86)),
        Color(light: .init(red: 0.78, green: 0.45, blue: 0.28),
              dark: .init(red: 0.94, green: 0.66, blue: 0.47)),
        Color(light: .init(red: 0.24, green: 0.45, blue: 0.72),
              dark: .init(red: 0.49, green: 0.68, blue: 0.93)),
        Color(light: .init(red: 0.62, green: 0.31, blue: 0.42),
              dark: .init(red: 0.86, green: 0.53, blue: 0.65)),
        Color(light: .init(red: 0.36, green: 0.52, blue: 0.24),
              dark: .init(red: 0.60, green: 0.78, blue: 0.44))
    ]

    // MARK: Surfaces

    static let background = Color(light: .init(red: 0.97, green: 0.97, blue: 0.96),
                                  dark: .init(red: 0.07, green: 0.07, blue: 0.08))

    static let card = Color(light: .init(red: 1.0, green: 1.0, blue: 1.0),
                            dark: .init(red: 0.13, green: 0.13, blue: 0.15))

    static let cardBorder = Color(light: .init(red: 0.89, green: 0.89, blue: 0.87),
                                  dark: .init(red: 0.22, green: 0.22, blue: 0.25))

    // MARK: Metrics

    /// Layout constants, kept in one place so spacing stays consistent across
    /// a dozen screens without anyone having to remember the numbers.
    static let cardRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16
    static let stackSpacing: CGFloat = 14
    static let sectionSpacing: CGFloat = 22

    /// Apple's minimum comfortable touch target. Anything tappable meets it.
    static let minimumTapTarget: CGFloat = 44
}

// MARK: - Appearance-aware colour

extension Color {
    /// Builds a colour that resolves differently in light and dark mode.
    init(light: RGB, dark: RGB) {
        self.init(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        })
    }

    struct RGB {
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat
    }
}

// MARK: - Card styling

extension View {
    /// The standard card treatment used across every screen.
    func petCard(padding: CGFloat = Theme.cardPadding) -> some View {
        self
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
    }

    /// Card with a coloured leading edge — used to tie a card to one pet or to
    /// one severity level without tinting the whole surface.
    func petCard(accent: Color, padding: CGFloat = Theme.cardPadding) -> some View {
        self
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(alignment: .leading) {
                accent
                    .frame(width: 4)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: Theme.cardRadius,
                        bottomLeadingRadius: Theme.cardRadius,
                        style: .continuous
                    ))
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
    }
}
