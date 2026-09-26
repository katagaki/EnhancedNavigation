import SwiftUI

/// Where the system's `.bottomBar` puts its items on an iPhone with a home
/// indicator, measured against iOS 27, for a custom bar that has to sit
/// exactly where the system one would.
public enum TabBottomBarMetrics {
    /// The height of a bar item's glass, and the width of a single-symbol one.
    public static let itemHeight: CGFloat = 48

    /// Between neighbouring items' glass, where the system bar's flexible
    /// spacers settle around a back button, an address field and a tabs
    /// button.
    public static let itemSpacing: CGFloat = 14

    /// From the screen's edges to the outermost items' glass. The system bar
    /// only gives this up when its items overflow.
    public static let horizontalInset: CGFloat = 28

    /// How far the items' glass hangs below the bottom safe area, into the
    /// home indicator's band.
    public static let safeAreaOverhang: CGFloat = 6
}

public extension View {
    /// A custom bar in place of the system's `.bottomBar`, laid out to its
    /// metrics. Hung off the view as a safe area bar rather than an inset or
    /// an overlay, so scroll views beneath it still run the system's soft
    /// edge effect: the variable blur and the dimming gradient that keep the
    /// bar legible over busy content.
    ///
    /// Applied outside a `NavigationStack`, one bar stays put across pushes
    /// and pops while every page underneath still gets the edge effect.
    func tabBottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        modifier(TabBottomBarModifier(bar: bar()))
    }
}

private struct TabBottomBarModifier<Bar: View>: ViewModifier {

    let bar: Bar

    /// The bottom inset the view itself is laid out with. A tab page runs
    /// edge to edge, so this is usually zero while the window's is not.
    @State private var localBottomInset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .safeAreaBar(edge: .bottom, spacing: 0) {
                bar
                    .frame(maxWidth: .infinity, minHeight: TabBottomBarMetrics.itemHeight)
                    .padding(.horizontal, TabBottomBarMetrics.horizontalInset)
                    .padding(.bottom, bottomPadding)
            }
            .softBottomScrollEdge()
            // Measured outside the bar, or the bar's own height is counted.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.safeAreaInsets.bottom
            } action: { inset in
                localBottomInset = inset
            }
    }

    /// Whatever of the window's inset the view does not already see, so the
    /// bar clears the home indicator the same way whether or not the page
    /// ignores the safe area.
    private var bottomPadding: CGFloat {
        let windowInset = DisplayMetrics.safeAreaInsets.bottom
        return max(windowInset - localBottomInset, 0) - TabBottomBarMetrics.safeAreaOverhang
    }
}

private extension View {
    /// visionOS has no scroll edge effects to style.
    @ViewBuilder
    func softBottomScrollEdge() -> some View {
        #if os(visionOS)
        self
        #else
        scrollEdgeEffectStyle(.soft, for: .bottom)
        #endif
    }
}
