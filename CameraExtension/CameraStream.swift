import Foundation
import CoreMediaIO
import CoreMedia
import CoreVideo

/// Provides the video stream output for the virtual camera.
/// Receives frames from the host app (via IPC, to be connected later) and outputs
/// them to meeting app consumers (Zoom, Teams, etc.).
final class CameraStream: NSObject, CMIOExtensionStreamSource {

    // MARK: - Properties

    private(set) var stream: CMIOExtensionStream!

    /// The last frame received from the host app; held on disconnect so the camera
    /// shows a freeze rather than going black.
    private var lastFrame: CVPixelBuffer?

    /// Whether the stream is currently actively sending frames.
    private var isStreaming = false

    /// Timer that drives frame output while streaming.
    private var frameTimer: DispatchSourceTimer?

    /// Serial queue for frame delivery to avoid races on lastFrame / isStreaming.
    private let frameQueue = DispatchQueue(label: "com.tapnetix.MacMeetingCam.CameraExtension.frameQueue")

    /// Sequence number for sent buffers (monotonically increasing).
    private var sequenceNumber: UInt64 = 0

    // Default format: 1920x1080 @ 30fps BGRA
    let width: Int32 = 1920
    let height: Int32 = 1080
    let frameRate: Int = 30

    // MARK: - CMIOExtensionStreamSource

    var availableProperties: Set<CMIOExtensionProperty> {
        [.streamActiveFormatIndex, .streamFrameDuration]
    }

    var formats: [CMIOExtensionStreamFormat] {
        var formatDesc: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: width,
            height: height,
            extensions: nil,
            formatDescriptionOut: &formatDesc
        )
        guard status == noErr, let desc = formatDesc else {
            fatalError("Failed to create CMVideoFormatDescription: \(status)")
        }
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        return [
            CMIOExtensionStreamFormat(
                formatDescription: desc,
                maxFrameDuration: frameDuration,
                minFrameDuration: frameDuration,
                validFrameDurations: nil
            )
        ]
    }

    // MARK: - Initializer

    init(device: CMIOExtensionDevice) {
        super.init()
        stream = CMIOExtensionStream(
            localizedName: "MacMeetingCam Video",
            streamID: UUID(),
            direction: .source,
            clockType: .hostTime,
            source: self
        )
    }

    // MARK: - Stream Properties

    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let result = CMIOExtensionStreamProperties(dictionary: [:])
        if properties.contains(.streamActiveFormatIndex) {
            result.activeFormatIndex = 0
        }
        if properties.contains(.streamFrameDuration) {
            result.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        }
        return result
    }

    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        // Read-only stream; ignore property changes from clients.
    }

    // MARK: - Stream Lifecycle

    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        true
    }

    func startStream() throws {
        frameQueue.sync {
            guard !isStreaming else { return }
            isStreaming = true
            startFrameTimer()
        }
    }

    func stopStream() throws {
        frameQueue.sync {
            isStreaming = false
            stopFrameTimer()
        }
    }

    // MARK: - Frame Delivery (called by IPC bridge)

    /// Called by the IPC bridge to deliver a new frame from the host app.
    func deliverFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        frameQueue.async { [weak self] in
            self?.lastFrame = pixelBuffer
        }
    }

    // MARK: - Private

    /// Creates and starts a timer that outputs frames at the configured frame rate.
    private func startFrameTimer() {
        let timer = DispatchSource.makeTimerSource(queue: frameQueue)
        let interval = 1.0 / Double(frameRate)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.outputFrame()
        }
        timer.resume()
        frameTimer = timer
    }

    private func stopFrameTimer() {
        frameTimer?.cancel()
        frameTimer = nil
    }

    /// Outputs the current frame (or a black placeholder) to connected clients.
    private func outputFrame() {
        guard isStreaming else { return }

        let pixelBuffer: CVPixelBuffer
        if let last = lastFrame {
            pixelBuffer = last
        } else {
            // No frame ever received -- output solid black.
            pixelBuffer = createBlackFrame()
        }

        guard let sampleBuffer = createSampleBuffer(from: pixelBuffer) else { return }

        let hostTimeNanos = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        stream.send(
            sampleBuffer,
            discontinuity: [],
            hostTimeInNanoseconds: UInt64(hostTimeNanos)
        )
        sequenceNumber += 1
    }

    /// Creates a sample buffer wrapping the given pixel buffer with current timing.
    private func createSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        var formatDesc: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDesc
        )
        guard status == noErr, let desc = formatDesc else { return nil }

        let now = CMClockGetTime(CMClockGetHostTimeClock())
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(frameRate)),
            presentationTimeStamp: now,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let createStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: desc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        guard createStatus == noErr else { return nil }
        return sampleBuffer
    }

    /// Creates a solid black BGRA pixel buffer at the stream's resolution.
    private func createBlackFrame() -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(width),
            Int(height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            fatalError("Failed to create black pixel buffer: \(status)")
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            let totalBytes = bytesPerRow * Int(height)
            // Zero out all bytes (BGRA 0,0,0,0 is black with zero alpha;
            // set alpha to 0xFF for fully opaque black).
            memset(baseAddress, 0, totalBytes)
            // Set alpha channel to fully opaque for each pixel.
            let pixelCount = Int(width) * Int(height)
            let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
            for i in 0..<pixelCount {
                ptr[i * 4 + 3] = 0xFF  // alpha byte in BGRA
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }
}
