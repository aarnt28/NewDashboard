import SwiftUI

/// Centralized VIP Clouds branding helpers.
enum VIPTheme {
    /// Primary gradient drawn from the VIP Clouds logo colors.
    static let primaryGradient = LinearGradient(
        colors: [.vipBlue, .vipGreen],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Soft background gradient to give light depth to screens.
    static let backgroundGradient = LinearGradient(
        colors: [Color.vipBlue.opacity(0.15), Color.vipGreen.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// A secondary gradient for cards and pills that need a little more pop.
    static let cardGradient = LinearGradient(
        colors: [Color.vipBlue.opacity(0.85), Color.vipGreen.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// A subtle surface color that works on top of the gradient background.
    static let surface = Color.white.opacity(0.85)
}

extension Color {
    /// Vibrant blue pulled from the VIP Clouds logotype.
    static let vipBlue = Color(red: 0.0, green: 0.47, blue: 0.78)

    /// Deepened blue used for hover/pressed states.
    static let vipBlueDeep = Color(red: 0.0, green: 0.32, blue: 0.58)

    /// Fresh green matching the "Clouds" portion of the logo.
    static let vipGreen = Color(red: 0.22, green: 0.71, blue: 0.29)

    /// Darker green for pressed states.
    static let vipGreenDeep = Color(red: 0.18, green: 0.55, blue: 0.24)
}

extension View {
    /// Applies the VIP background gradient behind a view and fills the safe area.
    func vipScreenBackground() -> some View {
        background(
            ZStack {
                Color.white.opacity(0.4)
                VIPTheme.backgroundGradient
            }
            .ignoresSafeArea()
        )
    }

    /// Styles a view as a card that sits on top of the VIP surface.
    func vipCardStyle() -> some View {
        self
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(VIPTheme.surface)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(VIPTheme.backgroundGradient)
                            .blur(radius: 30)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(VIPTheme.primaryGradient, lineWidth: 1)
            )
            .shadow(color: Color.vipBlue.opacity(0.12), radius: 10, x: 0, y: 8)
    }
}

/// Gradient-filled pill used for status badges.
struct VIPGradientPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(VIPTheme.cardGradient)
            )
            .foregroundStyle(Color.white)
    }
}

/// Custom button style that renders a full-width VIP gradient action.
struct VIPProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                VIPTheme.primaryGradient
                    .cornerRadius(16)
                    .shadow(color: Color.vipBlue.opacity(configuration.isPressed ? 0.0 : 0.2), radius: 12, x: 0, y: 10)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
