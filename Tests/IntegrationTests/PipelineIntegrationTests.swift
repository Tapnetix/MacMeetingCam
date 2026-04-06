import XCTest
import CoreVideo
import CoreMedia
@testable import MacMeetingCam

final class PipelineIntegrationTests: XCTestCase {

    func testFullPipelineProcesses10SecondsWithoutDrops() async throws {
        let segmentor = MockSegmentor()
        let compositor = Compositor()
        let buffer = FrameBuffer(maxDuration: 30.0)
        let processor = FrameProcessor(segmentor: segmentor, compositor: compositor, buffer: buffer)

        let frames = SyntheticFrameGenerator.frameSequence(count: 300, width: 640, height: 480, fps: 30)

        var outputCount = 0
        for frame in frames {
            let result = try await processor.process(
                frame: frame.buffer,
                timestamp: frame.timestamp,
                backgroundMode: .blur,
                blurIntensity: 0.5,
                edgeSoftness: 0.3,
                backgroundImage: nil
            )
            if CVPixelBufferGetWidth(result) > 0 { outputCount += 1 }
        }

        XCTAssertEqual(outputCount, 300, "All 300 frames should produce output")
        XCTAssertEqual(segmentor.segmentCallCount, 300, "Segmentor should be called for each frame")
        XCTAssertGreaterThan(buffer.frameCount, 0, "Buffer should have frames")
    }

    func testPipelineWithNoEffectPassesThroughRawFrames() async throws {
        let segmentor = MockSegmentor()
        let compositor = Compositor()
        let buffer = FrameBuffer(maxDuration: 30.0)
        let processor = FrameProcessor(segmentor: segmentor, compositor: compositor, buffer: buffer)

        let frames = SyntheticFrameGenerator.frameSequence(count: 30, width: 640, height: 480, fps: 30)

        for frame in frames {
            _ = try await processor.process(
                frame: frame.buffer,
                timestamp: frame.timestamp,
                backgroundMode: nil,
                blurIntensity: 0,
                edgeSoftness: 0,
                backgroundImage: nil
            )
        }

        XCTAssertEqual(segmentor.segmentCallCount, 0, "Segmentor should not be called without effect")
        XCTAssertEqual(buffer.frameCount, 30, "Buffer should still receive all frames")
    }

    func testPipelineOutputMatchesInputDimensions() async throws {
        let segmentor = MockSegmentor()
        let compositor = Compositor()
        let buffer = FrameBuffer(maxDuration: 10.0)
        let processor = FrameProcessor(segmentor: segmentor, compositor: compositor, buffer: buffer)

        let frame = try XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 1280, height: 720, red: 128, green: 128, blue: 128)
        )
        let time = CMTime(seconds: 0, preferredTimescale: 90000)

        let output = try await processor.process(
            frame: frame, timestamp: time,
            backgroundMode: .blur, blurIntensity: 0.5, edgeSoftness: 0.3, backgroundImage: nil
        )

        XCTAssertEqual(CVPixelBufferGetWidth(output), 1280)
        XCTAssertEqual(CVPixelBufferGetHeight(output), 720)
    }

    func testPipelineWithAllModes() async throws {
        let segmentor = MockSegmentor()
        let compositor = Compositor()
        let buffer = FrameBuffer(maxDuration: 10.0)
        let processor = FrameProcessor(segmentor: segmentor, compositor: compositor, buffer: buffer)

        let frame = try XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 128, green: 128, blue: 128)
        )
        let time = CMTime(seconds: 0, preferredTimescale: 90000)

        // Test all three modes produce output
        for mode in BackgroundMode.allCases {
            let output = try await processor.process(
                frame: frame, timestamp: time,
                backgroundMode: mode, blurIntensity: 0.5, edgeSoftness: 0.3, backgroundImage: nil
            )
            XCTAssertGreaterThan(
                CVPixelBufferGetWidth(output), 0,
                "\(mode) mode should produce valid output"
            )
        }
    }
}
