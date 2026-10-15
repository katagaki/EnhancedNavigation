import SwiftUI

public extension View {
    /// Runs `action` with the old and new tab whenever the selection changes.
    ///
    /// Use this rather than `onChange(of: store.selectedTabID)` on a view
    /// that builds the tab stack: `onChange` reads its value in the body it
    /// is applied in, so every selection, including the one a tab swipe
    /// commits as it starts to settle, would re-run that body and every
    /// mounted tab's content with it. Here the selection is read in a
    /// modifier of its own.
    func onTabSelectionChange<Root, Identity>(
        in store: TabNavigationStore<Root, Identity>,
        perform action: @escaping (_ oldTabID: UUID, _ newTabID: UUID) -> Void
    ) -> some View {
        modifier(TabSelectionChangeModifier(store: store, action: action))
    }
}

private struct TabSelectionChangeModifier<Root: TabRoot, Identity: TabPageIdentity>: ViewModifier {

    let store: TabNavigationStore<Root, Identity>
    let action: (UUID, UUID) -> Void

    func body(content: Content) -> some View {
        content.onChange(of: store.selectedTabID) { oldTabID, newTabID in
            action(oldTabID, newTabID)
        }
    }
}

/// Builds `content` in a body of its own, so the store reads it makes
/// invalidate it alone rather than the view that hands it over: a modifier's
/// content closure otherwise runs, and is observed, in the caller's body.
struct ObservationBoundary<Content: View>: View {

    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
    }
}
