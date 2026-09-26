import EnhancedNavigation
import SwiftUI

/// The tab management view keeps the system's own `.bottomBar`.
struct DemoSwitcher: View {

    @Environment(DemoStore.self) private var store

    var body: some View {
        TabSwitcher(store: store, placeholderIcon: .systemImage("house"), rebuildingPath: rebuildPath) { tab in
            let identity = tab.pageIdentity ?? .home
            Label(identity.title, systemImage: identity.symbolName)
                .lineLimit(1)
        }
    }

    private func rebuildPath(_ token: Int, _ path: inout NavigationPath) -> Bool {
        path.append(token)
        return true
    }
}
