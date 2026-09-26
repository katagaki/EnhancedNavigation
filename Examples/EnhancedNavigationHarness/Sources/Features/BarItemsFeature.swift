import EnhancedNavigation
import SwiftUI

/// A page's own controls in the custom bar, the way `.toolbar` puts them in
/// the system one. They belong to this page: push another and they go,
/// pop back and they return.
struct BarItemsFeaturePage: View {

    @State private var showsLeading = true
    @State private var showsTrailing = true
    @State private var showsAccessory = true
    @State private var isFavourite = false
    @State private var taps = 0

    let identity: HarnessPageIdentity

    var body: some View {
        HarnessPage(identity: identity) {
            HarnessSection("Items", footer: "tabBottomBarItem(.leading), tabBottomBarItem(.trailing) and tabOmniboxAccessory, filed against this page by tabPage(pathToken:).") {
                Toggle("Leading item", isOn: $showsLeading)
                    .harnessIdentifier("barItems.leadingToggle")
                Toggle("Trailing item", isOn: $showsTrailing)
                    .harnessIdentifier("barItems.trailingToggle")
                Toggle("Omnibox accessory", isOn: $showsAccessory)
                    .harnessIdentifier("barItems.accessoryToggle")
                HarnessValue(title: "Taps on bar items", value: "\(taps)", identifier: "barItems.taps")
            }

            HarnessSection("Page Ownership") {
                NavigationLink("Push Item 1: the items leave with this page", value: HarnessDestination.item(1))
                    .harnessIdentifier("barItems.push")
            }

            FeatureFooter(feature: .barItems)
        }
        .tabBottomBarItem(.leading, isEnabled: showsLeading) {
            Button("Refresh", systemImage: "arrow.clockwise") { taps += 1 }
                .harnessIdentifier("barItems.leading")
        }
        .tabBottomBarItem(.trailing, isEnabled: showsTrailing) {
            Button("Share", systemImage: "square.and.arrow.up") { taps += 1 }
                .harnessIdentifier("barItems.trailing")
        }
        .tabOmniboxAccessory(isEnabled: showsAccessory) {
            Button(
                isFavourite ? "Unfavourite" : "Favourite",
                systemImage: isFavourite ? "star.fill" : "star"
            ) {
                isFavourite.toggle()
                taps += 1
            }
            .harnessIdentifier("barItems.accessory")
        }
    }
}
