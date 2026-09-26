import EnhancedNavigation
import SwiftUI

struct DemoPage: View {

    @Environment(DemoStore.self) private var store
    @Environment(\.demoTabID) private var tabID

    let identity: DemoPageIdentity
    let seed: Int

    var body: some View {
        let page = ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text(identity.title)
                    .font(.largeTitle.bold())
                    .padding(.top, 8)
                ForEach(1...24, id: \.self) { index in
                    let number = seed * 10 + index
                    NavigationLink(value: number) {
                        DemoCard(number: number)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("card-\(index)")
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))
        .toolbarVisibility(.hidden, for: .navigationBar)
        .interactivePopGesture(for: store)
        .onAppear {
            guard let tabID else { return }
            store.setPageIdentity(identity, for: tabID)
        }

        if DemoBarStyle.current == .system, let tabID {
            page
                .toolbar {
                    DemoSystemBottomBar(store: store, tabID: tabID)
                }
                .toolbarVisibility(
                    store.isPageSwappedForSnapshot ? .hidden : .automatic,
                    for: .bottomBar
                )
        } else {
            page
        }
    }
}

struct DemoCard: View {

    let number: Int

    var body: some View {
        let hue = Double((number * 37) % 360) / 360
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            Text(verbatim: "Item \(number)")
                .font(.title2.bold())
            Text("Tap to push another page onto this tab's stack.")
                .font(.subheadline)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
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
