import EnhancedNavigation
import SwiftUI

/// A page pushed with `navigationDestination(item:)` never enters the path,
/// so it is filed with the store as an overlay page for the chrome to name.
struct OverlayFeaturePage: View {

    struct Overlay: Identifiable, Hashable {
        let id = UUID()
        let name: String
    }

    @Environment(HarnessStore.self) private var store
    @Environment(\.harnessTabID) private var tabID
    @State private var overlay: Overlay?
    @State private var overlayPageID = UUID()

    let identity: HarnessPageIdentity

    var body: some View {
        HarnessPage(identity: identity) {
            HarnessSection("Try It", footer: "The bar names the overlay and its back button dismisses it, though the tab's path never changed.") {
                ForEach(["Overlay A", "Overlay B"], id: \.self) { name in
                    Button("Show \(name)") {
                        overlay = Overlay(name: name)
                    }
                    .harnessIdentifier("overlay.show.\(name.suffix(1))")
                }
            }
            HarnessSection("State") {
                HarnessValue(
                    title: "Overlay page",
                    value: store.displayedOverlayPage?.identity.title ?? "None",
                    identifier: "overlay.current"
                )
            }
            FeatureFooter(feature: .overlayPages)
        }
        .navigationDestination(item: $overlay) { overlay in
            OverlayDetailPage(name: overlay.name)
        }
        .onChange(of: overlay, initial: true) { _, overlay in
            guard let tabID else { return }
            let page = overlay.map { overlay in
                OverlayPage(id: overlayPageID, identity: HarnessPageIdentity.overlay(overlay.name)) {
                    self.overlay = nil
                }
            }
            store.setOverlayPage(page, id: overlayPageID, for: tabID)
        }
    }
}

private struct OverlayDetailPage: View {

    @Environment(HarnessStore.self) private var store
    let name: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(name)
                    .font(.largeTitle.bold())
                    .harnessIdentifier("overlay.detailTitle")
                Text("Not on the tab's path. Use the bar's back button, or swipe back.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .toolbarVisibility(.hidden, for: .navigationBar)
        .interactivePopGesture(for: store)
    }
}
