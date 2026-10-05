import SwiftUI

/// The card's title row, laid over the top of the preview.
struct TabSwitcherCardHeader<Label: View>: View {

    let canClose: Bool
    let closeLabel: String
    /// Whether the snapshot behind the row is light, or nil without one.
    let isBackdropLight: Bool?
    let onClose: () -> Void
    @ViewBuilder let label: () -> Label
    @Environment(\.colorScheme) private var colorScheme

    /// Picked from the snapshot rather than the system appearance: a dark
    /// page in light mode would otherwise put dark glyphs on it. A card
    /// without a snapshot shows the system background, so it follows that.
    private var rowScheme: ColorScheme {
        isBackdropLight.map { $0 ? .light : .dark } ?? colorScheme
    }

    /// White under dark glyphs, black under light ones, so the title stands
    /// off the blurred snapshot.
    private var scrimColor: Color {
        rowScheme == .dark ? .black : .white
    }

    var body: some View {
        HStack(spacing: 6) {
            label()
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .shadow(color: scrimColor.opacity(0.5), radius: 2, y: 1)
            Spacer(minLength: 0)
            if canClose {
                closeButton
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.top, 6)
        .padding(.bottom, 22)
        .background {
            LinearGradient(
                stops: TabSwitcherCardScrim.stops(color: scrimColor),
                startPoint: .bottom,
                endPoint: .top
            )
        }
        .environment(\.colorScheme, rowScheme)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 14, height: 14)
        }
        .glassButtonStyleIfAvailable()
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .accessibilityLabel(closeLabel)
    }
}

private enum TabSwitcherCardScrim {

    static let opacity: Double = 0.55

    /// Eased rather than two-stop: a linear ramp ends in a visible band where
    /// it meets the preview.
    private static let curve: [(location: Double, opacity: Double)] = [
        (0.0, 0.0), (0.018, 0.002), (0.048, 0.008), (0.09, 0.021),
        (0.139, 0.042), (0.198, 0.075), (0.27, 0.126), (0.35, 0.194),
        (0.435, 0.278), (0.53, 0.382), (0.66, 0.541), (0.81, 0.738), (1.0, 1.0)
    ]

    static func stops(color: Color) -> [Gradient.Stop] {
        curve.map { location, stopOpacity in
            Gradient.Stop(color: color.opacity(stopOpacity * opacity), location: location)
        }
    }
}

private extension View {
    @ViewBuilder
    func glassButtonStyleIfAvailable() -> some View {
        #if os(visionOS)
        buttonStyle(.bordered)
        #else
        buttonStyle(.glass)
        #endif
    }
}
