import SwiftUI

/// A full-screen tab switcher behind the tab stack, with the stack zooming
/// down onto the selected tab's card while the switcher is shown. Cards
/// report where they sit with `tabCardFrame(id:in:)`.
public struct TabZoomContainer<Root: TabRoot, Identity: TabPageIdentity, Switcher: View, Page: View>: View {

    public static var coordinateSpaceName: String { TabZoomCoordinateSpace.name }

    private let store: TabNavigationStore<Root, Identity>
    private let cardCornerRadius: CGFloat
    private let switcher: Switcher
    private let page: (CGFloat) -> Page

    /// `page` is handed the container's width.
    public init(
        store: TabNavigationStore<Root, Identity>,
        cardCornerRadius: CGFloat,
        @ViewBuilder switcher: () -> Switcher,
        @ViewBuilder page: @escaping (CGFloat) -> Page
    ) {
        self.store = store
        self.cardCornerRadius = cardCornerRadius
        self.switcher = switcher()
        self.page = page
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Kept opaque rather than hidden: a transparent subtree is not
                // laid out, so the cards never report the frames the page
                // collapses onto.
                switcher
                    .modifier(TabSwitcherInteraction(store: store))

                // The transition's state is read in the modifier alone: read
                // here, every flip of it re-runs `page`, and with it every
                // mounted tab's content, on the frame the zoom starts.
                page(proxy.size.width)
                    .modifier(TabZoomPlacement(
                        store: store,
                        size: proxy.size,
                        cardCornerRadius: cardCornerRadius
                    ))
            }
            .coordinateSpace(name: TabZoomCoordinateSpace.name)
        }
    }
}

private struct TabSwitcherInteraction<Root: TabRoot, Identity: TabPageIdentity>: ViewModifier {

    let store: TabNavigationStore<Root, Identity>

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(store.isShowingTabSwitcher)
            .accessibilityHidden(!store.isShowingTabSwitcher)
    }
}

private struct TabZoomPlacement<Root: TabRoot, Identity: TabPageIdentity>: ViewModifier {

    let store: TabNavigationStore<Root, Identity>
    let size: CGSize
    let cardCornerRadius: CGFloat

    /// Where the page's top sits in the window at rest. A page run edge to
    /// edge starts under the status bar, and hands no safe area on to what
    /// is laid over it.
    @State private var restingPageTop: CGFloat = 0

    func body(content: Content) -> some View {
        content
            // Read at rest only: mid-zoom, the frame is the scaled one.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY
            } action: { top in
                guard !store.isPageClipActive else { return }
                restingPageTop = top
            }
            // Hidden rather than covered: a covered page is still drawn.
            .opacity(store.isPageGrowingFromSnapshot ? 0 : 1)
            // Inside the zoom, so the snapshot takes exactly the page's place
            // on every frame and the swap back is pixel for pixel.
            .overlay {
                if let tabID = store.snapshotStandInTabID {
                    TabPageSnapshotStandIn(
                        store: store,
                        tabID: tabID,
                        top: max(DisplayMetrics.safeAreaInsets.top - restingPageTop, 0)
                    )
                    .transition(.opacity)
                }
            }
            .scaleEffect(pageScale, anchor: .topLeading)
            .offset(pageOffset)
            .clipShape(pageClipShape)
            .animation(store.configuration.switcherAnimation, value: store.isPageCollapsed)
            // No cross-fade: the swap happens where page and
            // snapshot are pixel for pixel the same.
            .opacity(store.isPageSwappedForSnapshot ? 0 : 1)
            // Keyed on the unanimated flag: SwiftUI picks which
            // toolbar to show from what is interactive, so the
            // animated one swaps the bar mid-transition.
            .allowsHitTesting(!store.isShowingTabSwitcher)
            .accessibilityHidden(store.isShowingTabSwitcher)
    }

    private var selectedCardFrame: CGRect? {
        store.isPageCollapsed ? store.collapseTarget : nil
    }

    private var pageScale: CGFloat {
        guard let card = selectedCardFrame, size.width > 0 else { return 1 }
        return card.width / size.width
    }

    /// The page's origin is where the snapshot's crop starts, so the card's
    /// origin is the whole offset; correcting for the safe area double-counts
    /// it and lifts the page clear of the snapshot.
    private var pageOffset: CGSize {
        guard let card = selectedCardFrame else { return .zero }
        return CGSize(width: card.minX, height: card.minY)
    }

    /// Only `progress` animates, so the rects it interpolates between have to
    /// outlive the transition: hence the store's target rather than the
    /// nil-when-open `selectedCardFrame`.
    private var pageClipShape: CollapsingPageClipShape {
        let screen = CGRect(
            origin: .zero,
            size: CGSize(width: size.width, height: max(size.height, DisplayMetrics.windowHeight))
        )
        return CollapsingPageClipShape(
            progress: store.isPageCollapsed ? 1 : 0,
            isActive: store.isPageClipActive,
            expanded: screen,
            collapsed: store.collapseTarget ?? screen,
            expandedRadius: DisplayMetrics.displayCornerRadius,
            collapsedRadius: cardCornerRadius
        )
    }
}

/// A tab's snapshot over the page's safe area, which is the region it was
/// captured from. The status bar and home indicator bands it leaves out are
/// filled with its own top row and bottom corner pixel, so they carry on the
/// page's background rather than flashing a flat one until the swap.
private struct TabPageSnapshotStandIn<Root: TabRoot, Identity: TabPageIdentity>: View {

    let store: TabNavigationStore<Root, Identity>
    let tabID: UUID
    let top: CGFloat

    var body: some View {
        if let snapshot = store.snapshots[tabID] {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    edge(of: snapshot, row: .top)
                        .frame(height: top)
                    Image(uiImage: snapshot)
                        .resizable()
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.width / snapshot.widthToHeightRatio
                        )
                    // The corner rather than the whole row: the row runs
                    // through the bottom bar's glass, which hangs into the band.
                    edge(of: snapshot, row: .bottom)
                        .frame(maxHeight: .infinity)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private enum Row {
        case top, bottom
    }

    @ViewBuilder
    private func edge(of snapshot: UIImage, row: Row) -> some View {
        if let image = snapshot.cgImage, let strip = image.cropping(to: CGRect(
            x: 0,
            y: row == .top ? 0 : image.height - 1,
            width: row == .top ? image.width : 1,
            height: 1
        )) {
            Image(decorative: strip, scale: snapshot.scale)
                .resizable()
        }
    }
}

enum TabZoomCoordinateSpace {
    static let name = "EnhancedNavigation.TabZoom"
}

public extension View {
    /// Reports the rect the page collapses onto, before the switcher is ever
    /// shown.
    func tabCardFrame<Root, Identity>(
        id: UUID,
        in store: TabNavigationStore<Root, Identity>
    ) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(
                        of: proxy.frame(in: .named(TabZoomCoordinateSpace.name)),
                        initial: true
                    ) { _, frame in
                        store.setCardFrame(frame, for: id)
                    }
            }
        }
    }
}
