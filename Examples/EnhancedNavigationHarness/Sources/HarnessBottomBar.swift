import EnhancedNavigation
import SwiftUI

/// Back (long-press for history), the page's leading item, the omnibox with
/// the page's accessory, the page's trailing item, and the tab count.
struct HarnessBottomBar: View {

    let store: HarnessStore
    let tabID: UUID
    let items: TabBottomBarItems

    var body: some View {
        let identity = store.displayedTab(for: tabID).pageIdentity ?? .catalog
        GlassEffectContainer {
            HStack(spacing: TabBottomBarMetrics.itemSpacing) {
                backButton

                if items.hasLeading {
                    items.leading
                        .labelStyle(.iconOnly)
                        .frame(width: TabBottomBarMetrics.itemHeight, height: TabBottomBarMetrics.itemHeight)
                        .glassEffect(.regular.interactive(), in: .circle)
                }

                HStack {
                    Label(identity.title, systemImage: identity.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.smooth, value: identity.title)
                        .harnessIdentifier("bar.title")
                    items.omniboxAccessory
                }
                .padding(.horizontal, 17)
                .frame(maxWidth: .infinity, minHeight: TabBottomBarMetrics.itemHeight)
                .glassEffect(.regular.interactive(), in: .capsule)

                if items.hasTrailing {
                    items.trailing
                        .labelStyle(.iconOnly)
                        .frame(width: TabBottomBarMetrics.itemHeight, height: TabBottomBarMetrics.itemHeight)
                        .glassEffect(.regular.interactive(), in: .circle)
                }

                Button {
                    store.showTabSwitcher()
                } label: {
                    TabCountLabel(count: store.tabs.count)
                        .frame(width: TabBottomBarMetrics.itemHeight, height: TabBottomBarMetrics.itemHeight)
                        .contentShape(.circle)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Tabs")
                .harnessIdentifier("bar.tabs")
            }
            .font(.system(size: TabBottomBarMetrics.symbolSize, weight: .medium))
            .foregroundStyle(.primary)
            .buttonStyle(.plain)
        }
    }

    /// Tap to go back, press and hold for every page behind this one.
    private var backButton: some View {
        Menu {
            ForEach(store.backHistory(for: tabID), id: \.depth) { entry in
                Button(entry.identity.title, systemImage: entry.identity.symbolName) {
                    store.popTo(depth: entry.depth)
                }
            }
        } label: {
            Image(systemName: "chevron.backward")
                .frame(width: TabBottomBarMetrics.itemHeight, height: TabBottomBarMetrics.itemHeight)
                .contentShape(.circle)
        } primaryAction: {
            store.goBack()
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(!store.displayedCanGoBack(for: tabID))
        .accessibilityLabel("Back")
        .harnessIdentifier("bar.back")
    }
}

struct TabCountLabel: View {

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
