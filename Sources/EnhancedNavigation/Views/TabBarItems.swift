import SwiftUI

/// The items the visible page has declared, handed to the app's bar layout.
/// Each renders nothing when the page declared none.
public struct TabBottomBarItems {

    let leadingBox: TabBarItemBox?
    let trailingBox: TabBarItemBox?
    let omniboxAccessoryBox: TabBarItemBox?

    public var hasLeading: Bool { leadingBox != nil }
    public var hasTrailing: Bool { trailingBox != nil }
    public var hasOmniboxAccessory: Bool { omniboxAccessoryBox != nil }

    @ViewBuilder
    public var leading: some View {
        if let leadingBox { TabBarItemContent(box: leadingBox) }
    }

    @ViewBuilder
    public var trailing: some View {
        if let trailingBox { TabBarItemContent(box: trailingBox) }
    }

    @ViewBuilder
    public var omniboxAccessory: some View {
        if let omniboxAccessoryBox { TabBarItemContent(box: omniboxAccessoryBox) }
    }
}

public extension View {
    /// A bar like `tabBottomBar(_:)` whose layout is handed the items the
    /// visible page declared with `tabBottomBarItem` and
    /// `tabOmniboxAccessory`. Apply it to the tab's `NavigationStack`.
    func tabBottomBar<Root, Identity, Bar: View>(
        for tabID: UUID,
        in store: TabNavigationStore<Root, Identity>,
        @ViewBuilder _ bar: @escaping (TabBottomBarItems) -> Bar
    ) -> some View {
        environment(\.tabBarItemRegistrar, TabBarItemRegistrar(registry: store.barItems, tabID: tabID))
            .tabBottomBar {
                TabBottomBarItemsReader(store: store, tabID: tabID, bar: bar)
            }
    }

    /// Names the page the modifiers under it belong to: the same token the
    /// page reports in its `TabPageIdentity`, and nil for a tab's root.
    ///
    /// Also clears the tab's bottom bar: a `NavigationStack` lays its pages
    /// out with the window's safe area rather than its own, so the inset a
    /// `tabBottomBar` adds never reaches them, and the end of the page would
    /// otherwise scroll no further than underneath the bar.
    func tabPage<Token: Hashable>(pathToken: Token?) -> some View {
        environment(\.tabPagePathToken, TabPagePathToken(value: pathToken.map(AnyHashable.init)))
            .modifier(TabBottomBarPageInsetModifier())
    }

    /// Puts an item in the tab's bottom bar while this page is the one
    /// showing, the way `.toolbar` does for the system bar. Filed against the
    /// page, so a page underneath cannot take the bar over as a pop reveals
    /// it. Does nothing outside a `tabBottomBar(for:in:_:)`.
    func tabBottomBarItem<Item: View>(
        _ placement: TabBottomBarItemPlacement,
        isEnabled: Bool = true,
        @ViewBuilder _ item: @escaping () -> Item
    ) -> some View {
        modifier(TabBarItemModifier(placement: placement, isEnabled: isEnabled, item: item))
    }

    /// Puts a button or menu inside the omnibox, after the page's name, while
    /// this page is the one showing. Written the way it would be for a
    /// toolbar, `Button(_:systemImage:action:)` or
    /// `Menu(_:systemImage:content:)`: the omnibox draws the symbol alone and
    /// keeps the title for VoiceOver.
    func tabOmniboxAccessory<Accessory: View>(
        isEnabled: Bool = true,
        @ViewBuilder _ accessory: @escaping () -> Accessory
    ) -> some View {
        tabBottomBarItem(.omniboxAccessory, isEnabled: isEnabled) {
            accessory()
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.system(size: 17))
                // A tap target taller than the glyph, and no wider, so the
                // glyph sits flush with the omnibox's own padding.
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
    }
}

private struct TabBottomBarItemsReader<Root: TabRoot, Identity: TabPageIdentity, Bar: View>: View {

    let store: TabNavigationStore<Root, Identity>
    let tabID: UUID
    let bar: (TabBottomBarItems) -> Bar

    var body: some View {
        let pathToken = store.displayedPathToken(for: tabID).map(AnyHashable.init)
        bar(TabBottomBarItems(
            leadingBox: box(.leading, pathToken),
            trailingBox: box(.trailing, pathToken),
            omniboxAccessoryBox: box(.omniboxAccessory, pathToken)
        ))
    }

    private func box(_ placement: TabBottomBarItemPlacement, _ pathToken: AnyHashable?) -> TabBarItemBox? {
        store.barItems.box(for: .init(pathToken: pathToken, placement: placement), in: tabID)
    }
}

private struct TabBarItemContent: View {

    let box: TabBarItemBox

    var body: some View {
        let _ = box.generation
        box.content()
    }
}

private struct TabBarItemModifier<Item: View>: ViewModifier {

    @Environment(\.tabBarItemRegistrar) private var registrar
    @Environment(\.tabPagePathToken) private var page
    @State private var box = TabBarItemBox { AnyView(EmptyView()) }
    let placement: TabBottomBarItemPlacement
    let isEnabled: Bool
    let item: () -> Item

    func body(content: Content) -> some View {
        // Handed over on every pass rather than on change: the item reads the
        // page's own state, which this modifier has no way to compare.
        let item = self.item
        box.update { AnyView(item()) }
        return content
            .onAppear { sync() }
            .onChange(of: isEnabled) { sync() }
            .onChange(of: page) { sync() }
    }

    private func sync() {
        guard let registrar, let page else { return }
        let key = TabBarItemRegistry.Key(pathToken: page.value, placement: placement)
        if isEnabled {
            registrar.registry.register(box, for: key, in: registrar.tabID)
        } else {
            registrar.registry.unregister(box, for: key, in: registrar.tabID)
        }
    }
}

struct TabBarItemRegistrar: Equatable {
    let registry: TabBarItemRegistry
    let tabID: UUID

    static func == (lhs: TabBarItemRegistrar, rhs: TabBarItemRegistrar) -> Bool {
        lhs.registry === rhs.registry && lhs.tabID == rhs.tabID
    }
}

struct TabPagePathToken: Equatable {
    let value: AnyHashable?
}

private struct TabBarItemRegistrarKey: EnvironmentKey {
    static let defaultValue: TabBarItemRegistrar? = nil
}

private struct TabPagePathTokenKey: EnvironmentKey {
    static let defaultValue: TabPagePathToken? = nil
}

extension EnvironmentValues {
    var tabBarItemRegistrar: TabBarItemRegistrar? {
        get { self[TabBarItemRegistrarKey.self] }
        set { self[TabBarItemRegistrarKey.self] = newValue }
    }

    var tabPagePathToken: TabPagePathToken? {
        get { self[TabPagePathTokenKey.self] }
        set { self[TabPagePathTokenKey.self] = newValue }
    }
}
