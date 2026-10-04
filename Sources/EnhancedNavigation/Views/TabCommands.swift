import SwiftUI

/// Safari's tab commands in the iPadOS and Mac Catalyst menu bar, with their
/// hardware keyboard shortcuts. They act on the focused window's
/// `AdaptiveTabContainer`.
///
/// ```swift
/// WindowGroup { ... }
///     .commands { TabCommands() }
/// ```
///
/// Commands rather than shortcuts on hidden buttons: a view's ⌘W loses to the
/// menu bar's Close Window, which closes the whole scene instead of the tab,
/// and hidden buttons still show up to VoiceOver.
public struct TabCommands: Commands {

    @FocusedValue(\.tabCommandActions) private var actions

    public init() {}

    public var body: some Commands {
        CommandGroup(after: .newItem) {
            command("New Tab", "t", isEnabled: actions != nil) { $0.openTab() }
            // Ahead of Close Window while enabled. Disabled, ⌘W falls through
            // to it, so the last tab closes its window as in Safari.
            command("Close Tab", "w", isEnabled: actions?.canCloseTab ?? false) { $0.closeTab() }
        }
        CommandGroup(after: .toolbar) {
            command(
                actions?.isShowingOverview == true ? "Hide All Tabs" : "Show All Tabs",
                "\\",
                modifiers: [.command, .shift],
                isEnabled: actions != nil
            ) { $0.toggleOverview() }
            command("Back", "[", isEnabled: actions?.canGoBack ?? false) { $0.goBack() }
        }
        CommandGroup(before: .windowArrangement) {
            command("Show Previous Tab", "[", modifiers: [.command, .shift], isEnabled: canStep) {
                $0.selectAdjacentTab(-1)
            }
            command("Show Next Tab", "]", modifiers: [.command, .shift], isEnabled: canStep) {
                $0.selectAdjacentTab(1)
            }
            Divider()
            ForEach(1..<9) { number in
                command(
                    "Show Tab \(number)",
                    KeyEquivalent(Character("\(number)")),
                    isEnabled: canSelect && (actions?.tabCount ?? 0) >= number
                ) { $0.selectTab(number - 1) }
            }
            // Safari's ⌘9 is the last tab rather than the ninth.
            command("Show Last Tab", "9", isEnabled: canStep) { $0.selectTab($0.tabCount - 1) }
            Divider()
        }
    }

    private var canSelect: Bool {
        actions?.isOnPage ?? false
    }

    private var canStep: Bool {
        canSelect && (actions?.tabCount ?? 0) > 1
    }

    private func command(
        _ title: String,
        _ key: KeyEquivalent,
        modifiers: EventModifiers = .command,
        isEnabled: Bool,
        perform: @escaping (TabCommandActions) -> Void
    ) -> some View {
        Button(title) {
            if let actions { perform(actions) }
        }
        .keyboardShortcut(key, modifiers: modifiers)
        .disabled(!isEnabled)
    }
}

/// What the focused window's tabs allow, published for `TabCommands`, which
/// sits outside every window and cannot see a store of its own.
struct TabCommandActions {
    var tabCount: Int
    var isShowingOverview: Bool
    /// Tab-level commands other than opening one wait for the overview to
    /// close: selecting from the grid belongs to its cards, which rebuild a
    /// tab's path before the page grows out of them.
    var isOnPage: Bool
    var canCloseTab: Bool
    var canGoBack: Bool
    var openTab: () -> Void
    var closeTab: () -> Void
    var selectAdjacentTab: (Int) -> Void
    var selectTab: (Int) -> Void
    var goBack: () -> Void
    var toggleOverview: () -> Void
}

extension FocusedValues {
    @Entry var tabCommandActions: TabCommandActions?
}

/// Publishes a store's `TabCommandActions` to its window.
struct TabCommandActionsPublisher<Root: TabRoot, Identity: TabPageIdentity>: ViewModifier {

    let store: TabNavigationStore<Root, Identity>

    @State private var isDismissingOverview = false

    func body(content: Content) -> some View {
        content.focusedSceneValue(\.tabCommandActions, actions)
    }

    private var actions: TabCommandActions {
        let isOnPage = !store.isShowingTabSwitcher && !isDismissingOverview
        return TabCommandActions(
            tabCount: store.tabs.count,
            isShowingOverview: store.isShowingTabSwitcher,
            isOnPage: isOnPage,
            // Cards close tabs from the overview too, and a disabled Close
            // Tab would hand ⌘W to Close Window there.
            canCloseTab: !isDismissingOverview && store.canCloseTabs,
            canGoBack: isOnPage && store.displayedCanGoBack,
            openTab: openTab,
            closeTab: { store.close(store.selectedTabID) },
            selectAdjacentTab: { store.selectAdjacentTab(offset: $0) },
            selectTab: { store.selectTab(atPosition: $0) },
            goBack: { store.goBack() },
            toggleOverview: toggleOverview
        )
    }

    private func openTab() {
        guard !isDismissingOverview else { return }
        store.openTab()
        guard store.isShowingTabSwitcher else { return }
        // As the grid's own new tab button does: the new stack mounts before
        // the page grows to reveal it.
        isDismissingOverview = true
        Task { @MainActor in
            await FrameClock.waitForSettledFrames()
            store.hideTabSwitcher()
            isDismissingOverview = false
        }
    }

    private func toggleOverview() {
        guard !isDismissingOverview else { return }
        if store.isShowingTabSwitcher {
            store.hideTabSwitcher()
        } else {
            store.showTabOverview()
        }
    }
}
