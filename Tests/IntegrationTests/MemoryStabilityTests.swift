import XCTest
import CoreMedia
@testable import MacMeetingCam

final class MemoryStabilityTests: XCTestCase {

    func testBufferMemoryStaysStableAtMaxDuration() {
        let buffer = FrameBuffer(maxDuration: 5.0) // 5 seconds for test speed

        // Fill with frames for 10 seconds worth (should evict old ones)
        let totalFrames = 300 // 10 seconds at 30fps
        for i in 0..<totalFrames {
            let frame = SyntheticFrameGenerator.solidColor(
                width: 320, height: 240,
                red: UInt8(i % 256), green: 0, blue: 0
            )!
            let time = CMTime(seconds: Double(i) / 30.0, preferredTimescale: 90000)
            buffer.append(frame: frame, timestamp: time)
        }

        // Buffer should have ~150 frames (5 seconds at 30fps), not 300
        XCTAssertLessThanOrEqual(buffer.frameCount, 155)
        XCTAssertGreaterThan(buffer.frameCount, 140)
    }

    func testBufferFlushReleasesMemory() {
        let buffer = FrameBuffer(maxDuration: 10.0)

        let frames = SyntheticFrameGenerator.frameSequence(count: 100, width: 320, height: 240, fps: 30)
        for frame in frames {
            buffer.append(frame: frame.buffer, timestamp: frame.timestamp)
        }

        XCTAssertEqual(buffer.frameCount, 100)
        buffer.flush()
        XCTAssertEqual(buffer.frameCount, 0)
    }

    func testReducingMaxDurationTrimsBuffer() {
        let buffer = FrameBuffer(maxDuration: 10.0)

        let frames = SyntheticFrameGenerator.frameSequence(count: 300, width: 320, height: 240, fps: 30)
        for frame in frames {
            buffer.append(frame: frame.buffer, timestamp: frame.timestamp)
        }

        XCTAssertGreaterThan(buffer.frameCount, 250)

        buffer.maxDuration = 1.0
        XCTAssertLessThanOrEqual(buffer.frameCount, 35) // ~1 second of frames
    }
}
