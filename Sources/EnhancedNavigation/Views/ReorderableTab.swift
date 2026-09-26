import SwiftUI
import UniformTypeIdentifiers

public extension View {
    /// Lets tabs be dragged around one another to reorder them. The others
    /// make way as the drag passes over them, and the dragged tab's own place
    /// shows a placeholder for where it will land.
    func reorderableTab<Root, Identity>(
        id tabID: UUID,
        in store: TabNavigationStore<Root, Identity>,
        animation: Animation = .smooth
    ) -> some View {
        modifier(ReorderableTabModifier(tabID: tabID, store: store, animation: animation))
    }
}

extension View {
    /// Ends a reorder dropped between tabs rather than on one, which would
    /// otherwise leave the placeholder standing.
    func endsTabReordering<Root, Identity>(
        in store: TabNavigationStore<Root, Identity>,
        animation: Animation = .smooth
    ) -> some View {
        onDrop(of: [.plainText], delegate: TabReorderEndDropDelegate(store: store, animation: animation))
    }
}

extension TabNavigationStore {
    func endReordering() {
        draggedTabID = nil
        reorderingTabID = nil
    }
}

/// A modifier rather than inline in the extension, so only the card that
/// changes redraws when the placeholder moves, not the whole grid.
private struct ReorderableTabModifier<Root: TabRoot, Identity: TabPageIdentity>: ViewModifier {

    let tabID: UUID
    let store: TabNavigationStore<Root, Identity>
    let animation: Animation

    private var isPlaceholder: Bool {
        store.reorderingTabID == tabID
    }

    func body(content: Content) -> some View {
        content
            .opacity(isPlaceholder ? 0 : 1)
            .overlay {
                if isPlaceholder {
                    RoundedRectangle(cornerRadius: TabSwitcherCardMetrics.cornerRadius, style: .continuous)
                        .fill(.fill.tertiary)
                        .transition(.opacity)
                }
            }
            .onDrag {
                store.draggedTabID = tabID
                return NSItemProvider(object: tabID.uuidString as NSString)
            }
            .onDrop(
                of: [.plainText],
                delegate: TabReorderDropDelegate(tabID: tabID, store: store, animation: animation)
            )
            .modifier(TabReorderCancellationObserver(store: store, animation: animation))
    }
}

private struct TabReorderDropDelegate<Root: TabRoot, Identity: TabPageIdentity>: DropDelegate {

    let tabID: UUID
    let store: TabNavigationStore<Root, Identity>
    let animation: Animation

    /// Only drags that started on a tab: anything else dropped here has no
    /// place in the grid.
    func validateDrop(info: DropInfo) -> Bool {
        store.draggedTabID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedTabID = store.draggedTabID,
              store.tabs.contains(where: { $0.id == draggedTabID }) else { return }
        withAnimation(animation) {
            store.reorderingTabID = draggedTabID
            store.moveTab(draggedTabID, to: tabID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    /// The tab is already where it lands; all that is left is to put it back.
    func performDrop(info: DropInfo) -> Bool {
        withAnimation(animation) {
            store.endReordering()
        }
        return true
    }
}

private struct TabReorderEndDropDelegate<Root: TabRoot, Identity: TabPageIdentity>: DropDelegate {

    let store: TabNavigationStore<Root, Identity>
    let animation: Animation

    func validateDrop(info: DropInfo) -> Bool {
        store.draggedTabID != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        withAnimation(animation) {
            store.endReordering()
        }
        return true
    }
}

/// A drag let go of outside any drop target is only reported from iOS 27;
/// before that the placeholder stands until the next reorder.
private struct TabReorderCancellationObserver<Root: TabRoot, Identity: TabPageIdentity>: ViewModifier {

    let store: TabNavigationStore<Root, Identity>
    let animation: Animation

    func body(content: Content) -> some View {
        if #available(iOS 27, visionOS 27, *) {
            content.onDragSessionUpdated { session in
                guard case .ended = session.phase else { return }
                withAnimation(animation) {
                    store.endReordering()
                }
            }
        } else {
            content
        }
    }
}
