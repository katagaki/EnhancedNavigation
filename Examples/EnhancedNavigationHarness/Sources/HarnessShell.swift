import EnhancedNavigation
import SwiftUI

struct HarnessShell: View {

    @Environment(HarnessStore.self) private var store

    private var usesWideTabs: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }

    // UI tests can exercise narrow windows on a full-size simulator.
    private var previewWidth: CGFloat? {
        let width = UserDefaults.standard.double(forKey: "AdaptivePreviewWidth")
        return width > 0 ? CGFloat(width) : nil
    }

    var body: some View {
        AdaptiveTabContainer(store: store, cardCornerRadius: TabSwitcherCardMetrics.cornerRadius) {
            HarnessSwitcher()
        } page: { _ in
            LiveTabStack(store: store) { tab in
                HarnessTabView(store: store, tabID: tab.id, root: tab.root)
            }
            // Edge to edge, or the snapshot carries blank status bar and home
            // indicator bands into the card.
            .ignoresSafeArea(.container, edges: usesWideTabs ? [] : .all)
        } tabLabel: { tab in
            let identity = tab.pageIdentity ?? tab.root.identity
            Label(identity.title, systemImage: identity.symbolName)
        }
        .ignoresSafeArea(.container, edges: usesWideTabs ? [] : .all)
        .frame(width: previewWidth)
        .task { store.loadPersistedSnapshots() }
    }
}

/// One tab: its own stack, with the bottom bar on iPhone and page controls
/// registered for the shared top bar on iPad and Mac Catalyst.
struct HarnessTabView: View {

    let store: HarnessStore
    let tabID: UUID
    let root: HarnessRoot

    var body: some View {
        Group {
            if usesWideTabs {
                stack.registersTabBarItems(for: tabID, in: store)
            } else {
                stack.tabBottomBar(for: tabID, in: store) { items in
                    HarnessBottomBar(store: store, tabID: tabID, items: items)
                }
            }
        }
        // Outside the bar too, which reads it for its identifiers.
        .environment(\.harnessTabID, tabID)
        // A tab from last session is rebuilt the first time it is mounted,
        // unless the switcher's prewarm got to it first.
        .onAppear {
            store.restorePathIfNeeded(for: tabID, rebuilding: HarnessPaths.rebuild)
        }
    }

    private var usesWideTabs: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }

    private var stack: some View {
        NavigationStack(path: store.pathBinding(for: tabID)) {
            HarnessRootPage(root: root, token: nil)
                .navigationDestination(for: HarnessDestination.self) { destination in
                    HarnessDestinationPage(destination: destination)
                }
                // Where `navigate(to:)` lands.
                .navigationDestination(for: HarnessRoot.self) { root in
                    HarnessRootPage(root: root, token: .root(root.persistenceToken))
                }
        }
    }
}

struct HarnessRootPage: View {

    let root: HarnessRoot
    let token: HarnessDestination?

    var body: some View {
        Group {
            switch root {
            case .catalog:
                CatalogPage(token: token)
            case .feature(let feature):
                FeaturePage(feature: feature, token: token)
            }
        }
        .tabPage(pathToken: token)
    }
}

struct HarnessDestinationPage: View {

    let destination: HarnessDestination

    var body: some View {
        Group {
            switch destination {
            case .feature(let feature):
                FeaturePage(feature: feature, token: destination)
            case .root(let persistenceToken):
                if let root = HarnessRoot(persistenceToken: persistenceToken) {
                    HarnessRootPage(root: root, token: destination)
                }
            case .item(let number):
                ItemPage(number: number)
            case .player(let number):
                PlayerPage(number: number)
            }
        }
        // The destination is the page's path token too.
        .tabPage(pathToken: destination)
    }
}

struct FeaturePage: View {

    let feature: Feature
    let token: HarnessDestination?

    var body: some View {
        let identity = HarnessPageIdentity.feature(feature, token: token)
        switch feature {
        case .navigation: NavigationFeaturePage(identity: identity)
        case .backHistory: BackHistoryFeaturePage(identity: identity)
        case .overlayPages: OverlayFeaturePage(identity: identity)
        case .media: MediaFeaturePage(identity: identity)
        case .barItems: BarItemsFeaturePage(identity: identity)
        case .switcher: SwitcherFeaturePage(identity: identity)
        case .liveTabs: LiveTabsFeaturePage(identity: identity)
        case .restoration: RestorationFeaturePage(identity: identity)
        case .utilities: UtilitiesFeaturePage(identity: identity)
        }
    }
}
