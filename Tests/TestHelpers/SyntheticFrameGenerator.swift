import Foundation
import CoreMedia
import CoreVideo

/// A frame with an associated timestamp, used for testing frame sequences.
struct TimedFrame {
    let buffer: CVPixelBuffer
    let timestamp: CMTime
}

/// Generates synthetic pixel buffers for testing purposes.
/// All functions are static and produce deterministic output.
enum SyntheticFrameGenerator {

    // MARK: - Solid Color

    /// Creates a BGRA pixel buffer filled with a solid color.
    /// - Parameters:
    ///   - width: Width in pixels.
    ///   - height: Height in pixels.
    ///   - red: Red component (0-255).
    ///   - green: Green component (0-255).
    ///   - blue: Blue component (0-255).
    /// - Returns: A CVPixelBuffer in 32BGRA format, or nil on failure.
    static func solidColor(
        width: Int,
        height: Int,
        red: UInt8,
        green: UInt8,
        blue: UInt8
    ) -> CVPixelBuffer? {
        guard let pixelBuffer = createPixelBuffer(
            width: width,
            height: height,
            pixelFormat: kCVPixelFormatType_32BGRA
        ) else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let data = baseAddress.assumingMemoryBound(to: UInt8.self)

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                data[offset + 0] = blue   // B
                data[offset + 1] = green   // G
                data[offset + 2] = red     // R
                data[offset + 3] = 255     // A
            }
        }

        return pixelBuffer
    }

    // MARK: - Timed Frame

    /// Creates a solid color frame paired with a CMTime timestamp.
    /// - Parameters:
    ///   - width: Width in pixels.
    ///   - height: Height in pixels.
    ///   - red: Red component (0-255).
    ///   - green: Green component (0-255).
    ///   - blue: Blue component (0-255).
    ///   - timestampSeconds: Timestamp in seconds.
    /// - Returns: A tuple of optional pixel buffer and CMTime.
    static func timedFrame(
        width: Int,
        height: Int,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        timestampSeconds: Double
    ) -> (buffer: CVPixelBuffer?, time: CMTime) {
        let buffer = solidColor(width: width, height: height, red: red, green: green, blue: blue)
        let time = CMTime(seconds: timestampSeconds, preferredTimescale: 600)
        return (buffer, time)
    }

    // MARK: - Gradient Mask

    /// Creates a single-channel (OneComponent8) mask with a vertical gradient.
    /// Top row is 0 (black), bottom row is 255 (white).
    /// - Parameters:
    ///   - width: Width in pixels.
    ///   - height: Height in pixels.
    /// - Returns: A CVPixelBuffer in OneComponent8 format, or nil on failure.
    static func gradientMask(width: Int, height: Int) -> CVPixelBuffer? {
        guard let pixelBuffer = createPixelBuffer(
            width: width,
            height: height,
            pixelFormat: kCVPixelFormatType_OneComponent8
        ) else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let data = baseAddress.assumingMemoryBound(to: UInt8.self)

        for y in 0..<height {
            let value: UInt8 = height > 1
                ? UInt8(clamping: (y * 255) / (height - 1))
                : 0
            for x in 0..<width {
                data[y * bytesPerRow + x] = value
            }
        }

        return pixelBuffer
    }

    // MARK: - Person Mask

    /// Creates a single-channel mask with white (255) inside personRect and black (0) outside.
    /// - Parameters:
    ///   - width: Width in pixels.
    ///   - height: Height in pixels.
    ///   - personRect: The rectangle defining the "person" region.
    /// - Returns: A CVPixelBuffer in OneComponent8 format, or nil on failure.
    static func personMask(width: Int, height: Int, personRect: CGRect) -> CVPixelBuffer? {
        guard let pixelBuffer = createPixelBuffer(
            width: width,
            height: height,
            pixelFormat: kCVPixelFormatType_OneComponent8
        ) else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let data = baseAddress.assumingMemoryBound(to: UInt8.self)

        let minX = Int(personRect.minX)
        let maxX = Int(personRect.maxX)
        let minY = Int(personRect.minY)
        let maxY = Int(personRect.maxY)

        for y in 0..<height {
            for x in 0..<width {
                let inside = x >= minX && x < maxX && y >= minY && y < maxY
                data[y * bytesPerRow + x] = inside ? 255 : 0
            }
        }

        return pixelBuffer
    }

    // MARK: - Frame Sequence

    /// Generates a sequence of frames with sequential timestamps at the given FPS.
    /// Each frame has a slightly different color shade so frames are distinguishable.
    /// - Parameters:
    ///   - count: Number of frames to generate.
    ///   - width: Width in pixels.
    ///   - height: Height in pixels.
    ///   - fps: Frames per second (determines timestamp intervals).
    /// - Returns: An array of TimedFrame values.
    static func frameSequence(count: Int, width: Int, height: Int, fps: Int) -> [TimedFrame] {
        var frames: [TimedFrame] = []
        frames.reserveCapacity(count)

        let timescale: Int32 = Int32(fps)

        for i in 0..<count {
            // Vary the green channel so each frame is distinguishable
            let shade = UInt8(clamping: (i * 255) / max(count - 1, 1))
            guard let buffer = solidColor(
                width: width,
                height: height,
                red: 100,
                green: shade,
                blue: 50
            ) else { continue }

            let timestamp = CMTime(value: CMTimeValue(i), timescale: timescale)
            frames.append(TimedFrame(buffer: buffer, timestamp: timestamp))
        }

        return frames
    }

    // MARK: - Private Helpers

    private static func createPixelBuffer(
        width: Int,
        height: Int,
        pixelFormat: OSType
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
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
            &pixelBuffer
        )
        guard status == kCVReturnSuccess else { return nil }
        return pixelBuffer
    }
}
