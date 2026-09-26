import EnhancedNavigation
import SwiftUI

@main
struct DemoApp: App {

    @State private var store = DemoStore(
        configuration: TabStoreConfiguration(
            persistenceKeyPrefix: "EnhancedNavigationDemo",
            snapshotDirectoryName: "EnhancedNavigationDemoSnapshots"
        )
    )

    var body: some Scene {
        WindowGroup {
            DemoShell()
                .environment(store)
        }
    }
}

struct DemoShell: View {

    @Environment(DemoStore.self) private var store

    var body: some View {
        TabZoomContainer(store: store, cardCornerRadius: TabSwitcherCardMetrics.cornerRadius) {
            DemoSwitcher()
        } page: { _ in
            LiveTabStack(store: store) { tab in
                DemoTabView(store: store, tabID: tab.id)
            }
            // Edge to edge, or the snapshot carries blank status bar and home
            // indicator bands into the card.
            .ignoresSafeArea(.container)
        }
        .ignoresSafeArea(.container)
        .task {
            store.loadPersistedSnapshots()
            guard store.tabs.count == 1 else { return }
            store.openTab(inBackground: true)
            store.openTab(inBackground: true)
        }
    }
}

struct DemoTabView: View {

    let store: DemoStore
    let tabID: UUID

    var body: some View {
        switch DemoBarStyle.current {
        case .custom:
            stack
                .tabBottomBar {
                    DemoCustomBottomBar(store: store, tabID: tabID)
                }
        case .system:
            stack
        }
    }

    private var stack: some View {
        NavigationStack(path: store.pathBinding(for: tabID)) {
            DemoPage(identity: .home, seed: 0)
                .navigationDestination(for: Int.self) { number in
                    DemoPage(identity: .item(number), seed: number)
                }
        }
        .environment(\.demoTabID, tabID)
    }
}
