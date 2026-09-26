import EnhancedNavigation
import SwiftUI

/// Everything the store knows, live.
struct HarnessInspector: View {

    @Environment(HarnessSession.self) private var session
    @Environment(HarnessStore.self) private var store
    @Environment(HarnessMediaCenter.self) private var media
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Store") {
                    HarnessValue(title: "Tabs", value: "\(store.tabs.count)", identifier: "inspector.tabCount")
                    HarnessValue(
                        title: "Live tabs",
                        value: "\(store.liveTabIDs.count) of \(store.configuration.liveTabLimit)",
                        identifier: "inspector.liveCount"
                    )
                    HarnessValue(
                        title: "Awaiting rebuild",
                        value: "\(store.tabsAwaitingPathRestore.count)",
                        identifier: "inspector.awaitingRestore"
                    )
                    HarnessValue(
                        title: "Switcher showing",
                        value: store.isShowingTabSwitcher ? "Yes" : "No",
                        identifier: "inspector.switcher"
                    )
                    HarnessValue(
                        title: "Now playing",
                        value: media.nowPlaying.map { "Player \($0.number)" } ?? "Nothing",
                        identifier: "inspector.media"
                    )
                    HarnessValue(title: "Launch", value: "\(session.launchCount)", identifier: "inspector.launch")
                }

                Section("Tabs, in order") {
                    ForEach(Array(store.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabRow(store: store, tab: tab, index: index)
                    }
                }

                Section("Frequently Visited") {
                    let roots = store.frequentlyVisitedRoots
                    if roots.isEmpty {
                        Text("None yet").foregroundStyle(.secondary)
                    }
                    ForEach(roots, id: \.self) { root in
                        LabeledContent(root.identity.title, value: "\(store.visitCounts[root.persistenceToken] ?? 0)")
                    }
                }

                Section("Events") {
                    if session.events.isEmpty {
                        Text("None yet").foregroundStyle(.secondary)
                    }
                    ForEach(Array(session.events.enumerated()), id: \.offset) { _, event in
                        Text(event)
                    }
                }
            }
            .navigationTitle("Inspector")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) { dismiss() }
                }
            }
        }
    }
}

private struct TabRow: View {

    let store: HarnessStore
    let tab: NavigationTab<HarnessRoot, HarnessPageIdentity>
    let index: Int

    var body: some View {
        let identity = tab.pageIdentity ?? tab.root.identity
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(index + 1).")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Label(identity.title, systemImage: identity.symbolName)
                    .font(.headline)
                Spacer()
                if tab.id == store.selectedTabID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Selected")
                }
            }
            HStack(spacing: 12) {
                Badge(text: store.isLive(tab.id) ? "Live" : "Evicted", isOn: store.isLive(tab.id))
                Badge(text: "Depth \(tab.path.count)", isOn: tab.canGoBack)
                Badge(text: "Root: \(tab.root.identity.title)", isOn: false)
                if store.snapshots[tab.id] != nil {
                    Badge(text: "Snapshot", isOn: true)
                }
                if store.overlayPages[tab.id] != nil {
                    Badge(text: "Overlay", isOn: true)
                }
            }
            .font(.caption)
        }
        .accessibilityElement(children: .combine)
        .harnessIdentifier("inspector.tab.\(index)")
    }
}

private struct Badge: View {

    let text: String
    let isOn: Bool

    var body: some View {
        Text(text)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isOn ? AnyShapeStyle(.tint.opacity(0.2)) : AnyShapeStyle(.fill.tertiary), in: .capsule)
    }
}
