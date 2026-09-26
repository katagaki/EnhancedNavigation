import EnhancedNavigation
import SwiftUI

nonisolated enum DemoRoot: String, TabRoot {
    case home

    static var newTabRoot: DemoRoot { .home }

    var persistenceToken: String { rawValue }

    init?(persistenceToken: String) {
        self.init(rawValue: persistenceToken)
    }
}

nonisolated struct DemoPageIdentity: TabPageIdentity {
    var title: String
    var symbolName: String
    var pathToken: Int?

    func names(_ other: DemoPageIdentity) -> Bool {
        guard let pathToken, let otherToken = other.pathToken else { return title == other.title }
        return pathToken == otherToken
    }

    static let home = DemoPageIdentity(title: "Home", symbolName: "house", pathToken: nil)

    static func item(_ number: Int) -> DemoPageIdentity {
        DemoPageIdentity(title: "Item \(number)", symbolName: "square.stack", pathToken: number)
    }
}

typealias DemoStore = TabNavigationStore<DemoRoot, DemoPageIdentity>

/// Which bottom bar the pages get, picked with `-BarStyle system|custom`.
enum DemoBarStyle: String {
    case system
    case custom

    static var current: DemoBarStyle {
        UserDefaults.standard.string(forKey: "BarStyle").flatMap(DemoBarStyle.init) ?? .custom
    }
}

struct DemoTabIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var demoTabID: UUID? {
        get { self[DemoTabIDKey.self] }
        set { self[DemoTabIDKey.self] = newValue }
    }
}
