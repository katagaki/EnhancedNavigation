import EnhancedNavigation
import SwiftUI

/// One screen per feature of the package, each a page of its own.
nonisolated enum Feature: String, CaseIterable, Codable, Hashable {
    case navigation
    case backHistory
    case overlayPages
    case media
    case barItems
    case switcher
    case liveTabs
    case restoration
    case utilities

    var title: String {
        switch self {
        case .navigation: "Navigation"
        case .backHistory: "Back History"
        case .overlayPages: "Overlay Pages"
        case .media: "Media Pages"
        case .barItems: "Bar Items"
        case .switcher: "Tab Switcher"
        case .liveTabs: "Live Tabs"
        case .restoration: "Restoration"
        case .utilities: "Utilities"
        }
    }

    var symbolName: String {
        switch self {
        case .navigation: "arrow.forward.square"
        case .backHistory: "clock.arrow.circlepath"
        case .overlayPages: "square.on.square.dashed"
        case .media: "play.rectangle"
        case .barItems: "menubar.dock.rectangle"
        case .switcher: "square.grid.2x2"
        case .liveTabs: "bolt.horizontal"
        case .restoration: "arrow.clockwise.icloud"
        case .utilities: "wrench.and.screwdriver"
        }
    }

    var summary: String {
        switch self {
        case .navigation: "Push, pop, pop to root and open deep links in a tab of their own."
        case .backHistory: "Long-press the back button for every page behind this one."
        case .overlayPages: "Pages shown with navigationDestination(item:) that never enter the path."
        case .media: "Players are stopped when popped or closed, and keep their tab alive."
        case .barItems: "Pages put their own controls in the custom bottom bar."
        case .switcher: "Zoom into the grid, swipe to close, drag to reorder."
        case .liveTabs: "Only the most recent tabs stay mounted."
        case .restoration: "Every tab comes back down to the page it was left on."
        case .utilities: "Snapshots, page slots, frame clock and display metrics."
        }
    }
}

/// What a tab is parked on.
nonisolated enum HarnessRoot: Hashable, TabRoot {
    case catalog
    case feature(Feature)

    static var newTabRoot: HarnessRoot { .catalog }

    var persistenceToken: String {
        switch self {
        case .catalog: "catalog"
        case .feature(let feature): "feature.\(feature.rawValue)"
        }
    }

    init?(persistenceToken: String) {
        if persistenceToken == "catalog" {
            self = .catalog
        } else if persistenceToken.hasPrefix("feature."),
                  let feature = Feature(rawValue: String(persistenceToken.dropFirst("feature.".count))) {
            self = .feature(feature)
        } else {
            return nil
        }
    }

    var isRecordedAsVisit: Bool { self != .catalog }

    var identity: HarnessPageIdentity {
        switch self {
        case .catalog: .catalog
        case .feature(let feature): .feature(feature, token: nil)
        }
    }
}

/// Everything that is pushed onto a tab's path, and the token it is restored
/// from, which are one and the same here.
nonisolated enum HarnessDestination: Hashable, Codable {
    case feature(Feature)
    case root(String)
    case item(Int)
    case player(Int)
}

nonisolated struct HarnessPageIdentity: TabPageIdentity {
    var title: String
    var symbolName: String
    var pathToken: HarnessDestination?

    func names(_ other: HarnessPageIdentity) -> Bool {
        guard let pathToken, let otherToken = other.pathToken else { return title == other.title }
        return pathToken == otherToken
    }

    static let catalog = HarnessPageIdentity(title: "Catalog", symbolName: "list.bullet.rectangle", pathToken: nil)

    static func feature(_ feature: Feature, token: HarnessDestination?) -> HarnessPageIdentity {
        HarnessPageIdentity(title: feature.title, symbolName: feature.symbolName, pathToken: token)
    }

    static func item(_ number: Int) -> HarnessPageIdentity {
        HarnessPageIdentity(title: "Item \(number)", symbolName: "square.stack", pathToken: .item(number))
    }

    static func player(_ number: Int) -> HarnessPageIdentity {
        HarnessPageIdentity(title: "Player \(number)", symbolName: "play.tv", pathToken: .player(number))
    }

    static func overlay(_ name: String) -> HarnessPageIdentity {
        HarnessPageIdentity(title: name, symbolName: "square.on.square.dashed", pathToken: nil)
    }
}

typealias HarnessStore = TabNavigationStore<HarnessRoot, HarnessPageIdentity>

enum HarnessPaths {
    /// Turns a saved token back into what was pushed.
    static func rebuild(_ token: HarnessDestination, _ path: inout NavigationPath) -> Bool {
        switch token {
        case .root(let persistenceToken):
            guard let root = HarnessRoot(persistenceToken: persistenceToken) else { return false }
            path.append(root)
        default:
            path.append(token)
        }
        return true
    }
}

struct HarnessTabIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var harnessTabID: UUID? {
        get { self[HarnessTabIDKey.self] }
        set { self[HarnessTabIDKey.self] = newValue }
    }
}
