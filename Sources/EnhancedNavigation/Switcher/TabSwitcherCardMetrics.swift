import CoreGraphics

public enum TabSwitcherCardMetrics {

    /// For `TabZoomContainer`, so the page lands on the card's own corners.
    public static let cornerRadius: CGFloat = 16

    /// Portrait, but far shorter than the screen: at the screen's ratio a card
    /// runs most of the height of the switcher.
    static let previewAspectRatio: CGFloat = 0.75

    static let closeDistance: CGFloat = 90

    /// How far the selection ring sits outside the card's edge.
    static let selectionRingInset: CGFloat = 3
}
