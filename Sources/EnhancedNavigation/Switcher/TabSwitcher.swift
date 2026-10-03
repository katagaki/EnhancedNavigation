import SwiftUI

/// Safari's tab grid, for the `switcher` side of a `TabZoomContainer`. The
/// top bar's trailing slot is the app's, and is left out when empty.
public struct TabSwitcher<
    Root: TabRoot,
    Identity: TabPageIdentity,
    CardLabel: View,
    TopTrailingItem: View
>: View {

    public typealias Tab = NavigationTab<Root, Identity>

    private let store: TabNavigationStore<Root, Identity>
    private let strings: TabSwitcherStrings
    private let rebuildPath: TabNavigationStore<Root, Identity>.PathRebuilder
    private let cardLabel: (Tab) -> CardLabel
    private let placeholderIcon: TabSwitcherPlaceholderIcon
    private let topTrailingItem: TopTrailingItem
    @State private var isDismissing = false

    public init(
        store: TabNavigationStore<Root, Identity>,
        strings: TabSwitcherStrings = TabSwitcherStrings(),
        placeholderIcon: TabSwitcherPlaceholderIcon = .systemImage("square.on.square"),
        rebuildingPath rebuildPath: @escaping TabNavigationStore<Root, Identity>.PathRebuilder,
        @ViewBuilder cardLabel: @escaping (Tab) -> CardLabel,
        @ViewBuilder topTrailingItem: () -> TopTrailingItem
    ) {
        self.store = store
        self.strings = strings
        self.rebuildPath = rebuildPath
        self.cardLabel = cardLabel
        self.placeholderIcon = placeholderIcon
        self.topTrailingItem = topTrailingItem()
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: columns(for: geometry.size.width), spacing: 16) {
                        ForEach(store.tabs) { tab in
                            TabSwitcherCard(
                                store: store,
                                tab: tab,
                                isSelected: tab.id == store.selectedTabID,
                                closeLabel: strings.closeTab,
                                previewAspectRatio: previewAspectRatio(in: geometry.size),
                                onSelect: { select(tab.id) },
                                onClose: { close(tab.id) },
                                placeholderIcon: placeholderIcon,
                                label: cardLabel
                            )
                            .equatable()
                            .reorderableTab(id: tab.id, in: store)
                        }
                    }
                    .padding(16)
                }
                .endsTabReordering(in: store)
            }
            .navigationTitle(strings.title(store.tabs.count))
            .toolbarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .background(Color(uiColor: .secondarySystemGroupedBackground).ignoresSafeArea())
        }
        // The grid stays mounted for the whole session, so this runs once,
        // early, and every tab is rebuilt long before one is tapped.
        .task { await store.prewarmRestorablePaths(rebuilding: rebuildPath) }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button(role: .destructive) {
                    withAnimation(.smooth.speed(1.5)) {
                        store.closeAll()
                    }
                } label: {
                    Label(strings.closeAll, systemImage: "xmark.square.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
        if TopTrailingItem.self != EmptyView.self {
            ToolbarItem(placement: .topBarTrailing) {
                topTrailingItem
            }
        }
        if usesWideLayout {
            ToolbarItem(placement: .topBarTrailing) {
                newTabButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                doneButton
            }
        } else {
            ToolbarItem(placement: .bottomBar) {
                newTabButton
            }
            #if !os(visionOS)
            ToolbarSpacer(.flexible, placement: .bottomBar)
            #endif
            ToolbarItem(placement: .bottomBar) {
                doneButton
            }
        }
    }

    private var newTabButton: some View {
        Button {
            guard !isDismissing else { return }
            store.openTab()
            // Let the new stack mount before revealing it.
            dismissOnceSettled()
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel(strings.newTab)
    }

    private var doneButton: some View {
        Group {
            if usesWideLayout {
                Button {
                    store.hideTabSwitcher()
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Done")
            } else {
                Button(role: .confirm) { store.hideTabSwitcher() }
            }
        }
    }

    private func columns(for width: CGFloat) -> [GridItem] {
        if usesWideLayout {
            let count = width >= 1000 ? 3 : 2
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
        }
        return [GridItem(.adaptive(minimum: 150), spacing: 16)]
    }

    private func previewAspectRatio(in size: CGSize) -> CGFloat {
        guard usesWideLayout, size.width > 0, size.height > 0 else {
            return TabSwitcherCardMetrics.phonePreviewAspectRatio
        }
        return size.width / size.height
    }

    private var usesWideLayout: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }

    private func select(_ tabID: UUID) {
        guard !isDismissing else { return }
        // Normally already done by the prewarm; here for the tab tapped
        // before it got its turn, so the rebuild still happens before the
        // growth rather than in the middle of it.
        store.restorePathIfNeeded(for: tabID, rebuilding: rebuildPath)
        store.select(tabID)
        // Selecting a tab mounts its stack if it is not live, and hands the
        // bottom bar over either way. A tick late was not enough: that work
        // is drawn in the next frame, which was the growth's first, and the
        // page froze on the card before it moved. Behind the grid it is free.
        dismissOnceSettled()
    }

    private func dismissOnceSettled() {
        isDismissing = true
        Task { @MainActor in
            await FrameClock.waitForSettledFrames()
            store.hideTabSwitcher()
            isDismissing = false
        }
    }

    private func close(_ tabID: UUID) {
        withAnimation(.smooth.speed(1.5)) {
            store.close(tabID)
        }
    }
}

public extension TabSwitcher where TopTrailingItem == EmptyView {
    init(
        store: TabNavigationStore<Root, Identity>,
        strings: TabSwitcherStrings = TabSwitcherStrings(),
        placeholderIcon: TabSwitcherPlaceholderIcon = .systemImage("square.on.square"),
        rebuildingPath rebuildPath: @escaping TabNavigationStore<Root, Identity>.PathRebuilder,
        @ViewBuilder cardLabel: @escaping (Tab) -> CardLabel
    ) {
        self.init(
            store: store,
            strings: strings,
            placeholderIcon: placeholderIcon,
            rebuildingPath: rebuildPath,
            cardLabel: cardLabel,
            topTrailingItem: { EmptyView() }
        )
    }
}
