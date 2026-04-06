import XCTest
@testable import MacMeetingCam

final class MemoryEstimatorTests: XCTestCase {

    // MARK: - estimateBytes

    func testEstimateFor30sAt1080p30fps() {
        // 30 * 30 = 900 frames * 1920 * 1080 * 4 = 7,464,960,000
        let bytes = MemoryEstimator.estimateBytes(
            durationSeconds: 30,
            width: 1920,
            height: 1080,
            fps: 30
        )
        XCTAssertEqual(bytes, 7_464_960_000)
    }

    func testEstimateFor3sAt720p30fps() {
        // 3 * 30 = 90 frames * 1280 * 720 * 4 = 331,776,000
        let bytes = MemoryEstimator.estimateBytes(
            durationSeconds: 3,
            width: 1280,
            height: 720,
            fps: 30
        )
        XCTAssertEqual(bytes, 331_776_000)
    }

    func testZeroDurationReturnsZero() {
        let bytes = MemoryEstimator.estimateBytes(
            durationSeconds: 0,
            width: 1920,
            height: 1080,
            fps: 30
        )
        XCTAssertEqual(bytes, 0)
    }

    func testZeroFpsReturnsZero() {
        let bytes = MemoryEstimator.estimateBytes(
            durationSeconds: 30,
            width: 1920,
            height: 1080,
            fps: 0
        )
        XCTAssertEqual(bytes, 0)
    }

    // MARK: - formattedEstimate

    func testFormattedEstimateContainsGB() {
        // 30s at 1080p30 = ~7.46 GB
        let formatted = MemoryEstimator.formattedEstimate(
            durationSeconds: 30,
            width: 1920,
            height: 1080,
            fps: 30
        )
        XCTAssertTrue(formatted.contains("GB"), "Expected GB in '\(formatted)'")
        XCTAssertTrue(formatted.hasPrefix("~"), "Expected leading ~ in '\(formatted)'")
    }

    func testFormattedEstimateContainsMB() {
        // 3s at 720p30 = ~331 MB
        let formatted = MemoryEstimator.formattedEstimate(
            durationSeconds: 3,
            width: 1280,
            height: 720,
            fps: 30
        )
        XCTAssertTrue(formatted.contains("MB"), "Expected MB in '\(formatted)'")
        XCTAssertTrue(formatted.hasPrefix("~"), "Expected leading ~ in '\(formatted)'")
    }
}
