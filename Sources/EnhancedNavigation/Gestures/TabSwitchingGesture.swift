import SwiftUI

public extension View {
    /// Swipe left for the next tab or right for the previous tab, in tab order.
    /// Apply to the omnibox rather than the page, so navigation and scrolling
    /// gestures keep their own touch area. Disable while editing an address.
    /// Selection changes on release; a short or cancelled drag does nothing.
    /// The first and last tabs do not wrap or create a new tab.
    @ViewBuilder
    func tabSwitchingGesture<Root, Identity>(
        for tabID: UUID,
        in store: TabNavigationStore<Root, Identity>,
        isEnabled: Bool = true
    ) -> some View {
        #if os(visionOS)
        self
        #else
        let canSwipe = isEnabled && tabID == store.selectedTabID
            && !store.isInteractivelyPopping
            && !store.isShowingTabSwitcher && !store.isPageClipActive
        self
            .contentShape(Rectangle())
            .gesture(TabSwitchingPanGesture(isEnabled: canSwipe) { translation in
                // Recheck on release: the tab could have closed, been selected
                // elsewhere, or entered a navigation transition during the pan.
                guard isEnabled, store.selectedTabID == tabID,
                      !store.isInteractivelyPopping, !store.isShowingTabSwitcher,
                      !store.isPageClipActive,
                      let index = store.tabs.firstIndex(where: { $0.id == tabID })
                else { return }
                let destination = index + (translation < 0 ? 1 : -1)
                guard store.tabs.indices.contains(destination) else { return }
                store.select(store.tabs[destination].id)
            })
        #endif
    }
}

#if !os(visionOS)
/// Rejects vertical motion before recognition, leaving taps and long presses
/// alone until an intentional horizontal pan begins.
private struct TabSwitchingPanGesture: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let onSwipe: (CGFloat) -> Void

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
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard isEnabled, recognizer.state == .ended else { return }
        let translation = recognizer.translation(in: recognizer.view)
        guard abs(translation.x) >= 36,
              abs(translation.x) > abs(translation.y) * 1.25 else { return }
        onSwipe(translation.x)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.25
        }
    }
}

/// Shared with the navigation gesture delegate so it can yield only to this
/// omnibox gesture, without changing how page scroll views behave.
let tabSwitchingPanGestureName = "EnhancedNavigation.TabSwitchingPan"
#endif
