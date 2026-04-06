import XCTest
import CoreVideo
import CoreMedia
@testable import MacMeetingCam

final class FrameProcessingBenchmark: XCTestCase {

    func testFrameProcessingLatencyAt1080p() {
        let segmentor = MockSegmentor()
        let compositor = Compositor()
        let buffer = FrameBuffer(maxDuration: 10.0)
        let processor = FrameProcessor(segmentor: segmentor, compositor: compositor, buffer: buffer)

        let frame = SyntheticFrameGenerator.solidColor(width: 1920, height: 1080, red: 128, green: 128, blue: 128)!
        var frameIndex = 0

        measure(metrics: [XCTClockMetric()]) {
            let time = CMTime(seconds: Double(frameIndex) / 30.0, preferredTimescale: 90000)
            let expectation = self.expectation(description: "frame")

            Task {
                _ = try? await processor.process(
                    frame: frame, timestamp: time,
                    backgroundMode: .blur, blurIntensity: 0.5, edgeSoftness: 0.3,
                    backgroundImage: nil
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
            frameIndex += 1
        }
    }

    func testFrameProcessingLatencyAt720p() {
        let segmentor = MockSegmentor()
        let compositor = Compositor()
        let buffer = FrameBuffer(maxDuration: 10.0)
        let processor = FrameProcessor(segmentor: segmentor, compositor: compositor, buffer: buffer)

        let frame = SyntheticFrameGenerator.solidColor(width: 1280, height: 720, red: 128, green: 128, blue: 128)!
        var frameIndex = 0

        measure(metrics: [XCTClockMetric()]) {
            let time = CMTime(seconds: Double(frameIndex) / 30.0, preferredTimescale: 90000)
            let expectation = self.expectation(description: "frame")

            Task {
                _ = try? await processor.process(
                    frame: frame, timestamp: time,
                    backgroundMode: .blur, blurIntensity: 0.5, edgeSoftness: 0.3,
                    backgroundImage: nil
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
            frameIndex += 1
        }
    }

    func testPassthroughLatency() {
        let segmentor = MockSegmentor()
        let compositor = Compositor()
        let buffer = FrameBuffer(maxDuration: 10.0)
        let processor = FrameProcessor(segmentor: segmentor, compositor: compositor, buffer: buffer)

        let frame = SyntheticFrameGenerator.solidColor(width: 1920, height: 1080, red: 128, green: 128, blue: 128)!
        var frameIndex = 0

        measure(metrics: [XCTClockMetric()]) {
            let time = CMTime(seconds: Double(frameIndex) / 30.0, preferredTimescale: 90000)
            let expectation = self.expectation(description: "frame")

            Task {
                _ = try? await processor.process(
                    frame: frame, timestamp: time,
                    backgroundMode: nil, blurIntensity: 0, edgeSoftness: 0,
                    backgroundImage: nil
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
            frameIndex += 1
        }
    }
}
