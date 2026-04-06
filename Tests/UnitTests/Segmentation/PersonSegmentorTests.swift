import XCTest
import CoreVideo
@testable import MacMeetingCam

// MARK: - MockSegmentor Tests

final class MockSegmentorTests: XCTestCase {

    // MARK: - testMockSegmentorReturnsMaskWithCorrectDimensions

    func testMockSegmentorReturnsMaskWithCorrectDimensions() async throws {
        let segmentor = MockSegmentor()
        let input = try XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 100, green: 150, blue: 200)
        )

        let mask = try await segmentor.segment(pixelBuffer: input)

        XCTAssertEqual(CVPixelBufferGetWidth(mask), 640)
        XCTAssertEqual(CVPixelBufferGetHeight(mask), 480)
    }

    // MARK: - testMockSegmentorReturnsSingleChannelMask

    func testMockSegmentorReturnsSingleChannelMask() async throws {
        let segmentor = MockSegmentor()
        let input = try XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 320, height: 240, red: 50, green: 100, blue: 150)
        )

        let mask = try await segmentor.segment(pixelBuffer: input)
        let pixelFormat = CVPixelBufferGetPixelFormatType(mask)

        XCTAssertEqual(pixelFormat, kCVPixelFormatType_OneComponent8)
    }

    // MARK: - testMockSegmentorWithCustomMask

    func testMockSegmentorWithCustomMask() async throws {
        let customMask = try XCTUnwrap(
            SyntheticFrameGenerator.gradientMask(width: 100, height: 100)
        )
        let segmentor = MockSegmentor(fixedMask: customMask)

        let input = try XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 0, green: 0, blue: 0)
        )

        let result = try await segmentor.segment(pixelBuffer: input)

        // Should return the exact same buffer object
        XCTAssertTrue(result === customMask, "Expected the fixed mask to be returned")
        XCTAssertEqual(CVPixelBufferGetWidth(result), 100)
        XCTAssertEqual(CVPixelBufferGetHeight(result), 100)
    }

    // MARK: - testMockSegmentorTracksCallCount

    func testMockSegmentorTracksCallCount() async throws {
        let segmentor = MockSegmentor()
        let input = try XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 320, height: 240, red: 128, green: 128, blue: 128)
        )

        XCTAssertEqual(segmentor.segmentCallCount, 0)

        _ = try await segmentor.segment(pixelBuffer: input)
        XCTAssertEqual(segmentor.segmentCallCount, 1)

        _ = try await segmentor.segment(pixelBuffer: input)
        XCTAssertEqual(segmentor.segmentCallCount, 2)

        _ = try await segmentor.segment(pixelBuffer: input)
        XCTAssertEqual(segmentor.segmentCallCount, 3)
    }

    // MARK: - testSegmentorQualityOptions

    func testSegmentorQualityOptions() {
        var segmentor = MockSegmentor(quality: .fast)
        XCTAssertEqual(segmentor.quality, .fast)

        segmentor.quality = .balanced
        XCTAssertEqual(segmentor.quality, .balanced)

        segmentor.quality = .accurate
        XCTAssertEqual(segmentor.quality, .accurate)

        // Verify all cases exist
        XCTAssertEqual(SegmentationQuality.allCases.count, 3)
        XCTAssertTrue(SegmentationQuality.allCases.contains(.fast))
        XCTAssertTrue(SegmentationQuality.allCases.contains(.balanced))
        XCTAssertTrue(SegmentationQuality.allCases.contains(.accurate))
    }
}

// MARK: - VisionSegmentor Tests

final class VisionSegmentorTests: XCTestCase {

    // MARK: - testSegmentsFrameAndReturnsMask

    func testSegmentsFrameAndReturnsMask() async throws {
        let segmentor = VisionSegmentor(quality: .fast)
        let input = try XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 100, green: 150, blue: 200)
        )

        let mask = try await segmentor.segment(pixelBuffer: input)

        // The mask should have the same dimensions as the input
        XCTAssertEqual(CVPixelBufferGetWidth(mask), 640)
        XCTAssertEqual(CVPixelBufferGetHeight(mask), 480)
    }

    // MARK: - testBalancedQualityUsesCorrectRevision

    func testBalancedQualityUsesCorrectRevision() {
        let segmentor = VisionSegmentor(quality: .balanced)
        XCTAssertEqual(segmentor.quality, .balanced)
        XCTAssertEqual(segmentor.quality.visionQualityLevel, .balanced)
    }

    // MARK: - testAccurateQualityUsesCorrectRevision

    func testAccurateQualityUsesCorrectRevision() {
        let segmentor = VisionSegmentor(quality: .accurate)
        XCTAssertEqual(segmentor.quality, .accurate)
        XCTAssertEqual(segmentor.quality.visionQualityLevel, .accurate)
    }

    // MARK: - testQualityCanBeChanged

    func testQualityCanBeChanged() {
        var segmentor = VisionSegmentor(quality: .fast)
        XCTAssertEqual(segmentor.quality, .fast)
        XCTAssertEqual(segmentor.quality.visionQualityLevel, .fast)

        segmentor.quality = .balanced
        XCTAssertEqual(segmentor.quality, .balanced)
        XCTAssertEqual(segmentor.quality.visionQualityLevel, .balanced)

        segmentor.quality = .accurate
        XCTAssertEqual(segmentor.quality, .accurate)
        XCTAssertEqual(segmentor.quality.visionQualityLevel, .accurate)
    }
}
