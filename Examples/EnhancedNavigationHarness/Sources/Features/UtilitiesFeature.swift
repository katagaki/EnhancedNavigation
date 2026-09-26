import EnhancedNavigation
import SwiftUI

struct UtilitiesFeaturePage: View {

    @Environment(HarnessStore.self) private var store
    @State private var settledFrameMilliseconds: Double?
    @State private var slot: PageSlot<Int, String>?
    @State private var visiblePage = 2

    let identity: HarnessPageIdentity

    var body: some View {
        HarnessPage(identity: identity) {
            HarnessSection("Snapshots", footer: "TabSnapshotView with TabSnapshotHeaderBlur, as the switcher's cards draw them. Snapshots are taken as the switcher opens.") {
                Button("Capture This Tab", systemImage: "camera") {
                    store.captureSelectedTabSnapshot()
                }
                .harnessIdentifier("utilities.capture")
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(store.tabs) { tab in
                            Color.clear
                                .frame(width: 90, height: 120)
                                .overlay(alignment: .top) {
                                    TabSnapshotView(store: store, tabID: tab.id) {
                                        Image(systemName: "testtube.2")
                                            .font(.title)
                                            .foregroundStyle(.tertiary)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                }
                                .overlay(alignment: .top) {
                                    TabSnapshotHeaderBlur(store: store, tabID: tab.id)
                                        .frame(height: 30)
                                }
                                .background(.fill.tertiary)
                                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }

            HarnessSection("Page Slots", footer: "A page below the visible one that reports nothing does not empty the slot the visible page filled.") {
                Picker("Visible page", selection: $visiblePage) {
                    Text("Page 1").tag(1)
                    Text("Page 2").tag(2)
                }
                .pickerStyle(.segmented)
                HStack {
                    Button("Page 2 fills") { PageSlot.fill(&slot, with: "Share", from: 2) }
                    Button("Page 1 clears") { PageSlot.fill(&slot, with: nil, from: 1) }
                    Button("Page 2 clears") { PageSlot.fill(&slot, with: nil, from: 2) }
                }
                .buttonStyle(.bordered)
                .font(.footnote)
                HarnessValue(
                    title: "Chrome shows",
                    value: slot?.value(forPageAt: visiblePage) ?? "Nothing",
                    identifier: "utilities.slot"
                )
            }

            HarnessSection("Frame Clock") {
                Button("Wait for Settled Frames", systemImage: "timer") {
                    Task {
                        let start = ContinuousClock.now
                        await FrameClock.waitForSettledFrames()
                        let elapsed = ContinuousClock.now - start
                        settledFrameMilliseconds = Double(elapsed.components.attoseconds) / 1e15
                            + Double(elapsed.components.seconds) * 1000
                    }
                }
                .harnessIdentifier("utilities.frameClock")
                HarnessValue(
                    title: "Took",
                    value: settledFrameMilliseconds.map { String(format: "%.1f ms", $0) } ?? "—",
                    identifier: "utilities.frameClockResult"
                )
            }

            HarnessSection("Metrics") {
                let insets = DisplayMetrics.safeAreaInsets
                LabeledContent("Safe area", value: "\(Int(insets.top)) / \(Int(insets.bottom))")
                LabeledContent("Window height", value: "\(Int(DisplayMetrics.windowHeight))")
                LabeledContent("Display corner radius", value: "\(Int(DisplayMetrics.displayCornerRadius))")
                LabeledContent("Bar item height", value: "\(Int(TabBottomBarMetrics.itemHeight))")
                LabeledContent("Bar item spacing", value: "\(Int(TabBottomBarMetrics.itemSpacing))")
                LabeledContent("Card corner radius", value: "\(Int(TabSwitcherCardMetrics.cornerRadius))")
            }

            FeatureFooter(feature: .utilities)
        }
    }
}
