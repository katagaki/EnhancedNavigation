import EnhancedNavigation
import SwiftUI

/// Every new tab's root: a way into each feature.
struct CatalogPage: View {

    @Environment(HarnessStore.self) private var store
    @State private var isShowingInspector = false

    let token: HarnessDestination?

    var body: some View {
        var identity = HarnessPageIdentity.catalog
        identity.pathToken = token
        return HarnessPage(identity: identity) {
            Text("A test harness for EnhancedNavigation. Each feature is a page of its own; the bar below is the package's custom bottom bar.")
                .foregroundStyle(.secondary)

            HarnessSection("Features") {
                ForEach(Feature.allCases, id: \.self) { feature in
                    NavigationLink(value: HarnessDestination.feature(feature)) {
                        FeatureRow(feature: feature)
                    }
                    .buttonStyle(.plain)
                    .harnessIdentifier("catalog.\(feature.rawValue)")
                }
            }

            HarnessSection(
                "Frequently Visited",
                footer: "frequentlyVisitedRoots, counted by openTab(at:) and navigate(to:)."
            ) {
                let roots = store.frequentlyVisitedRoots
                if roots.isEmpty {
                    Text("Open a feature in a new tab to see it here.")
                        .foregroundStyle(.secondary)
                }
                ForEach(roots, id: \.self) { root in
                    HStack {
                        Label(root.identity.title, systemImage: root.identity.symbolName)
                        Spacer()
                        Button("Go") { store.navigate(to: root) }
                            .buttonStyle(.bordered)
                        Button("New Tab") { store.openTab(at: root) }
                            .buttonStyle(.bordered)
                    }
                    .harnessIdentifier("frequent.\(root.persistenceToken)")
                }
            }
        }
        .tabOmniboxAccessory {
            Menu("More", systemImage: "ellipsis") {
                Button("Inspector", systemImage: "info.circle") { isShowingInspector = true }
                Button("New Tab", systemImage: "plus") { store.openTab() }
            }
        }
        .sheet(isPresented: $isShowingInspector) {
            HarnessInspector()
        }
    }
}

private struct FeatureRow: View {

    let feature: Feature

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: feature.symbolName)
                .font(.title3)
                .frame(width: 32)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.headline)
                Text(feature.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }
}
