import Foundation
import CoreVideo
@testable import MacMeetingCam

/// A test double for `PersonSegmentor` that returns predictable masks
/// without hitting the Vision framework.
final class MockSegmentor: PersonSegmentor {

    /// The quality level for segmentation.
    var quality: SegmentationQuality

    /// An optional fixed mask to return instead of generating one.
    private let fixedMask: CVPixelBuffer?

    /// The number of times `segment(pixelBuffer:)` has been called.
    private(set) var segmentCallCount = 0

    /// Creates a new MockSegmentor.
    /// - Parameters:
    ///   - quality: The segmentation quality. Defaults to `.balanced`.
    ///   - fixedMask: An optional fixed mask to return. If nil, a centered person mask
    ///     matching the input dimensions is generated using `SyntheticFrameGenerator.personMask()`.
    init(quality: SegmentationQuality = .balanced, fixedMask: CVPixelBuffer? = nil) {
        self.quality = quality
        self.fixedMask = fixedMask
    }

    func segment(pixelBuffer: CVPixelBuffer) async throws -> CVPixelBuffer {
        segmentCallCount += 1

        if let fixedMask = fixedMask {
            return fixedMask
        }

        // Generate a centered person mask matching input dimensions
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard width > 0, height > 0 else {
            throw SegmentationError.invalidInput
        }

        // Create a centered rectangle covering roughly the middle third
        let personRect = CGRect(
            x: CGFloat(width) / 4.0,
            y: CGFloat(height) / 4.0,
            width: CGFloat(width) / 2.0,
            height: CGFloat(height) / 2.0
        )

        guard let mask = SyntheticFrameGenerator.personMask(
            width: width,
            height: height,
            personRect: personRect
        ) else {
            throw SegmentationError.processingFailed(description: "Failed to generate mock mask")
        }

        return mask
    }
}
