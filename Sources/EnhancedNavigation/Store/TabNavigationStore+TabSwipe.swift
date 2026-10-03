import SwiftUI

public extension TabNavigationStore {
    var isSwipingBetweenTabs: Bool {
        tabSwipeNeighbour != nil || tabSwipeTranslation != 0
    }
}

extension TabNavigationStore {

    var canBeginTabSwipe: Bool {
        !isInteractivelyPopping && !isShowingTabSwitcher && !isPageClipActive
    }

    func updateTabSwipe(translation: CGFloat) {
        // A new swipe takes over from one still settling, whose completion
        // would otherwise take the page it uncovers away mid-swipe.
        tabSwipeGeneration += 1
        guard let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }
        let isNext = translation < 0
        let destination = index + (isNext ? 1 : -1)
        let neighbour = translation != 0 && tabs.indices.contains(destination)
            ? TabSwipeNeighbour(tabID: tabs[destination].id, isNext: isNext)
            : nil
        if neighbour != tabSwipeNeighbour {
            tabSwipeNeighbour = neighbour
        }
        tabSwipeTranslation = neighbour == nil ? Self.rubberBanded(translation) : translation
    }

    /// Commits when the swipe, carried on by its release velocity, would have
    /// covered nearly a third of the page: a drag along the whole omnibox is
    /// less than half of it.
    func endTabSwipe(velocity: CGFloat) {
        let width = tabSwipePageWidth
        guard let neighbour = tabSwipeNeighbour, width > 0 else {
            cancelTabSwipe()
            return
        }
        let projected = tabSwipeTranslation + velocity * 0.2
        guard abs(projected) > width * 0.3, (projected < 0) == neighbour.isNext else {
            cancelTabSwipe()
            return
        }
        // Selected on release rather than once settled, so the incoming page
        // takes touches straight away and the next swipe can start from it.
        // The outgoing tab becomes the neighbour, placed where it already is.
        let outgoingTabID = selectedTabID
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            select(neighbour.tabID)
            tabSwipeNeighbour = TabSwipeNeighbour(tabID: outgoingTabID, isNext: !neighbour.isNext)
            tabSwipeTranslation += neighbour.isNext ? width : -width
        }
        settleTabSwipe()
    }

    func cancelTabSwipe() {
        guard isSwipingBetweenTabs else { return }
        settleTabSwipe()
    }

    private func settleTabSwipe() {
        tabSwipeGeneration += 1
        let generation = tabSwipeGeneration
        withAnimation(.smooth(duration: 0.3)) {
            tabSwipeTranslation = 0
        } completion: { [self] in
            guard generation == tabSwipeGeneration else { return }
            tabSwipeNeighbour = nil
        }
    }

    /// With no tab beyond the end, the page gives a little and then resists.
    private static func rubberBanded(_ translation: CGFloat) -> CGFloat {
        let reach: CGFloat = 48
        return copysign(reach * log1p(abs(translation) / reach), translation)
    }
}
