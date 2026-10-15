import SwiftUI

public extension View {
    /// Swipe left for the next tab or right for the previous tab, in tab order.
    /// Apply to the omnibox rather than the page, so navigation and scrolling
    /// gestures keep their own touch area. Disable while editing an address.
    /// The pages in a `LiveTabStack` follow the finger, and the swipe settles
    /// on the neighbouring tab or springs back on release. The first and last
    /// tabs do not wrap or create a new tab.
    @ViewBuilder
    func tabSwitchingGesture<Root, Identity>(
        for tabID: UUID,
        in store: TabNavigationStore<Root, Identity>,
        isEnabled: Bool = true
    ) -> some View {
        #if os(visionOS)
        self
        #else
        modifier(TabSwitchingGestureModifier(store: store, tabID: tabID, isEnabled: isEnabled))
        #endif
    }
}

#if !os(visionOS)
/// Reads the store in its own body rather than in whatever builds the bar,
/// which is usually a tab's whole page: the selection a swipe commits would
/// otherwise rebuild it on the frame the pages start to settle.
private struct TabSwitchingGestureModifier<Root: TabRoot, Identity: TabPageIdentity>: ViewModifier {
    let store: TabNavigationStore<Root, Identity>
    let tabID: UUID
    let isEnabled: Bool

    /// How far a drag along the omnibox can reach, which on a bar crowded
    /// with buttons is well short of the page.
    @State private var omniboxWidth: CGFloat = 0

    func body(content: Content) -> some View {
        let canSwipe = isEnabled && tabID == store.selectedTabID
            && !store.isInteractivelyPopping
            && !store.isShowingTabSwitcher && !store.isPageClipActive
        content
            .contentShape(Rectangle())
            .gesture(TabSwitchingPanGesture(
                isEnabled: canSwipe,
                // Rechecked as the pan begins: the tab could have closed, been
                // selected elsewhere, or entered a navigation transition.
                shouldBegin: { [store, tabID, isEnabled] in
                    isEnabled && store.selectedTabID == tabID && store.canBeginTabSwipe
                },
                onChange: { [store] in store.updateTabSwipe(translation: $0) },
                onEnd: { [store, omniboxWidth] in
                    store.endTabSwipe(velocity: $0, omniboxWidth: omniboxWidth)
                },
                onCancel: { [store] in store.cancelTabSwipe() }
            ))
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                omniboxWidth = width
            }
    }
}
#endif

#if !os(visionOS)
/// Rejects vertical motion before recognition, leaving taps and long presses
/// alone until an intentional horizontal pan begins.
private struct TabSwitchingPanGesture: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let shouldBegin: () -> Bool
    let onChange: (CGFloat) -> Void
    let onEnd: (CGFloat) -> Void
    let onCancel: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.name = tabSwitchingPanGestureName
        recognizer.maximumNumberOfTouches = 1
        recognizer.delegate = context.coordinator
        recognizer.isEnabled = isEnabled
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        // Left alone mid-swipe: the selection changes as it settles, and
        // disabling a recognizer cancels it.
        guard !context.coordinator.isTracking else { return }
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let coordinator = context.coordinator
        switch recognizer.state {
        case .began:
            coordinator.isTracking = shouldBegin()
            // The pan is recognised some way into the drag. Measured from
            // there, so the pages pick up the finger rather than jumping
            // that far on the first frame. Only the recogniser's own slop is
            // taken off: a fast flick can be recognised far further in, and
            // that distance belongs to the swipe.
            let translation = horizontalTranslation(of: recognizer)
            coordinator.slop = copysign(min(abs(translation), 12), translation)
            if coordinator.isTracking {
                onChange(0)
            }
        case .changed:
            guard coordinator.isTracking else { return }
            onChange(horizontalTranslation(of: recognizer) - coordinator.slop)
        case .ended:
            guard coordinator.isTracking else { return }
            coordinator.isTracking = false
            // In the window, like the translation: the omnibox moves with
            // its page, so its own coordinates would slide under the finger.
            onEnd(recognizer.velocity(in: nil).x)
        case .cancelled, .failed:
            guard coordinator.isTracking else { return }
            coordinator.isTracking = false
            onCancel()
        default:
            break
        }
    }

    private func horizontalTranslation(of recognizer: UIPanGestureRecognizer) -> CGFloat {
        recognizer.translation(in: nil).x
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isTracking = false
        var slop: CGFloat = 0

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: nil)
            return abs(velocity.x) > abs(velocity.y) * 1.25
        }
    }
}

/// Shared with the navigation gesture delegate so it can yield only to this
/// omnibox gesture, without changing how page scroll views behave.
let tabSwitchingPanGestureName = "EnhancedNavigation.TabSwitchingPan"
#endif
