import CoreImage.CIFilterBuiltins
import UIKit

/// Blurs an image progressively down from its top edge, so a title row reads
/// over a busy snapshot. Rendered once per image rather than as a live
/// filter: every card in a grid would otherwise re-blur on each frame of a
/// scroll.
public enum ProgressiveBlurRenderer {

    /// In the points the image is drawn at, so a large iPad snapshot on a
    /// card blurs no harder than a phone's.
    nonisolated static let radius: Double = 1.2

    /// How far down the blur reaches, in the points the image is drawn at:
    /// just past a card's title row, whatever the card's shape.
    nonisolated static let depth: Double = 64

    private final class Entry {
        let displayWidth: CGFloat
        let image: UIImage

        init(displayWidth: CGFloat, image: UIImage) {
            self.displayWidth = displayWidth
            self.image = image
        }
    }

    private nonisolated(unsafe) static let cache = NSCache<UIImage, Entry>()
    private nonisolated static let context = CIContext()

    /// The blur already rendered for `image` drawn `displayWidth` points wide.
    public static func cached(for image: UIImage, displayWidth: CGFloat) -> UIImage? {
        guard let entry = cache.object(forKey: image),
              entry.displayWidth == displayWidth.rounded() else { return nil }
        return entry.image
    }

    /// Blurs `image` for drawing `displayWidth` points wide.
    public static func render(_ image: UIImage, displayWidth: CGFloat) async -> UIImage? {
        let displayWidth = displayWidth.rounded()
        guard displayWidth > 0 else { return nil }
        let result = await Task.detached(priority: .userInitiated) {
            blur(image, displayWidth: displayWidth)
        }.value
        if let result {
            cache.setObject(Entry(displayWidth: displayWidth, image: result), forKey: image)
        }
        return result
    }

    private nonisolated static func blur(_ image: UIImage, displayWidth: CGFloat) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let input = CIImage(cgImage: cgImage)
        let extent = input.extent
        let pixelsPerPoint = extent.width / displayWidth

        // Core Image's origin is the bottom left, so the top edge is maxY.
        let mask = CIFilter.linearGradient()
        mask.point0 = CGPoint(x: 0, y: extent.maxY)
        mask.point1 = CGPoint(x: 0, y: extent.maxY - depth * pixelsPerPoint)
        mask.color0 = CIColor.white
        mask.color1 = CIColor.black

        let filter = CIFilter.maskedVariableBlur()
        // Clamped first, or the blur pulls transparent black in at the edges.
        filter.inputImage = input.clampedToExtent()
        filter.mask = mask.outputImage?.cropped(to: extent)
        filter.radius = Float(radius * pixelsPerPoint)

        guard let output = filter.outputImage?.cropped(to: extent),
              let rendered = context.createCGImage(output, from: extent) else { return nil }
        return UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation)
    }
}

extension UIImage {
    var widthToHeightRatio: CGFloat {
        guard size.height > 0 else { return 1 }
        return size.width / size.height
    }
}
