# EnhancedNavigation

Safari-style tabs for SwiftUI, each tab with its own `NavigationPath`.

- `TabNavigationStore<Root, Identity>`: tabs, selection, a live-tab LRU, back history, persistence and restoration down to the page each tab was left on, and the tab switcher's zoom state.
- `TabRoot`: what a tab is parked on, stored as a string token.
- `TabPageIdentity`: what a page reports about itself, since a `NavigationPath` cannot be read back. Its `pathToken` is how the page is pushed again after a relaunch.
- `LiveTabStack`: mounts the recently used tabs and hides the rest.
- `TabZoomContainer`, `.tabCardFrame(id:in:)`, `TabSnapshotView`, `TabSnapshotHeaderBlur`: a full-screen switcher that the page zooms down onto.
- `TabSwitcher`: the switcher's tab grid, with cards the page lands on, swipe to close, reordering, and the app's own card label, placeholder icon, strings and bottom bar leading item.
- `.interactivePopGesture(for:)`: keeps swipe back working with the navigation bar hidden.
- `.tabBottomBar { }`, `TabBottomBarMetrics`: a custom bar laid out like the system `.bottomBar`, keeping the soft scroll edge effect beneath it.
- `.reorderableTab(id:in:)`, `PageSlot`, `OverlayPage`, `FrameClock`, `DisplayMetrics`.

```swift
let store = TabNavigationStore<Location, PageIdentity>.restored(
    configuration: TabStoreConfiguration(
        persistenceKeyPrefix: "Browser",
        snapshotDirectoryName: "TabSnapshots"
    )
)

LiveTabStack(store: store) { tab in
    NavigationStack(path: store.pathBinding(for: tab.id)) {
        RootView(root: tab.root)
    }
    .interactivePopGesture(for: store)
}
.task { store.loadPersistedSnapshots() }
```

Pages report themselves with `store.setPageIdentity(_:for:)`. Restore pushed pages with `restorePathIfNeeded(for:rebuilding:)`, which hands back each saved path token for the app to turn into a value again.

The switcher sits behind the stack in a `TabZoomContainer`. `placeholderIcon` is an SF Symbol (`.systemImage`) or an asset catalog image (`.asset(_:bundle:)`) for tabs with no snapshot yet. Leave out `bottomLeadingItem` to keep the bottom bar's leading slot empty.

```swift
TabZoomContainer(store: store, cardCornerRadius: TabSwitcherCardMetrics.cornerRadius) {
    TabSwitcher(store: store, placeholderIcon: .systemImage("safari"), rebuildingPath: rebuildPath) { tab in
        Text(tab.pageIdentity?.title ?? "New Tab")
    } bottomLeadingItem: {
        Button("Profile", systemImage: "person.crop.circle") { isShowingProfile = true }
    }
} page: { _ in
    LiveTabStack(store: store) { tab in ... }
}
```

For a bottom bar of the app's own in place of the system `.bottomBar`, hang it off each tab's `NavigationStack` with `.tabBottomBar { }`. It sits where the system bar would, stays put while pages push and pop, and scroll views beneath it keep the soft edge effect.

```swift
NavigationStack(path: store.pathBinding(for: tab.id)) { ... }
    .tabBottomBar {
        HStack(spacing: TabBottomBarMetrics.itemSpacing) { ... }
    }
```

Pages can put their own controls in that bar, the way `.toolbar` does for the system one. Use `.tabBottomBar(for:in:)` so the bar's layout is handed what the visible page declared, and name each page with `.tabPage(pathToken:)`, the token it reports in its identity. A page's items are filed against it, so a page underneath cannot take the bar over as a pop reveals it, and they go when the page leaves the stack.

```swift
NavigationStack(path: store.pathBinding(for: tab.id)) { ... }
    .tabBottomBar(for: tab.id, in: store) { items in
        BackButton()
        HStack {
            PageName()
            items.omniboxAccessory
        }
        .glassEffect(in: .capsule)
        TabsButton()
    }

ArticleView(article)
    .tabOmniboxAccessory {
        Menu("More", systemImage: "ellipsis") { ... }
    }
    .tabPage(pathToken: .article(article.id))
```

`.tabOmniboxAccessory` takes a `Button` or `Menu` and draws its symbol alone. `.tabBottomBarItem(.leading)` and `.tabBottomBarItem(.trailing)` add items beside the omnibox.

`Examples/EnhancedNavigationDemo` is a sample app: `xcodegen generate` in that folder, then build. Launch with `-BarStyle system` to compare against the system bar.
