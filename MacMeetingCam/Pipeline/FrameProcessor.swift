import Foundation
import CoreImage
import CoreVideo
import CoreMedia

/// Orchestrates the per-frame pipeline: segmentation -> compositing -> buffer.
final class FrameProcessor {

    // MARK: - Properties

    private let segmentor: PersonSegmentor
    private let compositor: Compositor
    private let buffer: FrameBuffer

    // MARK: - Init

    init(segmentor: PersonSegmentor, compositor: Compositor, buffer: FrameBuffer) {
        self.segmentor = segmentor
        self.compositor = compositor
        self.buffer = buffer
    }

    // MARK: - Public API

    /// Process a single frame through the pipeline.
    /// - Parameters:
    ///   - frame: The input video frame pixel buffer.
    ///   - timestamp: The frame's presentation timestamp.
    ///   - backgroundMode: The background effect to apply, or nil for passthrough.
    ///   - blurIntensity: Normalized blur intensity (0.0-1.0).
    ///   - edgeSoftness: Normalized edge softness (0.0-1.0).
    ///   - backgroundImage: Optional replacement background image.
    /// - Returns: The processed (or raw) pixel buffer.
    func process(
        frame: CVPixelBuffer,
        timestamp: CMTime,
        backgroundMode: BackgroundMode?,
        blurIntensity: Double,
        edgeSoftness: Double,
        backgroundImage: CIImage?
    ) async throws -> CVPixelBuffer {
        let result: CVPixelBuffer

        if let mode = backgroundMode {
            // Run segmentation
            let mask = try await segmentor.segment(pixelBuffer: frame)

            // Run compositing
            if let composited = compositor.apply(
                frame: frame,
                mask: mask,
                mode: mode,
                blurIntensity: blurIntensity,
                edgeSoftness: edgeSoftness,
                backgroundImage: backgroundImage
            ) {
                result = composited
            } else {
                // Compositing failed, fall back to raw frame
                result = frame
            }
        } else {
            // No effect: passthrough
            result = frame
        }

        // Always append to buffer
        buffer.append(frame: result, timestamp: timestamp)

        return result
    }
}
