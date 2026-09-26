import SwiftUI

extension TabNavigationStore {

    /// Held back while a swipe back is in flight, like the media it mirrors:
    /// the path has already popped by then, and a cancelled swipe puts the
    /// page, and so its items, back.
    func removeBarItemsLeftBehind(in tabID: UUID) {
        guard !isInteractivelyPopping, let tab = tab(tabID) else { return }
        let history = pageHistories[tabID] ?? []
        barItems.removeItems(in: tabID) { pathToken in
            guard let token = pathToken?.base as? PathToken,
                  let depth = history.firstIndex(where: { $0.pathToken == token })
            else { return false }
            return depth > tab.path.count
        }
    }
}
