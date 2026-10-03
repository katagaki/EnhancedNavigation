import Foundation

/// The tab beside the selected one while an omnibox swipe is on screen: the
/// one being uncovered, then the one sliding away once the swipe commits.
public struct TabSwipeNeighbour: Equatable {
    public let tabID: UUID
    /// Whether it sits to the right of the selected tab.
    public let isNext: Bool
}
