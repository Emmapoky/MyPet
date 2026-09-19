import SwiftUI
import UIKit

/// The MyPet logo.
///
/// Drop the logo from the slides into `Assets.xcassets/AppLogo` and it shows up
/// everywhere this view is used. Until then a paw on the brand gradient stands
/// in, so the layout never has a hole in it.
struct BrandLogo: View {
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let image = UIImage(named: "AppLogo") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    Circle().fill(Theme.heroGradient)
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: size * 0.46, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .accessibilityLabel("MyPet")
    }
}
