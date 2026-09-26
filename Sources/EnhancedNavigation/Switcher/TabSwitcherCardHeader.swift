import SwiftUI

/// The card's title row, laid over the top of the preview.
struct TabSwitcherCardHeader<Label: View>: View {

    let canClose: Bool
    let closeLabel: String
    let onClose: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        HStack(spacing: 6) {
            label()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
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
            LinearGradient(stops: TabSwitcherCardScrim.stops, startPoint: .bottom, endPoint: .top)
        }
        // Light glyphs and glass whatever the system appearance: the row
        // always sits on the dark end of the gradient.
        .environment(\.colorScheme, .dark)
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

    static let opacity: Double = 0.4

    /// Eased rather than two-stop: a linear ramp ends in a visible band where
    /// it meets the preview.
    static let stops: [Gradient.Stop] = [
        (0.0, 0.0), (0.018, 0.002), (0.048, 0.008), (0.09, 0.021),
        (0.139, 0.042), (0.198, 0.075), (0.27, 0.126), (0.35, 0.194),
        (0.435, 0.278), (0.53, 0.382), (0.66, 0.541), (0.81, 0.738), (1.0, 1.0)
    ].map { location, stopOpacity in
        Gradient.Stop(color: .black.opacity(stopOpacity * opacity), location: location)
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
