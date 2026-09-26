import EnhancedNavigation
import SwiftUI

/// What every page does to take part: reports its identity and keeps swipe
/// back under the hidden navigation bar. Pages are named for their bar items
/// by the router, outside the page, so items a page hangs off itself are
/// filed against it.
struct HarnessPage<Content: View>: View {

    @Environment(HarnessStore.self) private var store
    @Environment(\.harnessTabID) private var tabID

    let identity: HarnessPageIdentity
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(identity.title, systemImage: identity.symbolName)
                    .font(.largeTitle.bold())
                    .labelStyle(.titleOnly)
                    .harnessIdentifier("page.title")
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .toolbarVisibility(.hidden, for: .navigationBar)
        .interactivePopGesture(for: store)
        .onAppear {
            guard let tabID else { return }
            store.setPageIdentity(identity, for: tabID)
        }
    }
}

struct HarnessSection<Content: View>: View {

    let title: String
    var footer: String?
    @ViewBuilder let content: Content

    init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A read-out the UI tests look up by identifier.
struct HarnessValue: View {

    let title: String
    let value: String
    let identifier: String

    /// Not a `LabeledContent`, which merges the title and value into one
    /// element and so one label.
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .harnessIdentifier(identifier)
        }
    }
}

/// Every feature page ends with ways out of it.
struct FeatureFooter: View {

    @Environment(HarnessStore.self) private var store
    let feature: Feature

    var body: some View {
        HarnessSection("This Feature") {
            Button("Open in New Tab", systemImage: "plus.square.on.square") {
                store.openTab(at: .feature(feature))
            }
            .harnessIdentifier("feature.openInNewTab")
            Button("Show Tabs", systemImage: "square.grid.2x2") {
                store.showTabSwitcher()
            }
        }
    }
}

/// The pages behind the current one, each a way back to it.
struct BackHistoryList: View {

    @Environment(HarnessStore.self) private var store
    @Environment(\.harnessTabID) private var tabID

    var body: some View {
        let entries = tabID.map { store.backHistory(for: $0) } ?? []
        HarnessSection("Back History", footer: "backHistory(for:), nearest first. Tap one for popTo(depth:).") {
            if entries.isEmpty {
                Text("Nothing behind this page.")
                    .foregroundStyle(.secondary)
            }
            ForEach(entries, id: \.depth) { entry in
                Button {
                    store.popTo(depth: entry.depth)
                } label: {
                    LabeledContent {
                        Text("depth \(entry.depth)")
                    } label: {
                        Label(entry.identity.title, systemImage: entry.identity.symbolName)
                    }
                }
                .harnessIdentifier("history.\(entry.depth)")
            }
        }
    }
}

extension View {
    /// An identifier for the UI tests, given only while this view's tab is
    /// the one on screen. The tabs behind it stay mounted, and their pages
    /// and bars are still in the accessibility tree, so a lookup would
    /// otherwise find the same control in every live tab.
    func harnessIdentifier(_ identifier: String) -> some View {
        modifier(HarnessIdentifier(identifier: identifier))
    }
}

private struct HarnessIdentifier: ViewModifier {

    @Environment(HarnessStore.self) private var store
    @Environment(\.harnessTabID) private var tabID
    let identifier: String

    func body(content: Content) -> some View {
        let isShowing = tabID.map { $0 == store.selectedTabID } ?? true
        content.accessibilityIdentifier(isShowing ? identifier : "background.\(identifier)")
    }
}
