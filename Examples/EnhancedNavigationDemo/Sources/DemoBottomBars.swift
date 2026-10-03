import EnhancedNavigation
import SwiftUI

/// The custom bar: one per tab, outside its `NavigationStack`, so it holds
/// still while pages push and pop underneath it.
struct DemoCustomBottomBar: View {

    let store: DemoStore
    let tabID: UUID
    /// What the visible page put in the bar.
    let items: TabBottomBarItems

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

                HStack {
                    Label(identity.title, systemImage: identity.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.smooth, value: identity.title)
                    items.omniboxAccessory
                }
                .padding(.horizontal, 17)
                .frame(maxWidth: .infinity, minHeight: TabBottomBarMetrics.itemHeight)
                .glassEffect(.regular.interactive(), in: .capsule)

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
            .font(.system(size: TabBottomBarMetrics.symbolSize, weight: .medium))
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
            .font(.system(size: 13, weight: .bold))
            .minimumScaleFactor(0.6)
            .frame(width: 24, height: 24)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(lineWidth: 1.8)
            }
    }
}
