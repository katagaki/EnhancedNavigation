import SwiftUI

/// A tab's last snapshot, matched to the view's width with the overflow
/// falling off the bottom, or `placeholder` for a tab that has none yet.
/// Filling would scale by height instead and crop the sides, because
/// cropping the status bar leaves a snapshot shorter in ratio than the screen.
public struct TabSnapshotView<Root: TabRoot, Identity: TabPageIdentity, Placeholder: View>: View {

    private let store: TabNavigationStore<Root, Identity>
    private let tabID: UUID
    private let placeholder: Placeholder

    public init(
        store: TabNavigationStore<Root, Identity>,
        tabID: UUID,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.store = store
        self.tabID = tabID
        self.placeholder = placeholder()
    }

    public var body: some View {
        if let snapshot = store.snapshots[tabID] {
            GeometryReader { proxy in
                Image(uiImage: snapshot)
                    .resizable()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.width / snapshot.widthToHeightRatio
                    )
            }
        } else {
            placeholder
        }
    }
}

/// The tab's snapshot again, blurred progressively down from its top edge,
/// for laying a title row over.
public struct TabSnapshotHeaderBlur<Root: TabRoot, Identity: TabPageIdentity>: View {

    private let store: TabNavigationStore<Root, Identity>
    private let tabID: UUID
    @State private var blurred: UIImage?
    @State private var width: CGFloat = 0

    public init(store: TabNavigationStore<Root, Identity>, tabID: UUID) {
        self.store = store
        self.tabID = tabID
    }

    public var body: some View {
        let snapshot = store.snapshots[tabID]
        GeometryReader { proxy in
            if let blurred {
                Image(uiImage: blurred)
                    .resizable()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.width / blurred.widthToHeightRatio
                    )
            }
        }
        .allowsHitTesting(false)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width.rounded()
        } action: { newWidth in
            width = newWidth
        }
        // Rendered again for a new width too: the blur is sized in the
        // points the card draws the snapshot at.
        .task(id: BlurKey(snapshot: snapshot.map(ObjectIdentifier.init), width: width)) {
            guard let snapshot, width > 0 else {
                blurred = nil
                return
            }
            if let cached = ProgressiveBlurRenderer.cached(for: snapshot, displayWidth: width) {
                blurred = cached
                return
            }
            // Cleared first: the previous snapshot's blur, over the new one,
            // shows the old page's title through the header.
            blurred = nil
            blurred = await ProgressiveBlurRenderer.render(snapshot, displayWidth: width)
        }
    }

    private struct BlurKey: Hashable {
        let snapshot: ObjectIdentifier?
        let width: CGFloat
    }
}
