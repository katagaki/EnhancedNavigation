import EnhancedNavigation
import SwiftUI

/// The switcher with every customisation it takes: strings, a placeholder
/// icon, a card label and a top trailing item.
struct HarnessSwitcher: View {

    @Environment(HarnessStore.self) private var store
    @State private var isShowingInspector = false

    var body: some View {
        TabSwitcher(
            store: store,
            strings: TabSwitcherStrings(
                title: { $0 == 1 ? "1 Harness Tab" : "\($0) Harness Tabs" },
                closeAll: "Close Every Tab",
                newTab: "New Harness Tab",
                closeTab: "Close Harness Tab"
            ),
            placeholderIcon: .systemImage("testtube.2"),
            rebuildingPath: HarnessPaths.rebuild
        ) { tab in
            let identity = tab.pageIdentity ?? tab.root.identity
            Label(identity.title, systemImage: identity.symbolName)
                .lineLimit(1)
        } topTrailingItem: {
            Button("Inspector", systemImage: "info.circle") {
                isShowingInspector = true
            }
            .harnessIdentifier("switcher.inspector")
        }
        .sheet(isPresented: $isShowingInspector) {
            HarnessInspector()
        }
    }
}
