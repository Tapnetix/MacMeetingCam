import Foundation
import CoreMedia
import CoreVideo
import CoreImage

/// Manages freeze and loop playback with crossfade blending.
final class LoopEngine {

    enum Mode: Equatable {
        case idle
        case frozen
        case looping
    }

    // MARK: - Properties

    private(set) var mode: Mode = .idle
    let crossfadeDuration: TimeInterval
    let resumeTransition: TimeInterval

    private var frozenFrame: CVPixelBuffer?
    private var loopFrames: [FrameBuffer.Entry] = []
    private var loopStartTime: CMTime?
    private var loopTotalDuration: TimeInterval = 0

    private static let ciContext = CIContext()

    // MARK: - Init

    init(crossfadeDuration: TimeInterval, resumeTransition: TimeInterval) {
        self.crossfadeDuration = crossfadeDuration
        self.resumeTransition = resumeTransition
    }

    // MARK: - Freeze

    func activateFreeze(lastFrame: CVPixelBuffer) {
        frozenFrame = lastFrame
        mode = .frozen
    }

    func deactivateFreeze() -> CVPixelBuffer? {
        let frame = frozenFrame
        frozenFrame = nil
        mode = .idle
        return frame
    }

    // MARK: - Loop

    func activateLoop(frames: [FrameBuffer.Entry]) {
        guard !frames.isEmpty else { return }
        loopFrames = frames
        loopStartTime = nil
        if frames.count > 1 {
            let first = CMTimeGetSeconds(frames.first!.timestamp)
            let last = CMTimeGetSeconds(frames.last!.timestamp)
            loopTotalDuration = last - first
        } else {
            loopTotalDuration = 0
        }
        mode = .looping
    }

    func deactivateLoop() {
        loopFrames = []
        loopStartTime = nil
        loopTotalDuration = 0
        mode = .idle
    }

    // MARK: - Playback

    func nextFrame(at currentTime: CMTime) -> CVPixelBuffer? {
        switch mode {
        case .idle:
            return nil

        case .frozen:
            return frozenFrame

        case .looping:
            return loopFrame(at: currentTime)
        }
    }

    // MARK: - Crossfade Math

    /// Linear interpolation, clamped to 0...1.
    func crossfadeAlpha(t: Double) -> Double {
        return min(max(t, 0), 1)
    }

    // MARK: - Blending

    /// Blends two pixel buffers: `output = a * (1-alpha) + b * alpha`.
    static func blend(_ a: CVPixelBuffer, _ b: CVPixelBuffer, alpha: Double) -> CVPixelBuffer? {
        let clampedAlpha = min(max(alpha, 0), 1)

        let ciA = CIImage(cvPixelBuffer: a)
        let ciB = CIImage(cvPixelBuffer: b)

        // Use CIBlendWithMask approach via dissolve
        // output = a * (1 - alpha) + b * alpha
        guard let dissolveFilter = CIFilter(name: "CIDissolveTransition") else { return nil }
        dissolveFilter.setValue(ciA, forKey: kCIInputImageKey)
        dissolveFilter.setValue(ciB, forKey: kCIInputTargetImageKey)
        dissolveFilter.setValue(NSNumber(value: clampedAlpha), forKey: kCIInputTimeKey)

        guard let outputImage = dissolveFilter.outputImage else { return nil }

        let width = CVPixelBufferGetWidth(a)
        let height = CVPixelBufferGetHeight(a)

        var outputBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: false,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: false,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &outputBuffer
        )
        guard status == kCVReturnSuccess, let output = outputBuffer else { return nil }

        ciContext.render(outputImage, to: output)
        return output
    }

    // MARK: - Private Loop Helpers

    /// Small epsilon for floating-point time comparisons.
    private static let timeEpsilon: Double = 1e-9

    private func loopFrame(at currentTime: CMTime) -> CVPixelBuffer? {
        guard !loopFrames.isEmpty else { return nil }
        guard loopFrames.count > 1 else { return loopFrames[0].buffer }

        // Initialize loop start time on first call
        if loopStartTime == nil {
            loopStartTime = currentTime
        }

        let elapsed = CMTimeGetSeconds(currentTime) - CMTimeGetSeconds(loopStartTime!)

        // Where in the loop are we? Wrap around.
        let position = elapsed.truncatingRemainder(dividingBy: loopTotalDuration)
        let normalizedPosition = position < 0 ? position + loopTotalDuration : position

        // Find the frame whose offset from the first frame is closest to normalizedPosition
        let firstTimestamp = CMTimeGetSeconds(loopFrames.first!.timestamp)

        // Find the appropriate frame index using epsilon for floating-point tolerance
        var frameIndex = 0
        for i in 0..<loopFrames.count {
            let offset = CMTimeGetSeconds(loopFrames[i].timestamp) - firstTimestamp
            if offset <= normalizedPosition + Self.timeEpsilon {
                frameIndex = i
            } else {
                break
            }
        }

        // Check if we're in the crossfade region (last crossfadeDuration seconds of the loop)
        let crossfadeStart = loopTotalDuration - crossfadeDuration

        if normalizedPosition >= crossfadeStart && crossfadeDuration > 0 {
            // We are in the crossfade region
            let t = (normalizedPosition - crossfadeStart) / crossfadeDuration
            let alpha = crossfadeAlpha(t: t)

            // Find the corresponding frame from the start of the loop
            let startOffset = normalizedPosition - crossfadeStart
            var startFrameIndex = 0
            for i in 0..<loopFrames.count {
                let offset = CMTimeGetSeconds(loopFrames[i].timestamp) - firstTimestamp
                if offset <= startOffset + Self.timeEpsilon {
                    startFrameIndex = i
                } else {
                    break
                }
            }

            let endFrame = loopFrames[frameIndex].buffer
            let startFrame = loopFrames[startFrameIndex].buffer

            // output = frame_end * (1-t) + frame_start * t
            return LoopEngine.blend(endFrame, startFrame, alpha: alpha) ?? endFrame
        }

        return loopFrames[frameIndex].buffer
    }
}
