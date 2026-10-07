import UIKit

public enum WindowSnapshotter {

    /// Rasterising the window is software drawing on the main thread, and
    /// its cost runs with the pixel count.
    private static let maximumScale: CGFloat = 2

    /// Captures the key window below the status bar as it is on screen right
    /// now, scaled down to `width` points across. The home indicator band is
    /// kept: a bottom bar's glass runs down into it, and a page grown back out
    /// as its snapshot would otherwise lose that band until the swap.
    public static func captureVisiblePage(width targetWidth: CGFloat) -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first, window.bounds.width > 0 else { return nil }

        let insets = window.safeAreaInsets
        let scale = targetWidth / window.bounds.width
        let height = window.bounds.height - insets.top
        guard height > 0 else { return nil }

        let size = CGSize(width: targetWidth, height: height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        // Capped: a 3x card is invisibly sharper than a 2x one and costs more
        // than twice as much to draw. Read from the trait collection because
        // visionOS has no UIScreen.
        format.scale = min(window.traitCollection.displayScale, maximumScale)
        // No alpha to blend or carry: the page behind is opaque anyway.
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            // Drawn shifted up so the status bar falls off the top of the
            // canvas.
            window.drawHierarchy(
                in: CGRect(
                    x: 0,
                    y: -insets.top * scale,
                    width: targetWidth,
                    height: window.bounds.height * scale
                ),
                afterScreenUpdates: false
            )
        }
    }
}
