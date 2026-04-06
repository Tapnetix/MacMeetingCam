import XCTest
import AppKit

// MARK: - Lightweight Snapshot Testing for XCUITests
//
// The SnapshotTesting package cannot be imported in XCUITest targets on Swift 6.1+
// because Xcode aliases the `Testing` module to `_Testing_Unavailable` in UI test
// bundles, and SnapshotTesting requires it as a transitive dependency.
//
// This file implements a minimal snapshot comparison engine that follows the same
// directory conventions as swift-snapshot-testing:
//   - Reference images: `__Snapshots__/<TestClassName>/` next to the test file
//   - New/failed snapshots: `NSTemporaryDirectory()/MacMeetingCamSnapshots/` (writable from sandbox)
//   - Auto-records on first run when no reference exists
//   - Supports pixel precision tolerance

/// Set to `true` to force re-recording all reference snapshots.
private var snapshotIsRecording = false

/// Default pixel precision threshold (0.0 - 1.0). Fraction of pixels that must match.
/// Using 0.90 to accommodate window focus state, animation timing, and rendering variance.
private let defaultPrecision: Float = 0.90

/// Asserts that an NSImage matches a stored reference snapshot.
///
/// Reference images are read from `Tests/E2ETests/__Snapshots__/VisualRegressionTests/`
/// in the source tree (readable by the sandboxed test runner).
///
/// When recording (first run or `snapshotIsRecording = true`), new images are saved
/// to `/tmp/MacMeetingCamSnapshots/` and the test fails with a message showing the
/// path. Copy new references into the source tree to make subsequent runs pass.
///
/// - Parameters:
///   - image: The image to compare.
///   - name: A human-readable name used as the filename component.
///   - precision: Fraction of pixels that must match (default 0.98).
///   - file: The source file (auto-filled).
///   - testName: The test function name (auto-filled).
///   - line: The source line (auto-filled).
private func assertImageSnapshot(
    of image: NSImage,
    named name: String,
    precision: Float = defaultPrecision,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    // Reference directory: alongside the test source file
    let fileURL = URL(fileURLWithPath: "\(file)", isDirectory: false)
    let className = fileURL.deletingPathExtension().lastPathComponent
    let referenceDir = fileURL.deletingLastPathComponent()
        .appendingPathComponent("__Snapshots__")
        .appendingPathComponent(className)

    // Output directory: NSTemporaryDirectory() returns the sandboxed-writable temp path
    let outputDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("MacMeetingCamSnapshots")
        .appendingPathComponent(className)

    let sanitizedTestName = testName
        .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "-", options: .regularExpression)
        .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
    let sanitizedName = name
        .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "-", options: .regularExpression)
        .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)

    let filename = "\(sanitizedTestName).\(sanitizedName).png"
    let referenceFileURL = referenceDir.appendingPathComponent(filename)
    let outputFileURL = outputDir.appendingPathComponent(filename)

    let fm = FileManager.default

    guard let pngData = pngRepresentation(of: image) else {
        XCTFail("Failed to create PNG representation of captured image", file: file, line: line)
        return
    }

    // Ensure output directory exists
    do {
        try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)
    } catch {
        XCTFail("Failed to create output directory \(outputDir.path): \(error)", file: file, line: line)
        return
    }

    // Recording mode: always save and fail
    if snapshotIsRecording {
        do {
            try pngData.write(to: outputFileURL)
        } catch {
            XCTFail("Failed to write snapshot: \(error)", file: file, line: line)
            return
        }
        XCTFail(
            "Record mode is on. Recorded snapshot to: \(outputFileURL.path)\n"
            + "Copy to source tree: cp \"\(outputFileURL.path)\" \"\(referenceFileURL.path)\"\n"
            + "Then set snapshotIsRecording = false and re-run.",
            file: file, line: line
        )
        return
    }

    // No reference on disk: auto-record and fail with instructions
    guard fm.fileExists(atPath: referenceFileURL.path) else {
        do {
            try pngData.write(to: outputFileURL)
        } catch {
            XCTFail("Failed to write snapshot: \(error)", file: file, line: line)
            return
        }
        XCTFail(
            "No reference snapshot found on disk. Recorded new snapshot to: \(outputFileURL.path)\n"
            + "To adopt as reference, run:\n"
            + "  mkdir -p \"\(referenceDir.path)\" && cp \"\(outputFileURL.path)\" \"\(referenceFileURL.path)\"\n"
            + "Then re-run the test to compare against this reference.",
            file: file, line: line
        )
        return
    }

    // Load reference and compare
    guard let referenceData = try? Data(contentsOf: referenceFileURL),
          let referenceImage = NSImage(data: referenceData)
    else {
        XCTFail("Failed to load reference snapshot from \(referenceFileURL.path)", file: file, line: line)
        return
    }

    if let mismatch = compareImages(reference: referenceImage, actual: image, precision: precision) {
        // Save the failed snapshot for debugging
        let failedFilename = "\(sanitizedTestName).\(sanitizedName)_FAILED.png"
        let failedURL = outputDir.appendingPathComponent(failedFilename)
        try? pngData.write(to: failedURL)
        XCTFail(
            "Snapshot \"\(name)\" does not match reference. \(mismatch)\n"
            + "Failed snapshot saved to: \(failedURL.path)\n"
            + "Reference: \(referenceFileURL.path)",
            file: file, line: line
        )
    }
}

/// Creates a PNG `Data` representation from an `NSImage`.
private func pngRepresentation(of image: NSImage) -> Data? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return nil
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = image.size
    return rep.representation(using: .png, properties: [:])
}

/// Compares two images pixel-by-pixel and returns a failure description if they
/// differ beyond the allowed precision, or `nil` if they match.
private func compareImages(reference: NSImage, actual: NSImage, precision: Float) -> String? {
    guard let refCG = reference.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let actCG = actual.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
        return "Could not extract CGImage from one or both images."
    }

    guard actCG.width != 0, actCG.height != 0 else {
        return "Captured image is empty."
    }

    guard refCG.width == actCG.width, refCG.height == actCG.height else {
        return "Size mismatch: reference=\(refCG.width)x\(refCG.height), "
            + "actual=\(actCG.width)x\(actCG.height)."
    }

    guard let refCtx = bitmapContext(for: refCG), let refData = refCtx.data,
          let actCtx = bitmapContext(for: actCG), let actData = actCtx.data
    else {
        return "Could not create bitmap contexts for comparison."
    }

    let byteCount = refCtx.height * refCtx.bytesPerRow

    // Fast path: exact match
    if memcmp(refData, actData, byteCount) == 0 {
        return nil
    }

    if precision >= 1.0 {
        return "Images differ (exact match required)."
    }

    // Count differing bytes
    let refPtr = refData.assumingMemoryBound(to: UInt8.self)
    let actPtr = actData.assumingMemoryBound(to: UInt8.self)
    var differentByteCount = 0
    var index = 0
    while index < byteCount {
        if refPtr[index] != actPtr[index] {
            differentByteCount += 1
        }
        index += 1
    }

    let actualPrecision = 1.0 - Float(differentByteCount) / Float(byteCount)
    if actualPrecision < precision {
        return String(
            format: "Image precision %.4f is below required %.4f.",
            actualPrecision, precision
        )
    }

    return nil
}

/// Creates a normalized RGBA bitmap context for an image so comparisons are consistent.
private func bitmapContext(for cgImage: CGImage) -> CGContext? {
    guard let space = cgImage.colorSpace else { return nil }
    guard let ctx = CGContext(
        data: nil,
        width: cgImage.width,
        height: cgImage.height,
        bitsPerComponent: cgImage.bitsPerComponent,
        bytesPerRow: cgImage.bytesPerRow,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    return ctx
}

// MARK: - Visual Regression Tests

final class VisualRegressionTests: XCTestCase {

    // MARK: - Configuration

    /// On the very first run no reference images exist. The helper automatically
    /// records them to `NSTemporaryDirectory()/MacMeetingCamSnapshots/` and fails with
    /// instructions to copy the images into the source tree.
    ///
    /// To force re-recording all snapshots after a deliberate UI change, set
    /// `snapshotIsRecording = true` in `setUp()` and run once, then set it back.
    override func setUp() {
        super.setUp()
        // Uncomment to force re-record all reference snapshots:
        // snapshotIsRecording = true
    }

    // MARK: - Helpers

    private func launchApp(skipOnboarding: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-settings", "--e2e-testing"]
        if skipOnboarding {
            app.launchArguments.append("--skip-onboarding")
        }
        app.launch()
        return app
    }

    private func navigateToTab(_ tabName: String, in app: XCUIApplication) {
        let tab = app.staticTexts[tabName]
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
            // Allow content to settle before capturing
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// Captures a screenshot of the app's main window and returns it as an NSImage.
    private func captureWindowSnapshot(_ app: XCUIApplication) -> NSImage {
        let screenshot = app.windows.firstMatch.screenshot()
        return screenshot.image
    }

    // MARK: - Settings Tab Snapshots

    func testCameraTabSnapshot() {
        let app = launchApp()

        // Camera tab is the default; wait for it to fully render
        let cameraLabel = app.staticTexts["Source Camera"]
        XCTAssertTrue(cameraLabel.waitForExistence(timeout: 5), "Camera tab should load")
        Thread.sleep(forTimeInterval: 0.5)

        let image = captureWindowSnapshot(app)
        assertImageSnapshot(of: image, named: "Settings_CameraTab")
    }

    func testBackgroundTabSnapshot() {
        let app = launchApp()
        navigateToTab("Background", in: app)

        let image = captureWindowSnapshot(app)
        assertImageSnapshot(of: image, named: "Settings_BackgroundTab")
    }

    func testLoopTabSnapshot() {
        let app = launchApp()
        navigateToTab("Loop", in: app)

        let image = captureWindowSnapshot(app)
        assertImageSnapshot(of: image, named: "Settings_LoopTab")
    }

    func testHotkeysTabSnapshot() {
        let app = launchApp()
        navigateToTab("Hotkeys", in: app)

        let image = captureWindowSnapshot(app)
        assertImageSnapshot(of: image, named: "Settings_HotkeysTab")
    }

    func testGeneralTabSnapshot() {
        let app = launchApp()
        navigateToTab("General", in: app)

        let image = captureWindowSnapshot(app)
        assertImageSnapshot(of: image, named: "Settings_GeneralTab")
    }

    // MARK: - Onboarding Snapshots

    func testOnboardingWelcomeSnapshot() {
        let app = launchApp(skipOnboarding: false)

        let welcomeTitle = app.staticTexts["welcomeTitle"]
        guard welcomeTitle.waitForExistence(timeout: 5) else {
            XCTFail("Welcome screen did not appear")
            return
        }
        Thread.sleep(forTimeInterval: 0.5)

        let image = captureWindowSnapshot(app)
        assertImageSnapshot(of: image, named: "Onboarding_Welcome")
    }

    // MARK: - Background Mode Variant Snapshots

    func testBackgroundTabBlurModeSnapshot() {
        let app = launchApp()
        navigateToTab("Background", in: app)

        // Enable the background effect if not already on
        let effectToggle = app.checkBoxes["backgroundEffectToggle"].firstMatch
        let effectSwitch = app.switches["backgroundEffectToggle"].firstMatch
        if effectToggle.waitForExistence(timeout: 3) {
            if effectToggle.value as? String == "0" {
                effectToggle.tap()
            }
        } else if effectSwitch.waitForExistence(timeout: 1) {
            if effectSwitch.value as? String == "0" {
                effectSwitch.tap()
            }
        }

        // Select the Blur mode via segmented control or button
        let blurButton = app.buttons["Blur"].firstMatch
        let blurRadio = app.radioButtons["Blur"].firstMatch
        if blurButton.waitForExistence(timeout: 2) {
            blurButton.tap()
        } else if blurRadio.waitForExistence(timeout: 1) {
            blurRadio.tap()
        }

        Thread.sleep(forTimeInterval: 0.5)

        let image = captureWindowSnapshot(app)
        assertImageSnapshot(of: image, named: "Settings_BackgroundTab_BlurMode")
    }
}
