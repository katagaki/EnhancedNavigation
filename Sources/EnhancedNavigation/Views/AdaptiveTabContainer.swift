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

    @Environment(\.tabOmniboxEditor) private var omniboxEditor
    @Environment(\.tabOmniboxPopup) private var omniboxPopup

    /// How far the window controls reach into the toolbar's leading corner.
    @State private var windowControlsWidth: CGFloat = 0

    /// The top inset the toolbar gives the page, which a `NavigationStack`
    /// does not hand on to its pages.
    @State private var topBarInset: CGFloat = 0

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
            page(width)
                .overlay {
                    if isEditingOmnibox {
                        // Under the toolbar's safe area bar, so the bar and
                        // its field stay usable while the page dismisses.
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { endOmniboxEditing() }
                    }
                }
                .environment(\.tabTopBarInset, topBarInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                // Inside the bar, so the inset measured is the one it adds.
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.safeAreaInsets.top
                } action: { inset in
                    topBarInset = inset
                }
                // A safe area bar rather than a stack, so pages scroll on
                // underneath the bar's material.
                .safeAreaBar(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        toolbar
                        if store.tabs.count > 1 {
                            tabStrip
                        }
                    }
                    // Up behind the status bar too, so content scrolling past
                    // the toolbar never shows above it.
                    .background(.bar, ignoresSafeAreaEdges: .top)
                }
                .overlayPreferenceValue(TabOmniboxBoundsKey.self) { anchor in
                    if isEditingOmnibox, let omniboxPopup, omniboxPopup.isPresented {
                        TabOmniboxPopupLayer(anchor: anchor, popup: omniboxPopup)
                            .transition(.opacity)
                    }
                }
                .background(Color(uiColor: .systemBackground))
                .onChange(of: store.selectedTabID) { _, _ in endOmniboxEditing() }
        }
    }

    private var isEditingOmnibox: Bool {
        omniboxEditor?.isEditing.wrappedValue ?? false
    }

    private func endOmniboxEditing() {
        guard isEditingOmnibox else { return }
        omniboxEditor?.isEditing.wrappedValue = false
    }

    private var toolbar: some View {
        TabBottomBarItemsReader(store: store, tabID: store.selectedTabID) { items in
            GlassEffectContainer(spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    regularToolbar(items)
                    compactToolbar(items)
                    stackedToolbar(items)
                }
                .buttonStyle(.plain)
                .font(.system(size: TabBottomBarMetrics.symbolSize, weight: .medium))
                .foregroundStyle(.primary)
            }
            // Clear of the window controls when iPadOS shows them beside the
            // toolbar rather than above it.
            .padding(.leading, max(16, windowControlsWidth))
            .padding(.trailing, 16)
            .padding(.vertical, 8)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.containerCornerInsets.topLeading.width
            } action: { width in
                windowControlsWidth = width
            }
        }
    }

    /// Navigation, the omnibox and the tab buttons spread across a full-width
    /// window.
    private func regularToolbar(_ items: TabBottomBarItems) -> some View {
        HStack(spacing: 8) {
            backButton
            leadingControl(items)
            Spacer(minLength: 24)
            omnibox(items, embedsAccessory: !Self.separatesOmniboxAccessory)
                .frame(minWidth: 160, idealWidth: 160)
            accessoryControl(items)
            Spacer(minLength: 24)
            trailingControl(items)
            newTabButton
            overviewButton
        }
    }

    /// One row for a narrow window, the omnibox taking whatever the buttons
    /// leave and keeping the page's accessory inside it.
    private func compactToolbar(_ items: TabBottomBarItems) -> some View {
        HStack(spacing: 8) {
            backButton
            leadingControl(items)
            omnibox(items, embedsAccessory: true)
                .frame(minWidth: 120, idealWidth: 120)
            trailingControl(items)
            newTabButton
            overviewButton
        }
    }

    /// The omnibox across the window over a row of buttons, for a window too
    /// narrow to give it room beside them.
    private func stackedToolbar(_ items: TabBottomBarItems) -> some View {
        VStack(spacing: 8) {
            omnibox(items, embedsAccessory: true)
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

    private func omnibox(_ items: TabBottomBarItems, embedsAccessory: Bool) -> some View {
        HStack(spacing: 8) {
            if let omniboxEditor, isEditingOmnibox {
                omniboxEditor.field()
                    .frame(maxWidth: .infinity)
                    .onKeyPress(.escape) {
                        endOmniboxEditing()
                        return .handled
                    }
            } else {
                omniboxLabel
                if embedsAccessory {
                    items.omniboxAccessory
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: 520)
        .frame(height: toolbarControlSize)
        .glassEffect(.regular, in: .capsule)
        .anchorPreference(key: TabOmniboxBoundsKey.self, value: .bounds) { $0 }
        .tabSwitchingGesture(for: store.selectedTabID, in: store, isEnabled: !isEditingOmnibox)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("adaptive.omnibox")
    }

    @ViewBuilder
    private var omniboxLabel: some View {
        let label = tabLabel(store.displayedTab)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
        if let omniboxEditor {
            Button {
                omniboxEditor.isEditing.wrappedValue = true
            } label: {
                label.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("l", modifiers: .command)
            .accessibilityIdentifier("adaptive.omnibox.edit")
        } else {
            label
        }
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
                geometry.size.width < 600 ? 120 : 160,
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
                            // Identity rather than no modifier, so selecting a
                            // tab never rebuilds the strip's views.
                            .glassEffect(
                                tab.id == store.selectedTabID ? .regular.interactive() : .identity,
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
