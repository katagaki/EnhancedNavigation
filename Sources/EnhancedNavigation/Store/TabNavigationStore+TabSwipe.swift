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
    /// covered nearly a third of the page, or half the omnibox if that is
    /// less: a bar crowded with buttons leaves the omnibox too short to drag
    /// a third of the page along.
    func endTabSwipe(velocity: CGFloat, omniboxWidth: CGFloat = .infinity) {
        let width = tabSwipePageWidth
        guard let neighbour = tabSwipeNeighbour, width > 0 else {
            // Past either end the page only gives a little, so the finger's
            // speed is not the page's.
            cancelTabSwipe()
            return
        }
        let projected = tabSwipeTranslation + velocity * 0.2
        let threshold = min(width * 0.3, omniboxWidth > 0 ? omniboxWidth * 0.5 : .infinity)
        guard abs(projected) > threshold, (projected < 0) == neighbour.isNext else {
            cancelTabSwipe(velocity: velocity)
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
        settleTabSwipe(velocity: velocity)
    }

    func cancelTabSwipe(velocity: CGFloat = 0) {
        guard isSwipingBetweenTabs else { return }
        settleTabSwipe(velocity: velocity)
    }

    /// Springs from the speed the finger let go at, so a flick carries on
    /// into the settle rather than stopping dead and starting again.
    private func settleTabSwipe(velocity: CGFloat) {
        tabSwipeGeneration += 1
        let generation = tabSwipeGeneration
        // A spring's initial velocity is a fraction of the distance it covers
        // per second. Bounded, as a page released just short of rest would
        // otherwise be flung off it.
        let distance = -tabSwipeTranslation
        let relativeVelocity = abs(distance) < 1 ? 0 : min(max(velocity / distance, -12), 12)
        withAnimation(.interpolatingSpring(duration: 0.35, bounce: 0, initialVelocity: relativeVelocity)) {
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
