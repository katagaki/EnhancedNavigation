import EnhancedNavigation
import SwiftUI

struct SwitcherFeaturePage: View {

    @Environment(HarnessStore.self) private var store

    let identity: HarnessPageIdentity

    var body: some View {
        HarnessPage(identity: identity) {
            HarnessSection("Try It") {
                Text("Open the switcher from the tab count in the bar. The page zooms down onto its card. Swipe a card left to close it, or press and hold one and drag it: a placeholder shows where it will land.")
                Button("Open Four Tabs to Rearrange", systemImage: "plus.square.on.square") {
                    for feature in [Feature.media, .barItems, .liveTabs, .utilities] {
                        store.openTab(at: .feature(feature), inBackground: true)
                    }
                }
                .harnessIdentifier("switcher.openFour")
                Button("Show Tabs", systemImage: "square.grid.2x2") {
                    store.showTabSwitcher()
                }
                .harnessIdentifier("switcher.show")
            }

            HarnessSection("Order", footer: "moveTab(_:to:) is what a drop calls.") {
                ForEach(Array(store.tabs.enumerated()), id: \.element.id) { index, tab in
                    let identity = tab.pageIdentity ?? tab.root.identity
                    Label("\(index + 1). \(identity.title)", systemImage: identity.symbolName)
                }
                HarnessValue(
                    title: "Order",
                    value: store.tabs.map { ($0.pageIdentity ?? $0.root.identity).title }.joined(separator: ", "),
                    identifier: "switcher.order"
                )
            }

            HarnessSection("Customised Here", footer: "See HarnessSwitcher.swift.") {
                Text("TabSwitcherStrings for the title and labels, a testtube placeholder icon for tabs without a snapshot, the card label, and an Inspector button in the top trailing slot.")
            }

            FeatureFooter(feature: .switcher)
        }
    }
}

struct LiveTabsFeaturePage: View {

    @Environment(HarnessStore.self) private var store
    @Environment(\.harnessTabID) private var tabID
    /// Set when this page's view is built, so a tab rebuilt after eviction
    /// shows a later time than it was first opened at.
    @State private var builtAt = Date.now

    let identity: HarnessPageIdentity

    var body: some View {
        HarnessPage(identity: identity) {
            HarnessSection("This Page", footer: "Evict this tab by visiting more tabs than the limit, then come back: it is rebuilt from its path, so this time changes.") {
                LabeledContent("Built at", value: builtAt.formatted(date: .omitted, time: .standard))
            }

            HarnessSection("Live Tabs", footer: "LiveTabStack mounts the \(store.configuration.liveTabLimit) most recently used tabs and hides the rest.") {
                HarnessValue(
                    title: "Mounted",
                    value: "\(store.liveTabIDs.count) of \(store.configuration.liveTabLimit)",
                    identifier: "liveTabs.count"
                )
                ForEach(Array(store.tabs.enumerated()), id: \.element.id) { index, tab in
                    let identity = tab.pageIdentity ?? tab.root.identity
                    HStack {
                        Text("\(index + 1). \(identity.title)")
                        Spacer()
                        Text(store.isLive(tab.id) ? "Live" : "Evicted")
                            .foregroundStyle(store.isLive(tab.id) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        if tab.id != tabID {
                            Button("Select") { store.select(tab.id) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                Button("Open Three Background Tabs", systemImage: "plus.square.on.square") {
                    for _ in 0..<3 {
                        store.openTab(inBackground: true)
                    }
                }
                .harnessIdentifier("liveTabs.openThree")
            }

            FeatureFooter(feature: .liveTabs)
        }
    }
}

struct RestorationFeaturePage: View {

    @Environment(HarnessSession.self) private var session
    @Environment(HarnessStore.self) private var store
    @Environment(\.harnessTabID) private var tabID

    let identity: HarnessPageIdentity

    var body: some View {
        HarnessPage(identity: identity) {
            HarnessSection("Try It", footer: "Tabs, their order and selection, and each tab's page history are written to UserDefaults. On launch every tab is rebuilt from its path tokens, down to the page it was left on.") {
                NavigationLink("Push Item 1", value: HarnessDestination.item(1))
                    .harnessIdentifier("restoration.push")
                Button("Simulate Relaunch", systemImage: "arrow.clockwise") {
                    Task { await session.relaunch() }
                }
                .harnessIdentifier("restoration.relaunch")
                Text("Or quit the app from the app switcher and open it again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HarnessSection("This Tab's Record") {
                let history = tabID.flatMap { store.pageHistories[$0] } ?? []
                ForEach(Array(history.enumerated()), id: \.offset) { depth, page in
                    LabeledContent(page.title, value: "depth \(depth)")
                }
                HarnessValue(title: "Launch", value: "\(session.launchCount)", identifier: "restoration.launch")
                HarnessValue(
                    title: "Tabs awaiting rebuild",
                    value: "\(store.tabsAwaitingPathRestore.count)",
                    identifier: "restoration.awaiting"
                )
            }

            FeatureFooter(feature: .restoration)
        }
    }
}
