import EnhancedNavigation
import SwiftUI

struct NavigationFeaturePage: View {

    @Environment(HarnessStore.self) private var store
    @Environment(\.harnessTabID) private var tabID

    let identity: HarnessPageIdentity

    var body: some View {
        HarnessPage(identity: identity) {
            HarnessSection("Depth") {
                HarnessValue(
                    title: "Pages on this tab's path",
                    value: "\(tabID.map { store.displayedTab(for: $0).path.count } ?? 0)",
                    identifier: "navigation.depth"
                )
            }

            HarnessSection("Push", footer: "Swipe from the leading edge to go back: interactivePopGesture(for:) keeps it working with the navigation bar hidden.") {
                NavigationLink("Push Item 1 with a NavigationLink", value: HarnessDestination.item(1))
                    .harnessIdentifier("navigation.link")
                Button("Push Item 100 with push(_:)") {
                    store.push(HarnessDestination.item(100))
                }
                .harnessIdentifier("navigation.push")
                Button("Navigate to the Media root with navigate(to:)") {
                    store.navigate(to: HarnessRoot.feature(.media))
                }
                .harnessIdentifier("navigation.navigate")
            }

            HarnessSection("Deep Links", footer: "openTab(pushing:) lands a deep link in a tab of its own.") {
                Button("Open Item 7 in a New Tab") {
                    store.openTab(pushing: HarnessDestination.item(7))
                }
                .harnessIdentifier("navigation.deepLink")
            }

            FeatureFooter(feature: .navigation)
        }
    }
}

/// A page that can go deeper, back, or all the way back.
struct ItemPage: View {

    @Environment(HarnessStore.self) private var store
    @Environment(\.harnessTabID) private var tabID

    let number: Int

    var body: some View {
        HarnessPage(identity: .item(number)) {
            ItemCard(number: number)

            HarnessSection("Go") {
                NavigationLink("Push Item \(number + 1)", value: HarnessDestination.item(number + 1))
                    .harnessIdentifier("item.pushNext")
                Button("Go Back") { store.goBack() }
                    .harnessIdentifier("item.back")
                Button("Pop to Root") { store.popTo(depth: 0) }
                    .harnessIdentifier("item.popToRoot")
            }

            BackHistoryList()
        }
    }
}

struct ItemCard: View {

    let number: Int

    var body: some View {
        let hue = Double((number * 37) % 360) / 360
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            Text(verbatim: "Item \(number)")
                .font(.title2.bold())
            Text("A page on this tab's path, restored by its token after a relaunch.")
                .font(.subheadline)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.8, brightness: 0.9),
                    Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.9, brightness: 0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 20, style: .continuous)
        )
    }
}

struct BackHistoryFeaturePage: View {

    let identity: HarnessPageIdentity

    var body: some View {
        HarnessPage(identity: identity) {
            HarnessSection("Try It") {
                Text("Push a few items, then press and hold the back button in the bar. Every page behind the current one is listed, nearest first, and choosing one pops straight to it.")
                NavigationLink("Push Item 1", value: HarnessDestination.item(1))
                    .harnessIdentifier("backHistory.push")
            }
            BackHistoryList()
            FeatureFooter(feature: .backHistory)
        }
    }
}
