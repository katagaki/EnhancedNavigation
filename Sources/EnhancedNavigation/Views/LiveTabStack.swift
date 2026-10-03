import SwiftUI

/// Keeps the recent tabs mounted so switching back is instant, and hides the
/// ones that are not on screen rather than tearing their stacks down.
public struct LiveTabStack<Root: TabRoot, Identity: TabPageIdentity, Content: View>: View {

    private let store: TabNavigationStore<Root, Identity>
    private let content: (NavigationTab<Root, Identity>) -> Content

    /// `content` should read as little of the store as it can: anything it
    /// reads re-runs it, in every mounted tab.
    public init(
        store: TabNavigationStore<Root, Identity>,
        @ViewBuilder content: @escaping (NavigationTab<Root, Identity>) -> Content
    ) {
        self.store = store
        self.content = content
    }

    public var body: some View {
        let swipeNeighbourID = store.tabSwipeNeighbour?.tabID
        ZStack {
            ForEach(store.tabs) { tab in
                // A swipe mounts the tab beside the selected one, so the page
                // it uncovers is the real one and stays put once selected.
                if store.isLive(tab.id) || tab.id == swipeNeighbourID {
                    let isSelected = tab.id == store.selectedTabID
                    content(tab)
                        .modifier(TabSwipePlacement(store: store, tabID: tab.id))
                        .opacity(isSelected || tab.id == swipeNeighbourID ? 1 : 0)
                        .allowsHitTesting(isSelected)
                        // A zero-opacity tab still publishes its accessibility
                        // elements; collapsing the subtree takes them out.
                        .accessibilityElement(children: isSelected ? .contain : .ignore)
                        .accessibilityHidden(!isSelected)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            store.tabSwipePageWidth = width
        }
    }
}

/// Reads the swipe's translation on its own, so a frame of the swipe moves
/// the pages without re-running every mounted tab's content.
private struct TabSwipePlacement<Root: TabRoot, Identity: TabPageIdentity>: ViewModifier {

    let store: TabNavigationStore<Root, Identity>
    let tabID: UUID

    func body(content: Content) -> some View {
        content.offset(x: offset)
    }

    private var offset: CGFloat {
        // Checked before the translation is read, so the tabs left out of
        // the swipe are not invalidated on every frame of it.
        if tabID == store.selectedTabID {
            return store.tabSwipeTranslation
        }
        guard let neighbour = store.tabSwipeNeighbour, neighbour.tabID == tabID else { return 0 }
        let width = store.tabSwipePageWidth
        return store.tabSwipeTranslation + (neighbour.isNext ? width : -width)
    }
}
