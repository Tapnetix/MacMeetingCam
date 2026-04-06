import Foundation
import CoreVideo
import CoreImage

/// Composites video frames with background effects (blur, remove, replace)
/// using Core Image filters and mask-based blending.
final class Compositor {

    // MARK: - Properties

    private let ciContext: CIContext

    // MARK: - Init

    init() {
        self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
    }

    // MARK: - Public API

    /// Applies a background effect to the given frame using the segmentation mask.
    /// - Parameters:
    ///   - frame: The original video frame in BGRA format.
    ///   - mask: The segmentation mask (OneComponent8). White = foreground, black = background.
    ///   - mode: The background effect mode (blur, remove, replace).
    ///   - blurIntensity: Normalized blur intensity (0.0-1.0). Maps to 0-30px Gaussian blur radius.
    ///   - edgeSoftness: Normalized edge softness (0.0-1.0). Maps to 0-10px feather radius on the mask.
    ///   - backgroundImage: Optional replacement background image (used in replace mode).
    /// - Returns: A composited CVPixelBuffer matching the input frame dimensions, or nil on failure.
    func apply(
        frame: CVPixelBuffer,
        mask: CVPixelBuffer,
        mode: BackgroundMode,
        blurIntensity: Double,
        edgeSoftness: Double,
        backgroundImage: CIImage?
    ) -> CVPixelBuffer? {
        let frameImage = CIImage(cvPixelBuffer: frame)
        let maskImage = CIImage(cvPixelBuffer: mask)

        let frameWidth = CVPixelBufferGetWidth(frame)
        let frameHeight = CVPixelBufferGetHeight(frame)
        let frameExtent = CGRect(x: 0, y: 0, width: frameWidth, height: frameHeight)

        // Scale mask to match frame dimensions if needed
        let scaledMask = scaleMaskToFrame(maskImage, frameExtent: frameExtent)

        // Apply edge feathering to the mask
        let featheredMask = applyEdgeFeathering(scaledMask, edgeSoftness: edgeSoftness, extent: frameExtent)

        // Create the background image based on mode
        let background: CIImage
        switch mode {
        case .blur:
            background = applyBlur(to: frameImage, intensity: blurIntensity, extent: frameExtent)
        case .remove:
            background = createSolidBackground(extent: frameExtent)
        case .replace:
            if let bgImage = backgroundImage {
                background = scaleToAspectFill(bgImage, targetExtent: frameExtent)
            } else {
                // Fall back to remove mode (black background)
                background = createSolidBackground(extent: frameExtent)
            }
        }

        // Composite using CIBlendWithMask
        guard let composited = blendWithMask(
            foreground: frameImage,
            background: background,
            mask: featheredMask,
            extent: frameExtent
        ) else { return nil }

        // Render to output pixel buffer
        return renderToPixelBuffer(composited, width: frameWidth, height: frameHeight, sourceBuffer: frame)
    }

    // MARK: - Private Helpers

    private func scaleMaskToFrame(_ mask: CIImage, frameExtent: CGRect) -> CIImage {
        let maskExtent = mask.extent
        guard maskExtent.width > 0 && maskExtent.height > 0 else { return mask }

        let scaleX = frameExtent.width / maskExtent.width
        let scaleY = frameExtent.height / maskExtent.height

        if abs(scaleX - 1.0) < 0.001 && abs(scaleY - 1.0) < 0.001 {
            return mask
        }

        return mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }

    private func applyEdgeFeathering(_ mask: CIImage, edgeSoftness: Double, extent: CGRect) -> CIImage {
        let featherRadius = edgeSoftness * 10.0
        guard featherRadius > 0 else { return mask }

        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return mask }
        blurFilter.setValue(mask, forKey: kCIInputImageKey)
        blurFilter.setValue(featherRadius, forKey: kCIInputRadiusKey)

        guard let blurred = blurFilter.outputImage else { return mask }

        // Crop back to the original extent since Gaussian blur expands the image
        return blurred.cropped(to: extent)
    }

    private func applyBlur(to image: CIImage, intensity: Double, extent: CGRect) -> CIImage {
        let blurRadius = intensity * 30.0
        guard blurRadius > 0 else { return image }

        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return image }
        blurFilter.setValue(image, forKey: kCIInputImageKey)
        blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)

        guard let blurred = blurFilter.outputImage else { return image }

        // Crop back to the original extent
        return blurred.cropped(to: extent)
    }

    private func createSolidBackground(extent: CGRect) -> CIImage {
        let black = CIColor(red: 0, green: 0, blue: 0, alpha: 1)
        return CIImage(color: black).cropped(to: extent)
    }

    private func scaleToAspectFill(_ image: CIImage, targetExtent: CGRect) -> CIImage {
        let imageExtent = image.extent
        guard imageExtent.width > 0 && imageExtent.height > 0 else {
            return createSolidBackground(extent: targetExtent)
        }

        // Calculate scale to fill both dimensions (aspect fill)
        let scaleX = targetExtent.width / imageExtent.width
        let scaleY = targetExtent.height / imageExtent.height
        let scale = max(scaleX, scaleY)

        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Center-crop to target extent
        let scaledExtent = scaled.extent
        let offsetX = (scaledExtent.width - targetExtent.width) / 2.0
        let offsetY = (scaledExtent.height - targetExtent.height) / 2.0
        let cropRect = CGRect(
            x: scaledExtent.minX + offsetX,
            y: scaledExtent.minY + offsetY,
            width: targetExtent.width,
            height: targetExtent.height
        )

        // Crop and translate to origin
        let cropped = scaled.cropped(to: cropRect)
        return cropped.transformed(by: CGAffineTransform(
            translationX: -cropRect.origin.x,
            y: -cropRect.origin.y
        ))
    }

    private func blendWithMask(
        foreground: CIImage,
        background: CIImage,
        mask: CIImage,
        extent: CGRect
    ) -> CIImage? {
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return nil }
        blendFilter.setValue(foreground, forKey: kCIInputImageKey)
        blendFilter.setValue(background, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(mask, forKey: kCIInputMaskImageKey)
        return blendFilter.outputImage?.cropped(to: extent)
    }

    private func renderToPixelBuffer(
        _ image: CIImage,
        width: Int,
        height: Int,
        sourceBuffer: CVPixelBuffer
    ) -> CVPixelBuffer? {
        let pixelFormat = CVPixelBufferGetPixelFormatType(sourceBuffer)

        var outputBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: false,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: false,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormat,
            attrs as CFDictionary,
            &outputBuffer
        )

        guard status == kCVReturnSuccess, let output = outputBuffer else { return nil }

        ciContext.render(image, to: output)
        return output
    }
}
