import SwiftUI

struct TabSwitcherCard<Root: TabRoot, Identity: TabPageIdentity, Label: View>: View {

    private typealias Metrics = TabSwitcherCardMetrics

    let store: TabNavigationStore<Root, Identity>
    let tab: NavigationTab<Root, Identity>
    let isSelected: Bool
    let closeLabel: String
    let previewAspectRatio: CGFloat
    let onSelect: () -> Void
    let onClose: () -> Void
    let placeholderIcon: TabSwitcherPlaceholderIcon
    let label: (NavigationTab<Root, Identity>) -> Label
    @State private var dragOffset: CGFloat = 0
    @State private var isPastCloseDistance = false
    @State private var isHeaderVisible = true

    /// The collapsing page lands on the selected card, so its title row waits
    /// for the page to hand over to the snapshot rather than sit on top of it
    /// mid-morph.
    private var isHeaderShown: Bool {
        !isSelected || store.isPageSwappedForSnapshot
    }

    var body: some View {
        Button(action: onSelect) {
            // Ratio driven off a flexible shape, not the preview: a stand-in
            // has no intrinsic size for aspectRatio to work from.
            Color.clear
                .aspectRatio(previewAspectRatio, contentMode: .fit)
                .overlay(alignment: .top) {
                    TabSnapshotView(store: store, tabID: tab.id) {
                        TabSwitcherCardPlaceholder(icon: placeholderIcon)
                    }
                }
                .overlay(alignment: .top) {
                    ZStack(alignment: .top) {
                        TabSnapshotHeaderBlur(store: store, tabID: tab.id)
                        TabSwitcherCardHeader(
                            canClose: store.canCloseTabs,
                            closeLabel: closeLabel,
                            onClose: onClose
                        ) {
                            label(tab)
                        }
                    }
                    .opacity(isHeaderVisible ? 1 : 0)
                }
                .background(.background.secondary)
                // Clipped as a whole: `clipped()` on the preview trims to the
                // card's bounds but not to its rounded corners.
                .clipShape(.rect(cornerRadius: Metrics.cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
                // Outside the card, not over it: the collapsing page lands on the
                // card's own bounds, so an inset border spends the transition
                // hidden under the page and snaps back the frame it is swapped out.
                .background {
                    RoundedRectangle(
                        cornerRadius: Metrics.cornerRadius + Metrics.selectionRingInset,
                        style: .continuous
                    )
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                    .padding(-Metrics.selectionRingInset)
                }
                .contentShape(.rect(cornerRadius: Metrics.cornerRadius))
                .tabCardFrame(id: tab.id, in: store)
        }
        .offset(x: dragOffset)
        .opacity(closeProgress)
        // High priority: the card is a button, which otherwise swallows the drag.
        .highPriorityGesture(closeDragGesture)
        .buttonStyle(.plain)
        .accessibilityIdentifier("switcher.card")
        // Tapped on crossing either way, so the release point is felt.
        .sensoryFeedback(.impact(weight: .light), trigger: isPastCloseDistance)
        .onChange(of: isHeaderShown, initial: true) { _, isShown in
            // Hidden at once: the growing page covers the card from its first
            // frame, and the header would otherwise fade out on top of it.
            if isShown {
                withAnimation(.smooth(duration: 0.2)) {
                    isHeaderVisible = true
                }
            } else {
                isHeaderVisible = false
            }
        }
    }

    /// Fades the card as it is pushed away, so the swipe reads as closing.
    private var closeProgress: Double {
        1 - min(1, Double(-dragOffset / Metrics.closeDistance))
    }

    private var closeDragGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                // Vertical drags belong to the grid's scroll view.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragOffset = min(0, value.translation.width)
                isPastCloseDistance = store.canCloseTabs && -dragOffset > Metrics.closeDistance
            }
            .onEnded { value in
                isPastCloseDistance = false
                if store.canCloseTabs, value.translation.width < -Metrics.closeDistance {
                    withAnimation(.smooth(duration: 0.2)) {
                        dragOffset = -Metrics.closeDistance * 2
                    }
                    onClose()
                } else {
                    withAnimation(.smooth(duration: 0.2)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

/// Compared on what the card draws, not its actions: the switcher hands in new
/// closures every pass, so every card would redraw whenever any tab changed.
/// The actions only ever act on this card's own tab.
extension TabSwitcherCard: Equatable {
    static func == (lhs: TabSwitcherCard, rhs: TabSwitcherCard) -> Bool {
        lhs.tab.id == rhs.tab.id
            && lhs.tab.root == rhs.tab.root
            && lhs.tab.pageIdentity == rhs.tab.pageIdentity
            && lhs.isSelected == rhs.isSelected
            && lhs.previewAspectRatio == rhs.previewAspectRatio
    }
}
