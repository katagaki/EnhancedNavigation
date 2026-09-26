import EnhancedNavigation
import SwiftUI

/// The custom bar: one per tab, outside its `NavigationStack`, so it holds
/// still while pages push and pop underneath it.
struct DemoCustomBottomBar: View {

    let store: DemoStore
    let tabID: UUID

    var body: some View {
        let identity = store.displayedTab(for: tabID).pageIdentity ?? .home
        GlassEffectContainer {
            HStack(spacing: TabBottomBarMetrics.itemSpacing) {
                Button {
                    store.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                        .frame(width: TabBottomBarMetrics.itemHeight, height: TabBottomBarMetrics.itemHeight)
                        .contentShape(.circle)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .disabled(!store.displayedCanGoBack(for: tabID))
                .accessibilityLabel("Back")

                Label(identity.title, systemImage: identity.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity, minHeight: TabBottomBarMetrics.itemHeight)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .animation(.smooth, value: identity.title)

                Button {
                    store.showTabSwitcher()
                } label: {
                    DemoTabCountLabel(count: store.tabs.count)
                        .frame(width: TabBottomBarMetrics.itemHeight, height: TabBottomBarMetrics.itemHeight)
                        .contentShape(.circle)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Tabs")
            }
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .buttonStyle(.plain)
        }
    }
}

/// The same controls as a system `.bottomBar`, to compare against.
struct DemoSystemBottomBar: ToolbarContent {

    let store: DemoStore
    let tabID: UUID

    var body: some ToolbarContent {
        let identity = store.displayedTab(for: tabID).pageIdentity ?? .home
        ToolbarItem(placement: .bottomBar) {
            Button("Back", systemImage: "chevron.backward") {
                store.goBack()
            }
            .disabled(!store.displayedCanGoBack(for: tabID))
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Label(identity.title, systemImage: identity.symbolName)
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .frame(width: 220)
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button {
                store.showTabSwitcher()
            } label: {
                DemoTabCountLabel(count: store.tabs.count)
            }
            .accessibilityLabel("Tabs")
        }
    }
}

struct DemoTabCountLabel: View {

    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption.weight(.bold))
            .frame(width: 20, height: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(lineWidth: 1.8)
            }
    }
}
