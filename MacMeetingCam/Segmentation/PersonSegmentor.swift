import Foundation
import CoreVideo

/// A pluggable segmentation engine that produces a person mask from a video frame.
protocol PersonSegmentor {
    /// The quality level for segmentation processing.
    var quality: SegmentationQuality { get set }

    /// Segments a person from the given pixel buffer and returns a mask.
    /// - Parameter pixelBuffer: The input video frame in BGRA format.
    /// - Returns: A single-channel mask pixel buffer where white (255) indicates person pixels.
    /// - Throws: `SegmentationError` if segmentation fails.
    func segment(pixelBuffer: CVPixelBuffer) async throws -> CVPixelBuffer
}

/// Errors that can occur during person segmentation.
enum SegmentationError: Error, Equatable {
    /// The input pixel buffer is invalid (e.g., zero dimensions).
    case invalidInput
    /// Segmentation processing failed with the given description.
    case processingFailed(description: String)
    /// The input pixel buffer uses an unsupported pixel format.
    case unsupportedPixelFormat
}
