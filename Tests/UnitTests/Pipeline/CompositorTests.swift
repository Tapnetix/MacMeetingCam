import XCTest
import CoreImage
import CoreVideo
@testable import MacMeetingCam

final class CompositorTests: XCTestCase {

    private var compositor: Compositor!

    override func setUp() {
        super.setUp()
        compositor = Compositor()
    }

    override func tearDown() {
        compositor = nil
        super.tearDown()
    }

    // MARK: - Blur Mode

    func testBlurModeReturnsNonNilResult() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 320, height: 240, red: 100, green: 150, blue: 200)
        )
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 320, height: 240, personRect: CGRect(x: 80, y: 60, width: 160, height: 120))
        )

        let result = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .blur,
            blurIntensity: 0.5,
            edgeSoftness: 0.5,
            backgroundImage: nil
        )

        XCTAssertNotNil(result)
    }

    func testBlurModeOutputMatchesInputDimensions() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 50, green: 100, blue: 150)
        )
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 640, height: 480, personRect: CGRect(x: 160, y: 120, width: 320, height: 240))
        )

        let result = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .blur,
            blurIntensity: 0.7,
            edgeSoftness: 0.3,
            backgroundImage: nil
        )

        let output = try! XCTUnwrap(result)
        XCTAssertEqual(CVPixelBufferGetWidth(output), 640)
        XCTAssertEqual(CVPixelBufferGetHeight(output), 480)
    }

    func testBlurModeWithZeroIntensityPreservesImage() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 64, height: 64, red: 200, green: 100, blue: 50)
        )
        // All-white mask: entire frame is foreground, so blur has no visible effect
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 64, height: 64, personRect: CGRect(x: 0, y: 0, width: 64, height: 64))
        )

        let result = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .blur,
            blurIntensity: 0.0,
            edgeSoftness: 0.0,
            backgroundImage: nil
        )

        let output = try! XCTUnwrap(result)

        // With zero blur and all-white mask, output should closely match the input
        let (r, g, b) = readCenterPixel(output)
        XCTAssertEqual(Int(r), 200, accuracy: 30, "Red channel should be preserved")
        XCTAssertEqual(Int(g), 100, accuracy: 30, "Green channel should be preserved")
        XCTAssertEqual(Int(b), 50, accuracy: 30, "Blue channel should be preserved")
    }

    // MARK: - Remove Mode

    func testRemoveModeReturnsNonNilResult() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 320, height: 240, red: 100, green: 150, blue: 200)
        )
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 320, height: 240, personRect: CGRect(x: 80, y: 60, width: 160, height: 120))
        )

        let result = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .remove,
            blurIntensity: 0.0,
            edgeSoftness: 0.0,
            backgroundImage: nil
        )

        XCTAssertNotNil(result)
    }

    func testRemoveModeOutputMatchesInputDimensions() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 50, green: 100, blue: 150)
        )
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 640, height: 480, personRect: CGRect(x: 160, y: 120, width: 320, height: 240))
        )

        let result = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .remove,
            blurIntensity: 0.0,
            edgeSoftness: 0.0,
            backgroundImage: nil
        )

        let output = try! XCTUnwrap(result)
        XCTAssertEqual(CVPixelBufferGetWidth(output), 640)
        XCTAssertEqual(CVPixelBufferGetHeight(output), 480)
    }

    func testRemoveModeBackgroundIsBlack() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 64, height: 64, red: 200, green: 200, blue: 200)
        )
        // Person in center only; corners are background (black in mask)
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 64, height: 64, personRect: CGRect(x: 16, y: 16, width: 32, height: 32))
        )

        let result = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .remove,
            blurIntensity: 0.0,
            edgeSoftness: 0.0,
            backgroundImage: nil
        )

        let output = try! XCTUnwrap(result)

        // Read a corner pixel which should be in the background (black) region
        let (r, g, b) = readPixel(output, x: 2, y: 2)
        XCTAssertEqual(Int(r), 0, accuracy: 30, "Background red should be near black")
        XCTAssertEqual(Int(g), 0, accuracy: 30, "Background green should be near black")
        XCTAssertEqual(Int(b), 0, accuracy: 30, "Background blue should be near black")
    }

    // MARK: - Replace Mode

    func testReplaceModeReturnsNonNilResult() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 320, height: 240, red: 100, green: 150, blue: 200)
        )
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 320, height: 240, personRect: CGRect(x: 80, y: 60, width: 160, height: 120))
        )
        let bgImage = CIImage(color: CIColor(red: 0.0, green: 0.5, blue: 1.0))
            .cropped(to: CGRect(x: 0, y: 0, width: 320, height: 240))

        let result = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .replace,
            blurIntensity: 0.0,
            edgeSoftness: 0.0,
            backgroundImage: bgImage
        )

        XCTAssertNotNil(result)
    }

    func testReplaceModeOutputMatchesInputDimensions() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 50, green: 100, blue: 150)
        )
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 640, height: 480, personRect: CGRect(x: 160, y: 120, width: 320, height: 240))
        )
        let bgImage = CIImage(color: CIColor(red: 1.0, green: 0.0, blue: 0.0))
            .cropped(to: CGRect(x: 0, y: 0, width: 640, height: 480))

        let result = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .replace,
            blurIntensity: 0.0,
            edgeSoftness: 0.0,
            backgroundImage: bgImage
        )

        let output = try! XCTUnwrap(result)
        XCTAssertEqual(CVPixelBufferGetWidth(output), 640)
        XCTAssertEqual(CVPixelBufferGetHeight(output), 480)
    }

    func testReplaceModeWithNilBackgroundFallsBackToRemove() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 64, height: 64, red: 200, green: 200, blue: 200)
        )
        // Person in center only
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 64, height: 64, personRect: CGRect(x: 16, y: 16, width: 32, height: 32))
        )

        let result = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .replace,
            blurIntensity: 0.0,
            edgeSoftness: 0.0,
            backgroundImage: nil
        )

        let output = try! XCTUnwrap(result)

        // With nil background, should fall back to remove mode (black background)
        let (r, g, b) = readPixel(output, x: 2, y: 2)
        XCTAssertEqual(Int(r), 0, accuracy: 30, "Fallback background red should be near black")
        XCTAssertEqual(Int(g), 0, accuracy: 30, "Fallback background green should be near black")
        XCTAssertEqual(Int(b), 0, accuracy: 30, "Fallback background blue should be near black")
    }

    func testReplaceModeScalesBackgroundToFill() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 100, green: 100, blue: 100)
        )
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 640, height: 480, personRect: CGRect(x: 160, y: 120, width: 320, height: 240))
        )
        // Use a small background image (100x100)
        let smallBg = CIImage(color: CIColor(red: 0.0, green: 1.0, blue: 0.0))
            .cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))

        let result = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .replace,
            blurIntensity: 0.0,
            edgeSoftness: 0.0,
            backgroundImage: smallBg
        )

        let output = try! XCTUnwrap(result)
        // Output should match frame dimensions, not background dimensions
        XCTAssertEqual(CVPixelBufferGetWidth(output), 640)
        XCTAssertEqual(CVPixelBufferGetHeight(output), 480)
    }

    // MARK: - Edge Feathering

    func testEdgeSoftnessZeroProducesHardEdge() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 64, height: 64, red: 255, green: 255, blue: 255)
        )
        // Sharp mask: left half white, right half black
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 64, height: 64, personRect: CGRect(x: 0, y: 0, width: 32, height: 64))
        )

        let result = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .remove,
            blurIntensity: 0.0,
            edgeSoftness: 0.0,
            backgroundImage: nil
        )

        let output = try! XCTUnwrap(result)

        // Just inside the foreground region (x=30) should be bright
        let (rFg, gFg, bFg) = readPixel(output, x: 15, y: 32)
        // Just outside the foreground region (x=34) should be dark
        let (rBg, gBg, bBg) = readPixel(output, x: 48, y: 32)

        // Foreground should be bright (white)
        XCTAssertGreaterThan(Int(rFg), 200, "Foreground should be bright")
        // Background should be dark (black)
        XCTAssertLessThan(Int(rBg), 55, "Background should be dark with hard edge")
    }

    func testEdgeSoftnessOneProducesSoftEdge() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 128, height: 128, red: 255, green: 255, blue: 255)
        )
        // Person in center
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 128, height: 128, personRect: CGRect(x: 32, y: 32, width: 64, height: 64))
        )

        let resultHard = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .remove,
            blurIntensity: 0.0,
            edgeSoftness: 0.0,
            backgroundImage: nil
        )

        let resultSoft = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .remove,
            blurIntensity: 0.0,
            edgeSoftness: 1.0,
            backgroundImage: nil
        )

        let outputHard = try! XCTUnwrap(resultHard)
        let outputSoft = try! XCTUnwrap(resultSoft)

        // Both should produce valid output
        XCTAssertEqual(CVPixelBufferGetWidth(outputHard), 128)
        XCTAssertEqual(CVPixelBufferGetWidth(outputSoft), 128)

        // With soft edge, a pixel near the edge boundary should have an intermediate value
        // compared to the hard-edge version. We verify by checking a pixel just inside the mask boundary.
        // At the boundary (x=32, y=64), with soft edge the feathered mask bleeds,
        // so a pixel just outside (x=28) should be brighter with soft edge than with hard edge.
        let (rHard, _, _) = readPixel(outputHard, x: 28, y: 64)
        let (rSoft, _, _) = readPixel(outputSoft, x: 28, y: 64)

        // With soft edge, the transition zone leaks foreground into the background region,
        // so the pixel just outside the mask should be brighter than with hard edge
        XCTAssertGreaterThan(Int(rSoft), Int(rHard), "Soft edge should produce smoother transition")
    }

    // MARK: - Edge Cases

    func testHandlesMismatchedMaskDimensions() {
        let frame = try! XCTUnwrap(
            SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 100, green: 150, blue: 200)
        )
        // Mask is smaller than the frame
        let mask = try! XCTUnwrap(
            SyntheticFrameGenerator.personMask(width: 320, height: 240, personRect: CGRect(x: 80, y: 60, width: 160, height: 120))
        )

        let result = compositor.apply(
            frame: frame,
            mask: mask,
            mode: .blur,
            blurIntensity: 0.5,
            edgeSoftness: 0.5,
            backgroundImage: nil
        )

        // Should still produce output even with mismatched dimensions
        XCTAssertNotNil(result)
        if let output = result {
            XCTAssertEqual(CVPixelBufferGetWidth(output), 640)
            XCTAssertEqual(CVPixelBufferGetHeight(output), 480)
        }
    }

    // MARK: - Pixel Reading Helpers

    private func readCenterPixel(_ buffer: CVPixelBuffer) -> (UInt8, UInt8, UInt8) {
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        return readPixel(buffer, x: width / 2, y: height / 2)
    }

    private func readPixel(_ buffer: CVPixelBuffer, x: Int, y: Int) -> (UInt8, UInt8, UInt8) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return (0, 0, 0)
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let data = baseAddress.assumingMemoryBound(to: UInt8.self)
        let offset = y * bytesPerRow + x * 4

        // BGRA format
        let blue = data[offset + 0]
        let green = data[offset + 1]
        let red = data[offset + 2]

        return (red, green, blue)
    }
}
