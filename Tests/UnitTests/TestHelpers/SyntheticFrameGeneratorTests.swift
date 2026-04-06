import XCTest
import CoreMedia
import CoreVideo

// SyntheticFrameGenerator and TimedFrame are in the test target (Tests/TestHelpers),
// so no @testable import needed for those types.

final class SyntheticFrameGeneratorTests: XCTestCase {

    // MARK: - solidColor tests

    func testSolidColor_returnsBGRAPixelBuffer() {
        let buffer = SyntheticFrameGenerator.solidColor(
            width: 640, height: 480, red: 255, green: 0, blue: 0
        )
        XCTAssertNotNil(buffer, "solidColor should return a non-nil pixel buffer")
    }

    func testSolidColor_hasCorrectDimensions() {
        let width = 320
        let height = 240
        let buffer = SyntheticFrameGenerator.solidColor(
            width: width, height: height, red: 0, green: 255, blue: 0
        )
        XCTAssertNotNil(buffer)
        guard let buffer = buffer else { return }
        XCTAssertEqual(CVPixelBufferGetWidth(buffer), width)
        XCTAssertEqual(CVPixelBufferGetHeight(buffer), height)
    }

    func testSolidColor_hasCorrectPixelFormat() {
        let buffer = SyntheticFrameGenerator.solidColor(
            width: 64, height: 64, red: 0, green: 0, blue: 255
        )
        XCTAssertNotNil(buffer)
        guard let buffer = buffer else { return }
        let format = CVPixelBufferGetPixelFormatType(buffer)
        XCTAssertEqual(format, kCVPixelFormatType_32BGRA, "Pixel format should be BGRA")
    }

    // MARK: - timedFrame tests

    func testTimedFrame_hasCorrectTimestamp() {
        let result = SyntheticFrameGenerator.timedFrame(
            width: 64, height: 64, red: 128, green: 128, blue: 128, timestampSeconds: 2.5
        )
        XCTAssertNotNil(result.buffer, "timedFrame should produce a non-nil buffer")
        XCTAssertEqual(
            CMTimeGetSeconds(result.time),
            2.5,
            accuracy: 0.001,
            "Timestamp should be 2.5 seconds"
        )
    }

    func testTimedFrame_hasCorrectDimensions() {
        let result = SyntheticFrameGenerator.timedFrame(
            width: 100, height: 200, red: 0, green: 0, blue: 0, timestampSeconds: 0.0
        )
        XCTAssertNotNil(result.buffer)
        guard let buffer = result.buffer else { return }
        XCTAssertEqual(CVPixelBufferGetWidth(buffer), 100)
        XCTAssertEqual(CVPixelBufferGetHeight(buffer), 200)
    }

    // MARK: - gradientMask tests

    func testGradientMask_hasCorrectDimensions() {
        let width = 128
        let height = 256
        let buffer = SyntheticFrameGenerator.gradientMask(width: width, height: height)
        XCTAssertNotNil(buffer)
        guard let buffer = buffer else { return }
        XCTAssertEqual(CVPixelBufferGetWidth(buffer), width)
        XCTAssertEqual(CVPixelBufferGetHeight(buffer), height)
    }

    func testGradientMask_hasCorrectPixelFormat() {
        let buffer = SyntheticFrameGenerator.gradientMask(width: 64, height: 64)
        XCTAssertNotNil(buffer)
        guard let buffer = buffer else { return }
        let format = CVPixelBufferGetPixelFormatType(buffer)
        XCTAssertEqual(
            format,
            kCVPixelFormatType_OneComponent8,
            "Gradient mask should be OneComponent8 format"
        )
    }

    // MARK: - personMask tests

    func testPersonMask_centerOfPersonRegionIsWhite() {
        let width = 100
        let height = 100
        let personRect = CGRect(x: 25, y: 25, width: 50, height: 50)

        let buffer = SyntheticFrameGenerator.personMask(
            width: width, height: height, personRect: personRect
        )
        XCTAssertNotNil(buffer)
        guard let buffer = buffer else { return }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            XCTFail("Could not get base address")
            return
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let data = baseAddress.assumingMemoryBound(to: UInt8.self)

        // Center of the person region (50, 50)
        let centerX = 50
        let centerY = 50
        let centerValue = data[centerY * bytesPerRow + centerX]
        XCTAssertEqual(centerValue, 255, "Center of person region should be white (255)")
    }

    func testPersonMask_cornerIsBlack() {
        let width = 100
        let height = 100
        let personRect = CGRect(x: 25, y: 25, width: 50, height: 50)

        let buffer = SyntheticFrameGenerator.personMask(
            width: width, height: height, personRect: personRect
        )
        XCTAssertNotNil(buffer)
        guard let buffer = buffer else { return }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            XCTFail("Could not get base address")
            return
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let data = baseAddress.assumingMemoryBound(to: UInt8.self)

        // Top-left corner (0, 0) — outside person rect
        let cornerValue = data[0 * bytesPerRow + 0]
        XCTAssertEqual(cornerValue, 0, "Corner outside person region should be black (0)")
    }

    // MARK: - frameSequence tests

    func testFrameSequence_hasCorrectCount() {
        let count = 5
        let frames = SyntheticFrameGenerator.frameSequence(
            count: count, width: 64, height: 64, fps: 30
        )
        XCTAssertEqual(frames.count, count, "Should generate exactly \(count) frames")
    }

    func testFrameSequence_hasSequentialTimestamps() {
        let fps = 30
        let count = 4
        let frames = SyntheticFrameGenerator.frameSequence(
            count: count, width: 64, height: 64, fps: fps
        )

        let expectedInterval = 1.0 / Double(fps)

        for i in 0..<count {
            let expectedTime = Double(i) * expectedInterval
            let actualTime = CMTimeGetSeconds(frames[i].timestamp)
            XCTAssertEqual(
                actualTime,
                expectedTime,
                accuracy: 0.0001,
                "Frame \(i) should have timestamp \(expectedTime), got \(actualTime)"
            )
        }
    }

    func testFrameSequence_framesHaveNonNilBuffers() {
        let frames = SyntheticFrameGenerator.frameSequence(
            count: 3, width: 64, height: 64, fps: 30
        )
        for (i, frame) in frames.enumerated() {
            XCTAssertEqual(
                CVPixelBufferGetWidth(frame.buffer), 64,
                "Frame \(i) should have correct width"
            )
            XCTAssertEqual(
                CVPixelBufferGetHeight(frame.buffer), 64,
                "Frame \(i) should have correct height"
            )
        }
    }
}
