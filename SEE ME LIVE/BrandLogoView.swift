import SwiftUI

/// Calendar artwork shared with the app icon and launch branding.
struct BrandLogoView: View {
    var size: CGFloat = 120

    var body: some View {
        Image("SplashIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("My Gig Calendar")
    }
}

#Preview {
    HStack(spacing: 24) {
        BrandLogoView(size: 120)
        BrandLogoView(size: 60)
    }
    .padding(40)
}
