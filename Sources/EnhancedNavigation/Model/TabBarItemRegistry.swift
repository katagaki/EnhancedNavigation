import Observation
import SwiftUI

/// Where a page's item goes in its tab's chrome.
public enum TabBottomBarItemPlacement: Hashable, Sendable {
    /// Beside the omnibox, on its leading side.
    case leading
    /// Beside the omnibox, on its trailing side.
    case trailing
    /// Inside the omnibox, after the page's name.
    case omniboxAccessory
}

/// One page's item, kept by reference so the page can hand it new content
/// every time its own body runs without that being a state change mid-update.
@Observable
final class TabBarItemBox {

    @ObservationIgnored private(set) var content: () -> AnyView
    /// Bumped a pass after new content arrives, so the bar redraws for state
    /// the content reads that observation cannot see, such as the page's own
    /// `@State`.
    private(set) var generation = 0
    @ObservationIgnored private var isRefreshScheduled = false

    init(content: @escaping () -> AnyView) {
        self.content = content
    }

    func update(_ content: @escaping () -> AnyView) {
        self.content = content
        guard !isRefreshScheduled else { return }
        isRefreshScheduled = true
        Task { @MainActor in
            self.isRefreshScheduled = false
            self.generation &+= 1
        }
    }
}

/// Every tab's bar items, filed by the page that declared them. Kept apart
/// from the store's own state, so a page handing over new content redraws the
/// bar and nothing else.
@Observable
final class TabBarItemRegistry {

    struct Key: Hashable {
        let pathToken: AnyHashable?
        let placement: TabBottomBarItemPlacement
    }

    @ObservationIgnored private var boxes: [UUID: [Key: TabBarItemBox]] = [:]
    /// Which tabs' items have come or gone, for the bars to observe.
    private var revisions: [UUID: Int] = [:]

    func box(for key: Key, in tabID: UUID) -> TabBarItemBox? {
        _ = revisions[tabID]
        return boxes[tabID]?[key]
    }

    func register(_ box: TabBarItemBox, for key: Key, in tabID: UUID) {
        guard boxes[tabID]?[key] !== box else { return }
        boxes[tabID, default: [:]][key] = box
        revisions[tabID, default: 0] &+= 1
    }

    func unregister(_ box: TabBarItemBox, for key: Key, in tabID: UUID) {
        guard boxes[tabID]?[key] === box else { return }
        boxes[tabID]?[key] = nil
        revisions[tabID, default: 0] &+= 1
    }

    /// Drops the items of pages no longer in the tab's stack.
    func removeItems(in tabID: UUID, where isGone: (AnyHashable?) -> Bool) {
        guard let tabBoxes = boxes[tabID] else { return }
        let gone = tabBoxes.keys.filter { isGone($0.pathToken) }
        guard !gone.isEmpty else { return }
        for key in gone {
            boxes[tabID]?[key] = nil
        }
        revisions[tabID, default: 0] &+= 1
    }

    func discard(_ tabID: UUID) {
        guard boxes.removeValue(forKey: tabID) != nil else { return }
        revisions[tabID] = nil
    }
}
