# EnhancedNavigation

Safari-style tabs for SwiftUI, each tab with its own `NavigationPath`.

| API | What it does |
| --- | --- |
| `TabNavigationStore<Root, Identity>` | Tabs, selection, live-tab LRU, back history, persistence and restoration, switcher zoom state. |
| `TabRoot` | What a tab is parked on, stored as a string token. |
| `TabPageIdentity` | What a page reports about itself. Its `pathToken` re-pushes the page after a relaunch. |
| `LiveTabStack` | Mounts recently used tabs and hides the rest. |
| `TabZoomContainer`, `TabSwitcher` | A full-screen tab grid the page zooms down onto. |
| `AdaptiveTabContainer` | Keeps the iPhone zoom UI and adds a Safari-style tab strip and card overview on iPad and Mac Catalyst. |
| `.tabBottomBar { }` | A custom bottom bar laid out like the system `.bottomBar`. |
| `.interactivePopGesture(for:)` | Keeps swipe back working with the navigation bar hidden. |

Also: `.tabCardFrame(id:in:)`, `TabSnapshotView`, `TabSnapshotHeaderBlur`, `TabBottomBarMetrics`, `.reorderableTab(id:in:)`, `PageSlot`, `OverlayPage`, `FrameClock`, `DisplayMetrics`.

## Tabs

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

- Pages report themselves with `store.setPageIdentity(_:for:)`.
- `restorePathIfNeeded(for:rebuilding:)` restores pushed pages, handing back each saved path token for the app to turn into a value.

## Tab switcher

```swift
TabZoomContainer(store: store, cardCornerRadius: TabSwitcherCardMetrics.cornerRadius) {
    TabSwitcher(store: store, placeholderIcon: .systemImage("safari"), rebuildingPath: rebuildPath) { tab in
        Text(tab.pageIdentity?.title ?? "New Tab")
    } topTrailingItem: {
        Button("Profile", systemImage: "person.crop.circle") { isShowingProfile = true }
    }
} page: { _ in
    LiveTabStack(store: store) { tab in ... }
}
```

- `placeholderIcon` is `.systemImage(_:)` or `.asset(_:bundle:)`, shown for tabs with no snapshot yet.
- `topTrailingItem` is optional.

For a shell that adapts between iPhone and iPad, use `AdaptiveTabContainer` in
place of `TabZoomContainer` and provide a short label for each tab:

```swift
AdaptiveTabContainer(store: store, cardCornerRadius: TabSwitcherCardMetrics.cornerRadius) {
    TabSwitcher(store: store, rebuildingPath: rebuildPath) { tab in
        Text(tab.pageIdentity?.title ?? "New Tab")
    }
} page: { _ in
    LiveTabStack(store: store) { tab in ... }
} tabLabel: { tab in
    Text(tab.pageIdentity?.title ?? "New Tab")
}
```

The wide layout shows a tab strip after a second tab opens. Its page zooms into
the selected overview card with the same transition as iPhone. Overview cards
follow the iPad or Catalyst window's aspect ratio as it rotates or resizes.
Native macOS is not currently a package target; Mac Catalyst uses the wide
layout. On iPad and
Catalyst, register each tab's page controls with `.registersTabBarItems(for:in:)`
so the top bar shows
them. The bottom bar remains the iPhone presentation.

## Bottom bar

Attach a bar to each tab's `NavigationStack`. It stays put while pages push and pop, and keeps the soft scroll edge effect.

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
```

To switch tabs by swiping horizontally, apply `.tabSwitchingGesture(for: tab.id,
in: store, isEnabled: !isEditingAddress)` to your omnibox. Left selects the next
tab and right selects the previous tab in the current order. Selection commits
on release after a horizontal drag; short drags leave the current tab selected.
The ends do not wrap or open tabs. The iPad and Catalyst omnibox in
`AdaptiveTabContainer` includes this gesture automatically. The modifier has no
effect on visionOS.

Pages add their own controls to it:

```swift
ArticleView(article)
    .tabOmniboxAccessory {
        Menu("More", systemImage: "ellipsis") { ... }
    }
    .tabPage(pathToken: .article(article.id))
```

- `.tabOmniboxAccessory` takes a `Button` or `Menu` and shows only its symbol.
- `.tabBottomBarItem(.leading)` / `.tabBottomBarItem(.trailing)` add items beside the omnibox.
- A page's items belong to that page and disappear when it leaves the stack.
- **Mark every page under the bar with `.tabPage(pathToken:)`**, even pages with no items, so their content scrolls clear of the bar.
- For a bar that ignores page items, use `.tabBottomBar { }` without `for:in:`.

## Example app

```sh
cd Examples/EnhancedNavigationDemo
xcodegen generate
```

Launch with `-BarStyle system` to compare against the system bar.

## Testing

Unit tests need UIKit, so run them on a simulator:

```sh
xcodebuild test -scheme EnhancedNavigation -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

`Examples/EnhancedNavigationHarness` has a page for every feature, a live inspector of the store's state, and UI tests covering each feature end to end:

```sh
cd Examples/EnhancedNavigationHarness
xcodegen generate
xcodebuild test -scheme EnhancedNavigationHarness -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Launch arguments: `-ResetState YES` starts fresh; `-LiveTabLimit <n>` sets how many tabs stay mounted (default 3).
