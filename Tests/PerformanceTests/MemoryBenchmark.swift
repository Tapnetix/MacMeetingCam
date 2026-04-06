import XCTest
import CoreVideo
import CoreMedia
@testable import MacMeetingCam

final class MemoryBenchmark: XCTestCase {

    func testMemoryUsageWithEmptyBuffer() {
        measure(metrics: [XCTMemoryMetric()]) {
            let buffer = FrameBuffer(maxDuration: 30.0)
            XCTAssertTrue(buffer.isEmpty)
            // Memory should be minimal
        }
    }

    func testMemoryUsageWith5SecondBuffer() {
        measure(metrics: [XCTMemoryMetric()]) {
            let buffer = FrameBuffer(maxDuration: 5.0)
            let frames = SyntheticFrameGenerator.frameSequence(count: 150, width: 640, height: 480, fps: 30)
            for frame in frames {
                buffer.append(frame: frame.buffer, timestamp: frame.timestamp)
            }
            XCTAssertGreaterThan(buffer.frameCount, 0)
        }
    }

    func testMemoryEstimatorAccuracy() {
        // Verify the estimator's calculation matches reality approximately
        let expected = MemoryEstimator.estimateBytes(durationSeconds: 5, width: 640, height: 480, fps: 30)

        let buffer = FrameBuffer(maxDuration: 5.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 150, width: 640, height: 480, fps: 30)
        for frame in frames {
            buffer.append(frame: frame.buffer, timestamp: frame.timestamp)
        }

        // Expected: 150 frames * 640 * 480 * 4 = 184,320,000 bytes
        XCTAssertEqual(expected, 150 * 640 * 480 * 4)
        XCTAssertGreaterThan(buffer.frameCount, 140) // Should have most frames
    }

    func testBufferFlushReducesMemory() {
        let buffer = FrameBuffer(maxDuration: 5.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 150, width: 320, height: 240, fps: 30)
        for frame in frames {
            buffer.append(frame: frame.buffer, timestamp: frame.timestamp)
        }

        XCTAssertGreaterThan(buffer.frameCount, 0)
        buffer.flush()
        XCTAssertEqual(buffer.frameCount, 0)
    }
}
