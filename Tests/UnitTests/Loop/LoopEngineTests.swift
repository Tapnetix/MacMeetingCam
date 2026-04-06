import XCTest
import CoreMedia
import CoreVideo
@testable import MacMeetingCam

final class LoopEngineTests: XCTestCase {

    // MARK: - testInitialModeIsIdle

    func testInitialModeIsIdle() {
        let engine = LoopEngine(crossfadeDuration: 0.5, resumeTransition: 0.3)
        XCTAssertEqual(engine.mode, .idle)
    }

    // MARK: - testActivateFreezeSetsModeToFrozen

    func testActivateFreezeSetsModeToFrozen() {
        let engine = LoopEngine(crossfadeDuration: 0.5, resumeTransition: 0.3)
        let frame = SyntheticFrameGenerator.solidColor(width: 64, height: 64, red: 255, green: 0, blue: 0)!

        engine.activateFreeze(lastFrame: frame)

        XCTAssertEqual(engine.mode, .frozen)
    }

    // MARK: - testFreezeReturnsLastFrame

    func testFreezeReturnsLastFrame() {
        let engine = LoopEngine(crossfadeDuration: 0.5, resumeTransition: 0.3)
        let frame = SyntheticFrameGenerator.solidColor(width: 64, height: 64, red: 255, green: 0, blue: 0)!

        engine.activateFreeze(lastFrame: frame)

        let t1 = CMTime(seconds: 0, preferredTimescale: 600)
        let t2 = CMTime(seconds: 1, preferredTimescale: 600)
        let t3 = CMTime(seconds: 2, preferredTimescale: 600)

        let result1 = engine.nextFrame(at: t1)
        let result2 = engine.nextFrame(at: t2)
        let result3 = engine.nextFrame(at: t3)

        // All should return the same frozen frame
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertNotNil(result3)

        // CVPixelBuffers are reference types, so identity check works
        XCTAssertTrue(result1 === frame)
        XCTAssertTrue(result2 === frame)
        XCTAssertTrue(result3 === frame)
    }

    // MARK: - testDeactivateFreezeReturnsFrozenFrame

    func testDeactivateFreezeReturnsFrozenFrame() {
        let engine = LoopEngine(crossfadeDuration: 0.5, resumeTransition: 0.3)
        let frame = SyntheticFrameGenerator.solidColor(width: 64, height: 64, red: 255, green: 0, blue: 0)!

        engine.activateFreeze(lastFrame: frame)
        let returned = engine.deactivateFreeze()

        XCTAssertNotNil(returned)
        XCTAssertTrue(returned === frame)
    }

    // MARK: - testDeactivateFreezeSetsModeToIdle

    func testDeactivateFreezeSetsModeToIdle() {
        let engine = LoopEngine(crossfadeDuration: 0.5, resumeTransition: 0.3)
        let frame = SyntheticFrameGenerator.solidColor(width: 64, height: 64, red: 255, green: 0, blue: 0)!

        engine.activateFreeze(lastFrame: frame)
        XCTAssertEqual(engine.mode, .frozen)

        _ = engine.deactivateFreeze()
        XCTAssertEqual(engine.mode, .idle)
    }

    // MARK: - testActivateLoopSetsModeToLooping

    func testActivateLoopSetsModeToLooping() {
        let engine = LoopEngine(crossfadeDuration: 0.1, resumeTransition: 0.3)
        let frames = SyntheticFrameGenerator.frameSequence(count: 10, width: 64, height: 64, fps: 30)
        let entries = frames.map { FrameBuffer.Entry(buffer: $0.buffer, timestamp: $0.timestamp) }

        engine.activateLoop(frames: entries)

        XCTAssertEqual(engine.mode, .looping)
    }

    // MARK: - testLoopReturnsFramesInSequence

    func testLoopReturnsFramesInSequence() {
        let engine = LoopEngine(crossfadeDuration: 0.0, resumeTransition: 0.3)
        let frames = SyntheticFrameGenerator.frameSequence(count: 5, width: 64, height: 64, fps: 30)
        let entries = frames.map { FrameBuffer.Entry(buffer: $0.buffer, timestamp: $0.timestamp) }

        engine.activateLoop(frames: entries)

        // Use CMTime with same timescale as frame timestamps (30) for exact arithmetic
        let baseTimescale: Int32 = 30
        let baseValue: CMTimeValue = 3000  // arbitrary start

        // Frame 0: offset 0
        let result0 = engine.nextFrame(at: CMTime(value: baseValue, timescale: baseTimescale))
        XCTAssertNotNil(result0)
        XCTAssertTrue(result0 === entries[0].buffer)

        // Frame 1: offset 1/30
        let result1 = engine.nextFrame(at: CMTime(value: baseValue + 1, timescale: baseTimescale))
        XCTAssertNotNil(result1)
        XCTAssertTrue(result1 === entries[1].buffer)

        // Frame 2: offset 2/30
        let result2 = engine.nextFrame(at: CMTime(value: baseValue + 2, timescale: baseTimescale))
        XCTAssertNotNil(result2)
        XCTAssertTrue(result2 === entries[2].buffer)
    }

    // MARK: - testLoopWrapsAround

    func testLoopWrapsAround() {
        // 5 frames at 30fps: offsets 0, 1/30, 2/30, 3/30, 4/30
        // Loop duration = 4/30
        let engine = LoopEngine(crossfadeDuration: 0.0, resumeTransition: 0.3)
        let frames = SyntheticFrameGenerator.frameSequence(count: 5, width: 64, height: 64, fps: 30)
        let entries = frames.map { FrameBuffer.Entry(buffer: $0.buffer, timestamp: $0.timestamp) }

        engine.activateLoop(frames: entries)

        // Use CMTime with same timescale as frames for exact arithmetic
        let baseTimescale: Int32 = 30

        // First frame at time 0
        let first = engine.nextFrame(at: CMTime(value: 0, timescale: baseTimescale))
        XCTAssertNotNil(first)
        XCTAssertTrue(first === entries[0].buffer)

        // After one full loop (4/30 seconds = value 4 at timescale 30): should wrap to frame 0
        let wrapped = engine.nextFrame(at: CMTime(value: 4, timescale: baseTimescale))
        XCTAssertNotNil(wrapped)
        // After wrapping, position 0 should give frame 0
        XCTAssertTrue(wrapped === entries[0].buffer,
            "After one full loop cycle, should return to the first frame")
    }

    // MARK: - testDeactivateLoopSetsModeToIdle

    func testDeactivateLoopSetsModeToIdle() {
        let engine = LoopEngine(crossfadeDuration: 0.1, resumeTransition: 0.3)
        let frames = SyntheticFrameGenerator.frameSequence(count: 5, width: 64, height: 64, fps: 30)
        let entries = frames.map { FrameBuffer.Entry(buffer: $0.buffer, timestamp: $0.timestamp) }

        engine.activateLoop(frames: entries)
        XCTAssertEqual(engine.mode, .looping)

        engine.deactivateLoop()
        XCTAssertEqual(engine.mode, .idle)
    }

    // MARK: - testCrossfadeAlphaLinear

    func testCrossfadeAlphaLinear() {
        let engine = LoopEngine(crossfadeDuration: 0.5, resumeTransition: 0.3)

        XCTAssertEqual(engine.crossfadeAlpha(t: 0.0), 0.0, accuracy: 0.0001)
        XCTAssertEqual(engine.crossfadeAlpha(t: 0.5), 0.5, accuracy: 0.0001)
        XCTAssertEqual(engine.crossfadeAlpha(t: 1.0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(engine.crossfadeAlpha(t: 0.25), 0.25, accuracy: 0.0001)
        XCTAssertEqual(engine.crossfadeAlpha(t: 0.75), 0.75, accuracy: 0.0001)
    }

    // MARK: - testCrossfadeAlphaClamped

    func testCrossfadeAlphaClamped() {
        let engine = LoopEngine(crossfadeDuration: 0.5, resumeTransition: 0.3)

        XCTAssertEqual(engine.crossfadeAlpha(t: -1.0), 0.0, accuracy: 0.0001)
        XCTAssertEqual(engine.crossfadeAlpha(t: -0.5), 0.0, accuracy: 0.0001)
        XCTAssertEqual(engine.crossfadeAlpha(t: 2.0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(engine.crossfadeAlpha(t: 100.0), 1.0, accuracy: 0.0001)
    }

    // MARK: - testFreezeToLoopTransition

    func testFreezeToLoopTransition() {
        let engine = LoopEngine(crossfadeDuration: 0.1, resumeTransition: 0.3)
        let frame = SyntheticFrameGenerator.solidColor(width: 64, height: 64, red: 255, green: 0, blue: 0)!

        // Start frozen
        engine.activateFreeze(lastFrame: frame)
        XCTAssertEqual(engine.mode, .frozen)

        let frozenResult = engine.nextFrame(at: CMTime(seconds: 0, preferredTimescale: 600))
        XCTAssertNotNil(frozenResult)
        XCTAssertTrue(frozenResult === frame)

        // Deactivate freeze
        let returnedFrame = engine.deactivateFreeze()
        XCTAssertEqual(engine.mode, .idle)
        XCTAssertNotNil(returnedFrame)

        // Now activate loop
        let frames = SyntheticFrameGenerator.frameSequence(count: 10, width: 64, height: 64, fps: 30)
        let entries = frames.map { FrameBuffer.Entry(buffer: $0.buffer, timestamp: $0.timestamp) }
        engine.activateLoop(frames: entries)
        XCTAssertEqual(engine.mode, .looping)

        // Should return a loop frame
        let loopResult = engine.nextFrame(at: CMTime(seconds: 0, preferredTimescale: 600))
        XCTAssertNotNil(loopResult)
    }

    // MARK: - testIdleModeReturnsNil

    func testIdleModeReturnsNil() {
        let engine = LoopEngine(crossfadeDuration: 0.5, resumeTransition: 0.3)

        let result = engine.nextFrame(at: CMTime(seconds: 0, preferredTimescale: 600))
        XCTAssertNil(result)
    }
}
