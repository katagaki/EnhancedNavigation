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

    /// How far down the title row reaches, in the same points: the strip
    /// measured to pick light or dark glyphs for it.
    nonisolated static let titleDepth: Double = 40

    /// Above this, the strip behind the title reads as light and takes dark
    /// glyphs. Averaged over the strip, so a busy page sits mid-range.
    nonisolated static let lightLuminance: Double = 0.55

    private final class Entry {
        let displayWidth: CGFloat
        let image: UIImage
        let isTitleBackdropLight: Bool

        init(displayWidth: CGFloat, image: UIImage, isTitleBackdropLight: Bool) {
            self.displayWidth = displayWidth
            self.image = image
            self.isTitleBackdropLight = isTitleBackdropLight
        }
    }

    private nonisolated(unsafe) static let cache = NSCache<UIImage, Entry>()
    private nonisolated static let context = CIContext()

    /// The blur already rendered for `image` drawn `displayWidth` points wide.
    public static func cached(for image: UIImage, displayWidth: CGFloat) -> UIImage? {
        entry(for: image, displayWidth: displayWidth)?.image
    }

    /// Whether the blurred strip behind a title row on `image` is light, once
    /// its blur is rendered for `displayWidth`.
    static func isTitleBackdropLight(for image: UIImage, displayWidth: CGFloat) -> Bool? {
        entry(for: image, displayWidth: displayWidth)?.isTitleBackdropLight
    }

    private static func entry(for image: UIImage, displayWidth: CGFloat) -> Entry? {
        guard let entry = cache.object(forKey: image),
              entry.displayWidth == displayWidth.rounded() else { return nil }
        return entry
    }

    /// Blurs `image` for drawing `displayWidth` points wide.
    public static func render(_ image: UIImage, displayWidth: CGFloat) async -> UIImage? {
        let displayWidth = displayWidth.rounded()
        guard displayWidth > 0 else { return nil }
        let result = await Task.detached(priority: .userInitiated) {
            blur(image, displayWidth: displayWidth)
        }.value
        guard let result else { return nil }
        cache.setObject(
            Entry(displayWidth: displayWidth, image: result.image, isTitleBackdropLight: result.isTitleBackdropLight),
            forKey: image
        )
        return result.image
    }

    private nonisolated static func blur(
        _ image: UIImage,
        displayWidth: CGFloat
    ) -> (image: UIImage, isTitleBackdropLight: Bool)? {
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
        let titleStrip = CGRect(
            x: extent.minX,
            y: extent.maxY - titleDepth * pixelsPerPoint,
            width: extent.width,
            height: titleDepth * pixelsPerPoint
        ).intersection(extent)
        return (
            UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation),
            luminance(of: output, in: titleStrip) > lightLuminance
        )
    }

    /// The strip's average colour, weighted as the eye weighs its channels.
    private nonisolated static func luminance(of image: CIImage, in rect: CGRect) -> Double {
        let average = CIFilter.areaAverage()
        average.inputImage = image
        average.extent = rect
        guard let output = average.outputImage else { return 0 }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        return (0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])) / 255
    }
}

extension UIImage {
    var widthToHeightRatio: CGFloat {
        guard size.height > 0 else { return 1 }
        return size.width / size.height
    }
}
