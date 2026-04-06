import XCTest
import CoreMedia
@testable import MacMeetingCam

final class FrameBufferTests: XCTestCase {

    // MARK: - testInitiallyEmpty

    func testInitiallyEmpty() {
        let buffer = FrameBuffer(maxDuration: 5.0)

        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.frameCount, 0)
        XCTAssertNil(buffer.oldestTimestamp)
        XCTAssertNil(buffer.newestTimestamp)
        XCTAssertEqual(buffer.currentDuration, 0)
    }

    // MARK: - testAppendFrame

    func testAppendFrame() {
        let buffer = FrameBuffer(maxDuration: 5.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 1, width: 64, height: 64, fps: 30)
        let frame = frames[0]

        buffer.append(frame: frame.buffer, timestamp: frame.timestamp)

        XCTAssertFalse(buffer.isEmpty)
        XCTAssertEqual(buffer.frameCount, 1)
    }

    // MARK: - testCapacityLimitsFrameCount

    func testCapacityLimitsFrameCount() {
        // 1s buffer at 30fps: add 60 frames (2s worth), should keep ≤31
        let buffer = FrameBuffer(maxDuration: 1.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 60, width: 64, height: 64, fps: 30)

        for frame in frames {
            buffer.append(frame: frame.buffer, timestamp: frame.timestamp)
        }

        XCTAssertLessThanOrEqual(buffer.frameCount, 31,
            "1s buffer at 30fps should have at most 31 frames, got \(buffer.frameCount)")
    }

    // MARK: - testOverwriteEvictsOldestFrames

    func testOverwriteEvictsOldestFrames() {
        // 0.5s buffer, 30 frames at 30fps (1s worth)
        let buffer = FrameBuffer(maxDuration: 0.5)
        let frames = SyntheticFrameGenerator.frameSequence(count: 30, width: 64, height: 64, fps: 30)

        for frame in frames {
            buffer.append(frame: frame.buffer, timestamp: frame.timestamp)
        }

        // The oldest remaining timestamp should be > 0.3s
        // (newest is 29/30 ≈ 0.9667, cutoff = 0.9667 - 0.5 = 0.4667)
        guard let oldest = buffer.oldestTimestamp else {
            XCTFail("Expected oldest timestamp")
            return
        }
        XCTAssertGreaterThan(CMTimeGetSeconds(oldest), 0.3,
            "Oldest timestamp should be > 0.3s after eviction, got \(CMTimeGetSeconds(oldest))")
    }

    // MARK: - testRetrieveFramesInOrder

    func testRetrieveFramesInOrder() {
        let buffer = FrameBuffer(maxDuration: 10.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 5, width: 64, height: 64, fps: 30)

        for frame in frames {
            buffer.append(frame: frame.buffer, timestamp: frame.timestamp)
        }

        let retrieved = buffer.allFrames()
        XCTAssertEqual(retrieved.count, 5)

        for i in 1..<retrieved.count {
            let prev = CMTimeGetSeconds(retrieved[i - 1].timestamp)
            let curr = CMTimeGetSeconds(retrieved[i].timestamp)
            XCTAssertLessThan(prev, curr, "Frames should be in chronological order")
        }
    }

    // MARK: - testFlushClearsBuffer

    func testFlushClearsBuffer() {
        let buffer = FrameBuffer(maxDuration: 5.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 10, width: 64, height: 64, fps: 30)

        for frame in frames {
            buffer.append(frame: frame.buffer, timestamp: frame.timestamp)
        }

        XCTAssertFalse(buffer.isEmpty)

        buffer.flush()

        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.frameCount, 0)
        XCTAssertNil(buffer.oldestTimestamp)
        XCTAssertNil(buffer.newestTimestamp)
    }

    // MARK: - testDurationProperty

    func testDurationProperty() {
        // 30 frames at 30fps: timestamps 0/30, 1/30, ..., 29/30
        // duration = 29/30 ≈ 0.9667
        let buffer = FrameBuffer(maxDuration: 5.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 30, width: 64, height: 64, fps: 30)

        for frame in frames {
            buffer.append(frame: frame.buffer, timestamp: frame.timestamp)
        }

        let expectedDuration = 29.0 / 30.0
        XCTAssertEqual(buffer.currentDuration, expectedDuration, accuracy: 0.001,
            "Duration should be approximately 29/30")
    }

    // MARK: - testMaxDurationCanBeUpdated

    func testMaxDurationCanBeUpdated() {
        // Add 60 frames at 30fps (0..59, spanning ~2s), buffer initially holds 5s
        let buffer = FrameBuffer(maxDuration: 5.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 60, width: 64, height: 64, fps: 30)

        for frame in frames {
            buffer.append(frame: frame.buffer, timestamp: frame.timestamp)
        }

        XCTAssertEqual(buffer.frameCount, 60)

        // Reduce maxDuration to 0.5s - should trim
        buffer.maxDuration = 0.5

        XCTAssertLessThan(buffer.frameCount, 60,
            "Frame count should decrease after reducing maxDuration")
        XCTAssertLessThanOrEqual(buffer.frameCount, 16,
            "0.5s at 30fps should keep at most ~16 frames")
    }

    // MARK: - testPartiallyFilledBuffer

    func testPartiallyFilledBuffer() {
        // 30s capacity, add only 3 frames
        let buffer = FrameBuffer(maxDuration: 30.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 3, width: 64, height: 64, fps: 30)

        for frame in frames {
            buffer.append(frame: frame.buffer, timestamp: frame.timestamp)
        }

        XCTAssertEqual(buffer.frameCount, 3)
    }

    // MARK: - testSingleFrameBuffer

    func testSingleFrameBuffer() {
        let buffer = FrameBuffer(maxDuration: 5.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 1, width: 64, height: 64, fps: 30)

        buffer.append(frame: frames[0].buffer, timestamp: frames[0].timestamp)

        XCTAssertEqual(buffer.frameCount, 1)
        XCTAssertEqual(buffer.currentDuration, 0)
    }
}
