import SwiftUI

/// Uses the card zoom on iPhone and a persistent Safari-style tab strip on iPad
/// and Mac Catalyst. The tab store and each tab's navigation stack are shared.
public struct AdaptiveTabContainer<
    Root: TabRoot,
    Identity: TabPageIdentity,
    Switcher: View,
    Page: View,
    TabLabel: View
>: View {

    public typealias Tab = NavigationTab<Root, Identity>

    private let store: TabNavigationStore<Root, Identity>
    private let cardCornerRadius: CGFloat
    private let switcher: Switcher
    private let page: (CGFloat) -> Page
    private let tabLabel: (Tab) -> TabLabel

    public init(
        store: TabNavigationStore<Root, Identity>,
        cardCornerRadius: CGFloat,
        @ViewBuilder switcher: () -> Switcher,
        @ViewBuilder page: @escaping (CGFloat) -> Page,
        @ViewBuilder tabLabel: @escaping (Tab) -> TabLabel
    ) {
        self.store = store
        self.cardCornerRadius = cardCornerRadius
        self.switcher = switcher()
        self.page = page
        self.tabLabel = tabLabel
    }

    public var body: some View {
        if Self.usesWideTabs {
            wideLayout
        } else {
            TabZoomContainer(store: store, cardCornerRadius: cardCornerRadius) {
                switcher
            } page: { width in
                page(width)
            }
        }
    }

    private var wideLayout: some View {
        TabZoomContainer(store: store, cardCornerRadius: cardCornerRadius) {
            switcher
                // Keep the grid laid out to measure card frames, while its
                // toolbar stays out of the glass chrome above the page.
                .opacity(store.isShowingTabSwitcher ? 1 : 0.001)
        } page: { width in
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    toolbar
                    if store.tabs.count > 1 {
                        tabStrip
                    }
                }
                .background(.regularMaterial)
                page(width)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(uiColor: .systemBackground))
        }
    }

    private var toolbar: some View {
        TabBottomBarItemsReader(store: store, tabID: store.selectedTabID) { items in
            GlassEffectContainer(spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        backButton
                        leadingControl(items)
                        Spacer(minLength: 24)
                        omnibox(items)
                            .frame(minWidth: 160, idealWidth: 160)
                        accessoryControl(items)
                        Spacer(minLength: 24)
                        trailingControl(items)
                        newTabButton
                        overviewButton
                    }

                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Spacer(minLength: 0)
                            omnibox(items)
                            accessoryControl(items)
                            Spacer(minLength: 0)
                        }
                        HStack(spacing: 8) {
                            backButton
                            leadingControl(items)
                            Spacer(minLength: 0)
                            trailingControl(items)
                            newTabButton
                            overviewButton
                        }
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: TabBottomBarMetrics.symbolSize, weight: .medium))
                .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func omnibox(_ items: TabBottomBarItems) -> some View {
        HStack(spacing: 8) {
            tabLabel(store.displayedTab)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            if !Self.separatesOmniboxAccessory {
                items.omniboxAccessory
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: 520)
        .frame(height: toolbarControlSize)
        .glassEffect(.regular, in: .capsule)
        .tabSwitchingGesture(for: store.selectedTabID, in: store)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("adaptive.omnibox")
    }

    @ViewBuilder
    private func leadingControl(_ items: TabBottomBarItems) -> some View {
        if items.hasLeading {
            items.leading
                .labelStyle(.iconOnly)
                .frame(width: toolbarControlSize, height: toolbarControlSize)
                .glassEffect(.regular.interactive(), in: .circle)
        }
    }

    @ViewBuilder
    private func trailingControl(_ items: TabBottomBarItems) -> some View {
        if items.hasTrailing {
            items.trailing
                .labelStyle(.iconOnly)
                .frame(width: toolbarControlSize, height: toolbarControlSize)
                .glassEffect(.regular.interactive(), in: .circle)
        }
    }

    @ViewBuilder
    private func accessoryControl(_ items: TabBottomBarItems) -> some View {
        if Self.separatesOmniboxAccessory, items.hasOmniboxAccessory {
            items.omniboxAccessory
                .frame(width: toolbarControlSize, height: toolbarControlSize)
                .glassEffect(.regular.interactive(), in: .circle)
        }
    }

    private var newTabButton: some View {
        Button("New Tab", systemImage: "plus") { store.openTab() }
            .labelStyle(.iconOnly)
            .frame(width: toolbarControlSize, height: toolbarControlSize)
            .glassEffect(.regular.interactive(), in: .circle)
    }

    private var overviewButton: some View {
        Button("Show All Tabs", systemImage: "square.on.square") {
            store.showTabOverview()
        }
        .labelStyle(.iconOnly)
        .frame(width: toolbarControlSize, height: toolbarControlSize)
        .glassEffect(.regular.interactive(), in: .circle)
    }

    private var toolbarControlSize: CGFloat { 40 }

    private var backButton: some View {
        Menu {
            ForEach(store.backHistory(for: store.selectedTabID), id: \.depth) { entry in
                Button {
                    store.popTo(depth: entry.depth)
                } label: {
                    tabLabel(tab(for: entry.identity))
                }
            }
        } label: {
            Image(systemName: "chevron.backward")
                .frame(width: toolbarControlSize, height: toolbarControlSize)
                .contentShape(.circle)
        } primaryAction: {
            store.goBack()
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(!store.displayedCanGoBack)
        .accessibilityLabel("Back")
    }

    private func tab(for identity: Identity) -> Tab {
        var tab = store.selectedTab
        tab.pageIdentity = identity
        return tab
    }

    private var tabStrip: some View {
        GeometryReader { geometry in
            let tabWidth = max(
                160,
                (geometry.size.width - 24 - CGFloat(store.tabs.count - 1) * 4)
                    / CGFloat(store.tabs.count)
            )
            ScrollViewReader { scroll in
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(store.tabs) { tab in
                            HStack(spacing: 8) {
                                Button {
                                    store.select(tab.id)
                                } label: {
                                    tabLabel(tab)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("adaptive.tab.\(tab.id)")
                                .accessibilityAddTraits(tab.id == store.selectedTabID ? .isSelected : [])

                                if tab.id == store.selectedTabID, store.canCloseTabs {
                                    Button("Close Tab", systemImage: "xmark") { store.close(tab.id) }
                                        .labelStyle(.iconOnly)
                                        .buttonStyle(.plain)
                                }
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .frame(width: tabWidth, height: 38)
                            .background(
                                tab.id == store.selectedTabID ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.clear),
                                in: .capsule
                            )
                            .id(tab.id)
                            .reorderableTab(id: tab.id, in: store)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .scrollIndicators(.hidden)
                .endsTabReordering(in: store)
                .onChange(of: store.selectedTabID, initial: true) { _, tabID in
                    scroll.scrollTo(tabID, anchor: .center)
                }
                .onChange(of: store.tabs.count) { _, _ in
                    scroll.scrollTo(store.selectedTabID, anchor: .center)
                }
                .onChange(of: geometry.size.width) { _, _ in
                    scroll.scrollTo(store.selectedTabID, anchor: .center)
                }
            }
        }
        .frame(height: 46)
    }

    private static var usesWideTabs: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }

    private static var separatesOmniboxAccessory: Bool {
        #if targetEnvironment(macCatalyst)
        false
        #else
        true
        #endif
    }
}
