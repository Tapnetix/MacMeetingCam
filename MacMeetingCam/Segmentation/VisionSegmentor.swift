import Foundation
import CoreVideo
import Vision
import CoreImage

/// A person segmentor that uses Apple's Vision framework (`VNGeneratePersonSegmentationRequest`).
final class VisionSegmentor: PersonSegmentor {

    /// The quality level for segmentation. Maps directly to `VNGeneratePersonSegmentationRequest.QualityLevel`.
    var quality: SegmentationQuality

    /// A reusable CIContext for resizing masks when dimensions don't match the input.
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Creates a new VisionSegmentor with the specified quality level.
    /// - Parameter quality: The segmentation quality. Defaults to `.balanced`.
    init(quality: SegmentationQuality = .balanced) {
        self.quality = quality
    }

    func segment(pixelBuffer: CVPixelBuffer) async throws -> CVPixelBuffer {
        let inputWidth = CVPixelBufferGetWidth(pixelBuffer)
        let inputHeight = CVPixelBufferGetHeight(pixelBuffer)

        guard inputWidth > 0, inputHeight > 0 else {
            throw SegmentationError.invalidInput
        }

        // 1. Create the segmentation request
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = quality.visionQualityLevel

        // 2. Create image request handler with the input pixel buffer
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        // 3. Perform the request
        do {
            try handler.perform([request])
        } catch {
            throw SegmentationError.processingFailed(description: error.localizedDescription)
        }

        // 4. Extract the mask from the result
        guard let result = request.results?.first as? VNPixelBufferObservation else {
            throw SegmentationError.processingFailed(description: "No segmentation result produced")
        }
        let maskBuffer = result.pixelBuffer

        // 5. Check if mask dimensions match input; resize if needed
        let maskWidth = CVPixelBufferGetWidth(maskBuffer)
        let maskHeight = CVPixelBufferGetHeight(maskBuffer)

        if maskWidth == inputWidth && maskHeight == inputHeight {
            return maskBuffer
        }

        // 6. Resize the mask to match input dimensions using CIContext
        return try resizeMask(maskBuffer, toWidth: inputWidth, height: inputHeight)
    }

    // MARK: - Private

    /// Resizes a mask pixel buffer to the specified dimensions.
    private func resizeMask(_ mask: CVPixelBuffer, toWidth width: Int, height: Int) throws -> CVPixelBuffer {
        let ciImage = CIImage(cvPixelBuffer: mask)

        let maskWidth = CGFloat(CVPixelBufferGetWidth(mask))
        let maskHeight = CGFloat(CVPixelBufferGetHeight(mask))

        let scaleX = CGFloat(width) / maskWidth
        let scaleY = CGFloat(height) / maskHeight

        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Create output pixel buffer matching the mask's pixel format
        let pixelFormat = CVPixelBufferGetPixelFormatType(mask)
        var outputBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: false,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: false,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormat,
            attrs as CFDictionary,
            &outputBuffer
        )

        guard status == kCVReturnSuccess, let output = outputBuffer else {
            throw SegmentationError.processingFailed(description: "Failed to create output buffer for resize")
        }

        ciContext.render(scaledImage, to: output)
        return output
    }
}

// MARK: - SegmentationQuality + Vision

extension SegmentationQuality {
    /// Maps the app's quality enum to Vision framework's quality level.
    var visionQualityLevel: VNGeneratePersonSegmentationRequest.QualityLevel {
        switch self {
        case .fast:
            return .fast
        case .balanced:
            return .balanced
        case .accurate:
            return .accurate
        }
    }
}
