import XCTest
import CoreImage
import CoreMedia
import CoreVideo
@testable import MacMeetingCam

final class FrameProcessorTests: XCTestCase {

    private var mockSegmentor: MockSegmentor!
    private var compositor: Compositor!
    private var buffer: FrameBuffer!
    private var processor: FrameProcessor!

    override func setUp() {
        super.setUp()
        mockSegmentor = MockSegmentor()
        compositor = Compositor()
        buffer = FrameBuffer(maxDuration: 10.0)
        processor = FrameProcessor(segmentor: mockSegmentor, compositor: compositor, buffer: buffer)
    }

    override func tearDown() {
        processor = nil
        buffer = nil
        compositor = nil
        mockSegmentor = nil
        super.tearDown()
    }

    // MARK: - Full Pipeline

    func testProcessesFrameThroughFullPipeline() async throws {
        let frame = try XCTUnwrap(
            SyntheticFrameGenerator.solidColor(
                width: TestConstants.smallWidth,
                height: TestConstants.smallHeight,
                red: 100, green: 150, blue: 200
            )
        )
        let timestamp = CMTime(seconds: 0.0, preferredTimescale: 600)

        let result = try await processor.process(
            frame: frame,
            timestamp: timestamp,
            backgroundMode: .blur,
            blurIntensity: 0.5,
            edgeSoftness: 0.3,
            backgroundImage: nil
        )

        // Verify output is non-nil (it's a value type, so we check dimensions)
        XCTAssertGreaterThan(CVPixelBufferGetWidth(result), 0)
        XCTAssertGreaterThan(CVPixelBufferGetHeight(result), 0)

        // Verify buffer has 1 frame
        XCTAssertEqual(buffer.frameCount, 1)

        // Verify segmentor was called
        XCTAssertEqual(mockSegmentor.segmentCallCount, 1)
    }

    // MARK: - Passthrough Mode

    func testSkipsSegmentationWhenNoEffect() async throws {
        let frame = try XCTUnwrap(
            SyntheticFrameGenerator.solidColor(
                width: TestConstants.smallWidth,
                height: TestConstants.smallHeight,
                red: 100, green: 150, blue: 200
            )
        )
        let timestamp = CMTime(seconds: 0.0, preferredTimescale: 600)

        let result = try await processor.process(
            frame: frame,
            timestamp: timestamp,
            backgroundMode: nil,
            blurIntensity: 0.0,
            edgeSoftness: 0.0,
            backgroundImage: nil
        )

        // Verify segmentor was NOT called
        XCTAssertEqual(mockSegmentor.segmentCallCount, 0)

        // Buffer still has the frame
        XCTAssertEqual(buffer.frameCount, 1)

        // Result should be the same raw frame
        XCTAssertEqual(CVPixelBufferGetWidth(result), TestConstants.smallWidth)
        XCTAssertEqual(CVPixelBufferGetHeight(result), TestConstants.smallHeight)
    }

    // MARK: - Multiple Frames

    func testMultipleFramesAccumulateInBuffer() async throws {
        let frames = SyntheticFrameGenerator.frameSequence(
            count: 5,
            width: TestConstants.smallWidth,
            height: TestConstants.smallHeight,
            fps: TestConstants.defaultFPS
        )

        for timedFrame in frames {
            _ = try await processor.process(
                frame: timedFrame.buffer,
                timestamp: timedFrame.timestamp,
                backgroundMode: nil,
                blurIntensity: 0.0,
                edgeSoftness: 0.0,
                backgroundImage: nil
            )
        }

        XCTAssertEqual(buffer.frameCount, 5)
    }

    // MARK: - Mode Passthrough to Compositor

    func testPassesThroughCorrectModeToCompositor() async throws {
        let frame = try XCTUnwrap(
            SyntheticFrameGenerator.solidColor(
                width: TestConstants.smallWidth,
                height: TestConstants.smallHeight,
                red: 200, green: 200, blue: 200
            )
        )
        let timestamp = CMTime(seconds: 0.0, preferredTimescale: 600)

        // Process with remove mode - background should be replaced with black
        let result = try await processor.process(
            frame: frame,
            timestamp: timestamp,
            backgroundMode: .remove,
            blurIntensity: 0.0,
            edgeSoftness: 0.0,
            backgroundImage: nil
        )

        // Segmentor should have been called for remove mode
        XCTAssertEqual(mockSegmentor.segmentCallCount, 1)

        // Output should have valid dimensions
        XCTAssertEqual(CVPixelBufferGetWidth(result), TestConstants.smallWidth)
        XCTAssertEqual(CVPixelBufferGetHeight(result), TestConstants.smallHeight)

        // Buffer should have the frame
        XCTAssertEqual(buffer.frameCount, 1)
    }
}
