import Foundation

/// The switcher's own text, handed in so the app's localizations are used.
public struct TabSwitcherStrings {
    public var title: (Int) -> String
    public var closeAll: String
    public var newTab: String
    public var closeTab: String

    public init(
        title: @escaping (Int) -> String = { "\($0) Tabs" },
        closeAll: String = "Close All Tabs",
        newTab: String = "New Tab",
        closeTab: String = "Close Tab"
    ) {
        self.title = title
        self.closeAll = closeAll
        self.newTab = newTab
        self.closeTab = closeTab
    }
}
