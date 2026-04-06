# MacMeetingCam Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS virtual camera app with background effects (blur/remove/replace) and seamless pause/loop system, following strict red-green TDD with >90% coverage.

**Architecture:** SwiftUI host app with dedicated serial-queue video pipeline (capture → segmentation → compositing → loop buffer → output), communicating with a thin CMIOExtension-based virtual camera via IOSurface shared memory + XPC signaling. Pluggable segmentation via protocol, shipping with Apple Vision framework.

**Tech Stack:** Swift, SwiftUI, AVFoundation, Vision, Core Image, CoreMediaIO, SystemExtensions, SPM (KeyboardShortcuts, Sparkle, ViewInspector, swift-snapshot-testing)

**TDD Protocol:** Every implementation follows red-green: write failing test → verify it fails → write minimal code to pass → verify it passes → commit. Coverage target: >90% of all code paths.

**Design Reference:** `docs/plans/2026-04-06-macmeetingcam-design.md`
**Wireframe Reference:** `wireframes/index.html`

---

## Phase 1: Project Foundation (Tasks 1–6)

### Task 1: Create Xcode Project with All Targets

**Files:**
- Create: `MacMeetingCam.xcodeproj/` (via Xcode CLI / `xcodegen`)
- Create: `MacMeetingCam/App/MacMeetingCamApp.swift`
- Create: `CameraExtension/CameraExtensionMain.swift`
- Create: `project.yml` (XcodeGen spec)

**Step 1: Install XcodeGen if needed**

```bash
brew list xcodegen || brew install xcodegen
```

**Step 2: Create the XcodeGen project spec**

Create `project.yml` at the repo root:

```yaml
name: MacMeetingCam
options:
  bundleIdPrefix: com.tapnetix
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "15.0"
  minimumXcodeGenVersion: "2.38.0"

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "14.0"

packages:
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts
    from: "2.0.0"
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: "2.5.0"
  ViewInspector:
    url: https://github.com/nicklama/ViewInspector
    from: "0.9.0"
  SnapshotTesting:
    url: https://github.com/pointfreeco/swift-snapshot-testing
    from: "1.15.0"

targets:
  MacMeetingCam:
    type: application
    platform: macOS
    sources:
      - path: MacMeetingCam
      - path: Shared
    dependencies:
      - package: KeyboardShortcuts
      - package: Sparkle
      - target: CameraExtension
        embed: true
        codeSign: true
        copy:
          destination: systemExtension
    settings:
      base:
        INFOPLIST_FILE: MacMeetingCam/Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: MacMeetingCam/Resources/MacMeetingCam.entitlements
    entitlements:
      path: MacMeetingCam/Resources/MacMeetingCam.entitlements
      properties:
        com.apple.developer.system-extension.install: true
        com.apple.security.device.camera: true

  CameraExtension:
    type: system-extension
    platform: macOS
    sources:
      - path: CameraExtension
      - path: Shared
    settings:
      base:
        INFOPLIST_FILE: CameraExtension/Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: CameraExtension/Resources/CameraExtension.entitlements
    entitlements:
      path: CameraExtension/Resources/CameraExtension.entitlements
      properties:
        com.apple.developer.system-extension.provider:
          - com.apple.system-extension.cmio

  MacMeetingCamTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/UnitTests
      - path: Tests/TestHelpers
    dependencies:
      - target: MacMeetingCam
      - package: ViewInspector
    settings:
      base:
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/MacMeetingCam.app/Contents/MacOS/MacMeetingCam"
        BUNDLE_LOADER: "$(TEST_HOST)"

  MacMeetingCamIntegrationTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/IntegrationTests
      - path: Tests/TestHelpers
    dependencies:
      - target: MacMeetingCam
    settings:
      base:
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/MacMeetingCam.app/Contents/MacOS/MacMeetingCam"
        BUNDLE_LOADER: "$(TEST_HOST)"

  MacMeetingCamE2ETests:
    type: bundle.ui-testing
    platform: macOS
    sources:
      - path: Tests/E2ETests
    dependencies:
      - target: MacMeetingCam
      - package: SnapshotTesting

  MacMeetingCamPerformanceTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/PerformanceTests
      - path: Tests/TestHelpers
    dependencies:
      - target: MacMeetingCam

schemes:
  MacMeetingCam:
    build:
      targets:
        MacMeetingCam: all
        CameraExtension: all
        MacMeetingCamTests: [test]
        MacMeetingCamIntegrationTests: [test]
        MacMeetingCamE2ETests: [test]
        MacMeetingCamPerformanceTests: [test]
    test:
      gatherCoverageData: true
      coverageTargets:
        - MacMeetingCam
      targets:
        - MacMeetingCamTests
        - MacMeetingCamIntegrationTests
        - MacMeetingCamE2ETests
        - MacMeetingCamPerformanceTests

  "MacMeetingCam (No Extension)":
    build:
      targets:
        MacMeetingCam: all
        MacMeetingCamTests: [test]
        MacMeetingCamIntegrationTests: [test]
        MacMeetingCamE2ETests: [test]
    test:
      gatherCoverageData: true
      coverageTargets:
        - MacMeetingCam
      targets:
        - MacMeetingCamTests
        - MacMeetingCamE2ETests
```

**Step 3: Create minimal source files for each target**

Create `MacMeetingCam/App/MacMeetingCamApp.swift`:

```swift
import SwiftUI

@main
struct MacMeetingCamApp: App {
    var body: some Scene {
        WindowGroup {
            Text("MacMeetingCam")
        }
    }
}
```

Create `CameraExtension/CameraExtensionMain.swift`:

```swift
import Foundation
import CoreMediaIO

// Placeholder — will be implemented in Phase 4
```

Create `Shared/Constants.swift`:

```swift
import Foundation

enum AppConstants {
    static let appName = "MacMeetingCam"
    static let virtualCameraName = "MacMeetingCam"
    static let bundleIdentifier = "com.tapnetix.MacMeetingCam"
    static let extensionBundleIdentifier = "com.tapnetix.MacMeetingCam.CameraExtension"

    enum Defaults {
        static let bufferDuration: TimeInterval = 30.0
        static let minBufferDuration: TimeInterval = 3.0
        static let maxBufferDuration: TimeInterval = 120.0
        static let crossfadeDuration: TimeInterval = 0.5
        static let minCrossfadeDuration: TimeInterval = 0.3
        static let maxCrossfadeDuration: TimeInterval = 1.5
        static let resumeTransition: TimeInterval = 0.3
        static let minResumeTransition: TimeInterval = 0.1
        static let maxResumeTransition: TimeInterval = 1.0
        static let blurIntensity: Double = 0.75
        static let edgeSoftness: Double = 0.30
        static let targetFramerate: Int = 30
    }
}
```

Create `Shared/IPCProtocol.swift`:

```swift
import Foundation
import CoreMedia

/// Messages sent from host app to Camera Extension via XPC
enum IPCMessage: Codable {
    case frameReady(surfaceID: IOSurfaceID, width: Int, height: Int, timestamp: Double)
    case startStreaming(width: Int, height: Int, framerate: Int)
    case stopStreaming
    case resolutionChanged(width: Int, height: Int)
}

/// Messages sent from Camera Extension to host app via XPC
enum IPCResponse: Codable {
    case streamingStarted
    case streamingStopped
    case clientConnected(bundleIdentifier: String)
    case clientDisconnected
    case error(description: String)
}
```

Create resource plists and entitlements:

`MacMeetingCam/Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MacMeetingCam</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>MacMeetingCam needs camera access to process your video feed.</string>
</dict>
</plist>
```

`MacMeetingCam/Resources/MacMeetingCam.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.system-extension.install</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <true/>
</dict>
</plist>
```

`CameraExtension/Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MacMeetingCam Camera Extension</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>NSSystemExtensionUsageDescription</key>
    <string>MacMeetingCam installs a camera extension to provide a virtual camera.</string>
</dict>
</plist>
```

`CameraExtension/Resources/CameraExtension.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.system-extension.provider</key>
    <array>
        <string>com.apple.system-extension.cmio</string>
    </array>
</dict>
</plist>
```

**Step 4: Generate the Xcode project and verify build**

```bash
cd /Users/jjb/Work/Claude/MacMeetingCam && xcodegen generate
xcodebuild -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 5: Create placeholder test files so test targets compile**

Create `Tests/UnitTests/PlaceholderTests.swift`:
```swift
import XCTest

final class PlaceholderTests: XCTestCase {
    func testProjectBuilds() {
        XCTAssertTrue(true)
    }
}
```

Create `Tests/IntegrationTests/PlaceholderTests.swift`:
```swift
import XCTest

final class IntegrationPlaceholderTests: XCTestCase {
    func testProjectBuilds() {
        XCTAssertTrue(true)
    }
}
```

Create `Tests/E2ETests/PlaceholderE2ETests.swift`:
```swift
import XCTest

final class PlaceholderE2ETests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.exists)
    }
}
```

Create `Tests/PerformanceTests/PlaceholderPerformanceTests.swift`:
```swift
import XCTest

final class PlaceholderPerformanceTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }
}
```

**Step 6: Run tests to verify all targets compile and pass**

```bash
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" 2>&1 | tail -10
```

Expected: Test Suite 'All tests' passed

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: scaffold Xcode project with all targets and SPM dependencies"
```

---

### Task 2: Test Helpers — Synthetic Frame Generator

**Files:**
- Create: `Tests/TestHelpers/SyntheticFrameGenerator.swift`
- Create: `Tests/UnitTests/TestHelpers/SyntheticFrameGeneratorTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/UnitTests/TestHelpers/SyntheticFrameGeneratorTests.swift
import XCTest
import CoreVideo
import CoreMedia
@testable import MacMeetingCam

final class SyntheticFrameGeneratorTests: XCTestCase {

    func testGeneratesSolidColorFrame() {
        let frame = SyntheticFrameGenerator.solidColor(
            width: 1920, height: 1080,
            red: 255, green: 0, blue: 0
        )
        XCTAssertNotNil(frame)
        XCTAssertEqual(CVPixelBufferGetWidth(frame!), 1920)
        XCTAssertEqual(CVPixelBufferGetHeight(frame!), 1080)
    }

    func testGeneratesFrameWithTimestamp() {
        let (buffer, time) = SyntheticFrameGenerator.timedFrame(
            width: 640, height: 480,
            red: 0, green: 255, blue: 0,
            timestampSeconds: 1.5
        )
        XCTAssertNotNil(buffer)
        XCTAssertEqual(time.seconds, 1.5, accuracy: 0.001)
    }

    func testGeneratesGradientMask() {
        let mask = SyntheticFrameGenerator.gradientMask(width: 100, height: 100)
        XCTAssertNotNil(mask)
        XCTAssertEqual(CVPixelBufferGetWidth(mask!), 100)
        XCTAssertEqual(CVPixelBufferGetPixelFormatType(mask!), kCVPixelFormatType_OneComponent8)
    }

    func testGeneratesPersonShapedMask() {
        let mask = SyntheticFrameGenerator.personMask(
            width: 1920, height: 1080,
            personRect: CGRect(x: 660, y: 140, width: 600, height: 800)
        )
        XCTAssertNotNil(mask)

        // Verify center of person region is white (foreground)
        CVPixelBufferLockBaseAddress(mask!, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(mask!)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask!)
        let centerX = 960
        let centerY = 540
        let pixel = baseAddress.advanced(by: centerY * bytesPerRow + centerX)
            .assumingMemoryBound(to: UInt8.self).pointee
        CVPixelBufferUnlockBaseAddress(mask!, .readOnly)
        XCTAssertEqual(pixel, 255, "Center of person region should be white")
    }

    func testGeneratesSequenceOfFrames() {
        let frames = SyntheticFrameGenerator.frameSequence(
            count: 10,
            width: 640, height: 480,
            fps: 30
        )
        XCTAssertEqual(frames.count, 10)

        // Verify timestamps are sequential
        for i in 1..<frames.count {
            let dt = frames[i].timestamp.seconds - frames[i-1].timestamp.seconds
            XCTAssertEqual(dt, 1.0/30.0, accuracy: 0.0001)
        }
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamTests/SyntheticFrameGeneratorTests 2>&1 | tail -5
```

Expected: FAIL — `SyntheticFrameGenerator` not found

**Step 3: Write minimal implementation**

```swift
// Tests/TestHelpers/SyntheticFrameGenerator.swift
import Foundation
import CoreVideo
import CoreMedia

struct TimedFrame {
    let buffer: CVPixelBuffer
    let timestamp: CMTime
}

enum SyntheticFrameGenerator {

    static func solidColor(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let baseAddress = CVPixelBufferGetBaseAddress(buffer)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let ptr = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                ptr[0] = blue   // B
                ptr[1] = green  // G
                ptr[2] = red    // R
                ptr[3] = 255    // A
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    static func timedFrame(
        width: Int, height: Int,
        red: UInt8, green: UInt8, blue: UInt8,
        timestampSeconds: Double
    ) -> (buffer: CVPixelBuffer?, time: CMTime) {
        let buffer = solidColor(width: width, height: height, red: red, green: green, blue: blue)
        let time = CMTime(seconds: timestampSeconds, preferredTimescale: 90000)
        return (buffer, time)
    }

    static func gradientMask(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_OneComponent8,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let baseAddress = CVPixelBufferGetBaseAddress(buffer)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        for y in 0..<height {
            let value = UInt8(Double(y) / Double(height - 1) * 255)
            for x in 0..<width {
                baseAddress.advanced(by: y * bytesPerRow + x)
                    .assumingMemoryBound(to: UInt8.self).pointee = value
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    static func personMask(width: Int, height: Int, personRect: CGRect) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_OneComponent8,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let baseAddress = CVPixelBufferGetBaseAddress(buffer)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        // Fill with black (background)
        memset(baseAddress, 0, bytesPerRow * height)

        // Fill person rect with white (foreground)
        let minX = max(0, Int(personRect.minX))
        let maxX = min(width, Int(personRect.maxX))
        let minY = max(0, Int(personRect.minY))
        let maxY = min(height, Int(personRect.maxY))

        for y in minY..<maxY {
            for x in minX..<maxX {
                baseAddress.advanced(by: y * bytesPerRow + x)
                    .assumingMemoryBound(to: UInt8.self).pointee = 255
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    static func frameSequence(count: Int, width: Int, height: Int, fps: Int) -> [TimedFrame] {
        let interval = 1.0 / Double(fps)
        return (0..<count).map { i in
            // Vary color slightly per frame so they're distinguishable
            let shade = UInt8(Double(i) / Double(max(count - 1, 1)) * 255)
            let buffer = solidColor(width: width, height: height, red: shade, green: shade, blue: shade)!
            let time = CMTime(seconds: Double(i) * interval, preferredTimescale: 90000)
            return TimedFrame(buffer: buffer, timestamp: time)
        }
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamTests/SyntheticFrameGeneratorTests 2>&1 | tail -5
```

Expected: PASS

**Step 5: Commit**

```bash
git add Tests/TestHelpers/SyntheticFrameGenerator.swift Tests/UnitTests/TestHelpers/SyntheticFrameGeneratorTests.swift
git commit -m "feat: add SyntheticFrameGenerator test helper with solid color, mask, and sequence support"
```

---

### Task 3: CI Scripts — Coverage Enforcement

**Files:**
- Create: `Scripts/check-coverage.sh`
- Create: `Scripts/ci-test.sh`
- Create: `Scripts/generate-reference-snapshots.sh`
- Create: `Scripts/setup-dev.sh`

**Step 1: Create coverage enforcement script**

```bash
#!/bin/bash
# Scripts/check-coverage.sh
# Parses xcodebuild result bundle and enforces >90% coverage threshold

set -euo pipefail

RESULT_BUNDLE="${1:-.build/results.xcresult}"
THRESHOLD="${2:-90}"
OUTPUT_FILE="Tests/coverage-report.txt"

echo "=== MacMeetingCam Coverage Report ==="
echo "Threshold: ${THRESHOLD}%"
echo ""

# Extract coverage using xcrun xccov
COVERAGE_JSON=$(xcrun xccov view --report --json "$RESULT_BUNDLE" 2>/dev/null)

if [ -z "$COVERAGE_JSON" ]; then
    echo "ERROR: Could not extract coverage from $RESULT_BUNDLE"
    exit 1
fi

# Parse overall line coverage
OVERALL=$(echo "$COVERAGE_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
targets = data.get('targets', [])
for t in targets:
    name = t.get('name', '')
    cov = t.get('lineCoverage', 0) * 100
    print(f'{name}: {cov:.1f}%')
    if name == 'MacMeetingCam.app':
        print(f'MAIN_COVERAGE={cov:.1f}')
")

echo "$OVERALL" | grep -v "MAIN_COVERAGE"
echo ""

MAIN_COV=$(echo "$OVERALL" | grep "MAIN_COVERAGE" | cut -d= -f2)

if [ -z "$MAIN_COV" ]; then
    echo "WARNING: Could not determine main target coverage"
    exit 0
fi

echo "Main target coverage: ${MAIN_COV}%"

# Write report
echo "$OVERALL" > "$OUTPUT_FILE"
echo "Report written to $OUTPUT_FILE"

# Check threshold
PASS=$(python3 -c "print('yes' if float('${MAIN_COV}') >= float('${THRESHOLD}') else 'no')")

if [ "$PASS" = "no" ]; then
    echo ""
    echo "FAIL: Coverage ${MAIN_COV}% is below threshold ${THRESHOLD}%"
    exit 1
else
    echo ""
    echo "PASS: Coverage ${MAIN_COV}% meets threshold ${THRESHOLD}%"
fi
```

**Step 2: Create CI test runner**

```bash
#!/bin/bash
# Scripts/ci-test.sh
# Full CI test runner: build, test, coverage check

set -euo pipefail

SCHEME="${1:-MacMeetingCam (No Extension)}"
RESULT_BUNDLE=".build/results.xcresult"
COVERAGE_THRESHOLD=90

echo "=== MacMeetingCam CI Test Runner ==="
echo "Scheme: $SCHEME"
echo ""

# Clean previous results
rm -rf "$RESULT_BUNDLE"

# Step 1: Build all targets
echo "--- Step 1: Building ---"
xcodebuild build-for-testing \
    -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -resultBundlePath "$RESULT_BUNDLE" \
    2>&1 | tail -3

# Step 2: Run unit tests with coverage
echo ""
echo "--- Step 2: Unit Tests ---"
xcodebuild test-without-building \
    -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -only-testing:MacMeetingCamTests \
    -resultBundlePath "$RESULT_BUNDLE" \
    -enableCodeCoverage YES \
    2>&1 | tail -5

# Step 3: Run integration tests
echo ""
echo "--- Step 3: Integration Tests ---"
xcodebuild test-without-building \
    -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -only-testing:MacMeetingCamIntegrationTests \
    -resultBundlePath "$RESULT_BUNDLE" \
    2>&1 | tail -5

# Step 4: Run E2E tests (includes visual regression)
echo ""
echo "--- Step 4: E2E Tests ---"
xcodebuild test-without-building \
    -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -only-testing:MacMeetingCamE2ETests \
    -resultBundlePath "$RESULT_BUNDLE" \
    2>&1 | tail -5

# Step 5: Run performance benchmarks
echo ""
echo "--- Step 5: Performance Tests ---"
xcodebuild test-without-building \
    -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -only-testing:MacMeetingCamPerformanceTests \
    -resultBundlePath "$RESULT_BUNDLE" \
    2>&1 | tail -5

# Step 6: Check coverage
echo ""
echo "--- Step 6: Coverage Check ---"
./Scripts/check-coverage.sh "$RESULT_BUNDLE" "$COVERAGE_THRESHOLD"

echo ""
echo "=== CI Complete ==="
```

**Step 3: Create developer setup script**

```bash
#!/bin/bash
# Scripts/setup-dev.sh
# Patches team ID and bundle identifiers for local development

set -euo pipefail

echo "=== MacMeetingCam Developer Setup ==="
echo ""

read -p "Enter your Apple Developer Team ID (e.g., ABCDE12345): " TEAM_ID

if [ -z "$TEAM_ID" ]; then
    echo "Error: Team ID is required"
    exit 1
fi

echo ""
echo "Patching project with Team ID: $TEAM_ID"

# Regenerate project with the team ID
if command -v xcodegen &> /dev/null; then
    TEAM_ID="$TEAM_ID" xcodegen generate
    echo "Project regenerated with your Team ID."
else
    echo "XcodeGen not found. Install with: brew install xcodegen"
    echo "Then re-run this script."
    exit 1
fi

echo ""
echo "Setup complete! Open MacMeetingCam.xcodeproj in Xcode."
echo ""
echo "Schemes available:"
echo "  - MacMeetingCam (Full): Builds host app + Camera Extension (requires signing)"
echo "  - MacMeetingCam (No Extension): Builds host app only (no signing needed)"
```

**Step 4: Create reference snapshot generator placeholder**

```bash
#!/bin/bash
# Scripts/generate-reference-snapshots.sh
# Renders wireframes/index.html to reference PNGs for visual regression tests

set -euo pipefail

OUTPUT_DIR="Tests/ReferenceSnapshots"
WIREFRAME="wireframes/index.html"

echo "=== Generating Reference Snapshots ==="

if [ ! -f "$WIREFRAME" ]; then
    echo "ERROR: Wireframe not found at $WIREFRAME"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Onboarding"

# Use swift script to render via WebKit
cat > /tmp/render-snapshots.swift << 'SWIFT_EOF'
import Foundation
import WebKit
import AppKit

// This script renders the wireframe HTML sections to PNG files
// Run with: swift /tmp/render-snapshots.swift <html-path> <output-dir>

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("Usage: render-snapshots <html-path> <output-dir>")
    exit(1)
}

let htmlPath = args[1]
let outputDir = args[2]
let htmlURL = URL(fileURLWithPath: htmlPath)

class SnapshotRenderer: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let outputDir: String
    let semaphore = DispatchSemaphore(value: 0)

    init(outputDir: String) {
        self.outputDir = outputDir
        let config = WKWebViewConfiguration()
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800), configuration: config)
        super.init()
        self.webView.navigationDelegate = self
    }

    func render(url: URL) {
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        semaphore.wait()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for rendering
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.captureSnapshots()
        }
    }

    func captureSnapshots() {
        let sections = [
            ("Settings_CameraTab", ".wireframe-section:nth-of-type(1) .macos-window"),
            ("Settings_BackgroundTab", ".wireframe-section:nth-of-type(2) .macos-window"),
            ("Settings_LoopTab", ".wireframe-section:nth-of-type(3) .macos-window"),
            ("Settings_HotkeysTab", ".wireframe-section:nth-of-type(4) .macos-window"),
            ("Settings_GeneralTab", ".wireframe-section:nth-of-type(5) .macos-window"),
            ("Menubar_Live", ".wireframe-section:nth-of-type(6) .popover:nth-of-type(1)"),
            ("FloatingPreview", ".wireframe-section:nth-of-type(7) .floating-preview"),
        ]

        let group = DispatchGroup()

        for (name, _) in sections {
            group.enter()
            let config = WKSnapshotConfiguration()
            webView.takeSnapshot(with: config) { image, error in
                if let image = image {
                    let tiff = image.tiffRepresentation!
                    let bitmap = NSBitmapImageRep(data: tiff)!
                    let png = bitmap.representation(using: .png, properties: [:])!
                    let path = "\(self.outputDir)/\(name).png"
                    try? png.write(to: URL(fileURLWithPath: path))
                    print("Saved: \(path)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.semaphore.signal()
        }
    }
}

let renderer = SnapshotRenderer(outputDir: outputDir)
let app = NSApplication.shared
DispatchQueue.main.async {
    renderer.render(url: htmlURL)
}
app.run()
SWIFT_EOF

echo "Rendering wireframes..."
swift /tmp/render-snapshots.swift "$(pwd)/$WIREFRAME" "$(pwd)/$OUTPUT_DIR" || {
    echo "WARNING: Automated rendering failed. Please manually capture reference snapshots."
    echo "Open wireframes/index.html in a browser and screenshot each component."
}

echo ""
echo "Reference snapshots saved to $OUTPUT_DIR/"
```

**Step 5: Make scripts executable**

```bash
chmod +x Scripts/check-coverage.sh Scripts/ci-test.sh Scripts/generate-reference-snapshots.sh Scripts/setup-dev.sh
```

**Step 6: Commit**

```bash
git add Scripts/
git commit -m "feat: add CI scripts for coverage enforcement, test running, and dev setup"
```

---

### Task 4: GitHub Actions CI Pipeline

**Files:**
- Create: `.github/workflows/ci.yml`

**Step 1: Create the workflow file**

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  test:
    name: Build & Test
    runs-on: macos-14
    timeout-minutes: 30

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Generate Xcode Project
        run: xcodegen generate

      - name: Build
        run: |
          xcodebuild build-for-testing \
            -scheme "MacMeetingCam (No Extension)" \
            -destination "platform=macOS" \
            2>&1 | tail -5

      - name: Run Unit Tests
        run: |
          xcodebuild test-without-building \
            -scheme "MacMeetingCam (No Extension)" \
            -destination "platform=macOS" \
            -only-testing:MacMeetingCamTests \
            -resultBundlePath .build/results.xcresult \
            -enableCodeCoverage YES \
            2>&1 | tail -20

      - name: Run Integration Tests
        run: |
          xcodebuild test-without-building \
            -scheme "MacMeetingCam (No Extension)" \
            -destination "platform=macOS" \
            -only-testing:MacMeetingCamIntegrationTests \
            2>&1 | tail -20

      - name: Run E2E Tests
        run: |
          xcodebuild test-without-building \
            -scheme "MacMeetingCam (No Extension)" \
            -destination "platform=macOS" \
            -only-testing:MacMeetingCamE2ETests \
            2>&1 | tail -20

      - name: Check Coverage
        run: ./Scripts/check-coverage.sh .build/results.xcresult 90

      - name: Upload Coverage Report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: Tests/coverage-report.txt

      - name: Upload Snapshot Failures
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: snapshot-failures
          path: Tests/SnapshotFailures/
```

**Step 2: Commit**

```bash
mkdir -p .github/workflows
git add .github/workflows/ci.yml
git commit -m "feat: add GitHub Actions CI pipeline with coverage enforcement"
```

---

### Task 5: E2E Test Helpers — Snapshot Testing Infrastructure

**Files:**
- Create: `Tests/E2ETests/Helpers/SnapshotTestHelper.swift`
- Create: `Tests/E2ETests/Helpers/AppLaunchHelper.swift`

**Step 1: Create the snapshot test helper**

```swift
// Tests/E2ETests/Helpers/SnapshotTestHelper.swift
import XCTest
import SnapshotTesting

enum SnapshotTestHelper {

    /// Default pixel diff tolerance (2%)
    static let defaultTolerance: Float = 0.02

    /// Fixed window sizes for deterministic snapshots
    enum WindowSize {
        static let settings = CGSize(width: 1280, height: 800)
        static let popover = CGSize(width: 280, height: 400)
        static let floatingPreview = CGSize(width: 300, height: 250)
    }

    /// Directory for reference snapshots
    static var referenceSnapshotDirectory: String {
        let testBundle = Bundle(for: _SnapshotAnchor.self)
        return testBundle.bundlePath
            .components(separatedBy: "/Build/")[0]
            .appending("/Tests/ReferenceSnapshots")
    }

    /// Compare a screenshot of an XCUIElement against a reference image
    static func assertMatchesReference(
        _ element: XCUIElement,
        named name: String,
        tolerance: Float = defaultTolerance,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let screenshot = element.screenshot()
        let image = screenshot.image

        assertSnapshot(
            of: image,
            as: .image(precision: 1.0 - tolerance, perceptualPrecision: 0.98),
            named: name,
            file: file,
            testName: "visual_regression",
            line: line
        )
    }

    /// Compare a full window screenshot against a reference image
    static func assertWindowMatchesReference(
        _ app: XCUIApplication,
        named name: String,
        tolerance: Float = defaultTolerance,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let window = app.windows.firstMatch
        assertMatchesReference(window, named: name, tolerance: tolerance, file: file, line: line)
    }
}

/// Anchor class for bundle resolution
private class _SnapshotAnchor {}
```

**Step 2: Create the app launch helper**

```swift
// Tests/E2ETests/Helpers/AppLaunchHelper.swift
import XCTest

enum AppLaunchHelper {

    /// Launch the app with default configuration for E2E tests
    static func launch(
        skipOnboarding: Bool = true,
        resetSettings: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()

        if resetSettings {
            app.launchArguments.append("--reset-settings")
        }
        if skipOnboarding {
            app.launchArguments.append("--skip-onboarding")
        }
        app.launchArguments.append("--e2e-testing")

        app.launch()
        return app
    }

    /// Launch the app and navigate to a specific settings tab
    static func launchToSettingsTab(
        _ tab: SettingsTab,
        skipOnboarding: Bool = true
    ) -> XCUIApplication {
        let app = launch(skipOnboarding: skipOnboarding)

        // Wait for settings window
        let window = app.windows["MacMeetingCam Settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Click the sidebar tab
        let sidebar = window.outlines.firstMatch
        sidebar.staticTexts[tab.rawValue].click()

        // Wait for tab content to load
        Thread.sleep(forTimeInterval: 0.5)

        return app
    }

    enum SettingsTab: String {
        case camera = "Camera"
        case background = "Background"
        case loop = "Loop"
        case hotkeys = "Hotkeys"
        case general = "General"
    }
}
```

**Step 3: Commit**

```bash
git add Tests/E2ETests/Helpers/
git commit -m "feat: add E2E test helpers for snapshot testing and app launch"
```

---

### Task 6: Test Constants and Shared Test Configuration

**Files:**
- Create: `Tests/TestHelpers/TestConstants.swift`
- Create: `Tests/TestHelpers/MockCaptureDevice.swift`

**Step 1: Create test constants**

```swift
// Tests/TestHelpers/TestConstants.swift
import Foundation
import CoreMedia

enum TestConstants {
    static let defaultWidth = 1920
    static let defaultHeight = 1080
    static let smallWidth = 640
    static let smallHeight = 480
    static let defaultFPS = 30
    static let frameDuration = CMTime(value: 1, timescale: 30)

    /// Tolerance for floating-point comparisons
    static let floatTolerance: Double = 0.001

    /// Timeout for async operations in tests
    static let asyncTimeout: TimeInterval = 5.0
}
```

**Step 2: Create mock capture device**

```swift
// Tests/TestHelpers/MockCaptureDevice.swift
import Foundation
import AVFoundation

/// A mock capture device descriptor for testing camera enumeration
/// without requiring actual hardware
struct MockCameraDescriptor: Equatable, Identifiable {
    let id: String
    let name: String
    let modelID: String
    let width: Int
    let height: Int
    let frameRates: [Int]

    static let builtInWide = MockCameraDescriptor(
        id: "built-in-wide",
        name: "FaceTime HD Camera",
        modelID: "FaceTimeHD",
        width: 1920, height: 1080,
        frameRates: [24, 30]
    )

    static let externalUSB = MockCameraDescriptor(
        id: "usb-cam-001",
        name: "USB Webcam",
        modelID: "GenericUSB",
        width: 1280, height: 720,
        frameRates: [30, 60]
    )

    static let allMocks: [MockCameraDescriptor] = [builtInWide, externalUSB]
}
```

**Step 3: Commit**

```bash
git add Tests/TestHelpers/TestConstants.swift Tests/TestHelpers/MockCaptureDevice.swift
git commit -m "feat: add TestConstants and MockCameraDescriptor test helpers"
```

---

## Phase 2: Data Layer (Tasks 7–14)

### Task 7: AppState — State Enum and Core Model

**Files:**
- Create: `MacMeetingCam/App/AppState.swift`
- Create: `Tests/UnitTests/App/AppStateTests.swift`

**Step 1: Write the failing test for state transitions**

```swift
// Tests/UnitTests/App/AppStateTests.swift
import XCTest
@testable import MacMeetingCam

final class AppStateTests: XCTestCase {

    var appState: AppState!

    override func setUp() {
        super.setUp()
        appState = AppState()
    }

    // MARK: - Initial State

    func testInitialStateIsLive() {
        XCTAssertEqual(appState.pipelineMode, .live)
    }

    func testInitialBackgroundEffectIsOff() {
        XCTAssertFalse(appState.backgroundEffectEnabled)
    }

    func testInitialBackgroundModeIsBlur() {
        XCTAssertEqual(appState.backgroundMode, .blur)
    }

    func testInitialBufferEnabled() {
        XCTAssertTrue(appState.bufferEnabled)
    }

    // MARK: - Pipeline Mode Transitions

    func testTransitionLiveToFrozen() {
        appState.toggleFreeze()
        XCTAssertEqual(appState.pipelineMode, .frozen)
    }

    func testTransitionFrozenToLive() {
        appState.toggleFreeze()
        appState.toggleFreeze()
        XCTAssertEqual(appState.pipelineMode, .live)
    }

    func testTransitionLiveToLooping() {
        appState.toggleLoop()
        XCTAssertEqual(appState.pipelineMode, .looping)
    }

    func testTransitionLoopingToLive() {
        appState.toggleLoop()
        appState.toggleLoop()
        XCTAssertEqual(appState.pipelineMode, .live)
    }

    func testTransitionFrozenToLooping() {
        appState.toggleFreeze()
        appState.toggleLoop()
        XCTAssertEqual(appState.pipelineMode, .looping)
    }

    func testTransitionLoopingToFrozen() {
        appState.toggleLoop()
        appState.toggleFreeze()
        XCTAssertEqual(appState.pipelineMode, .frozen)
    }

    // MARK: - Background Effect

    func testToggleBackgroundEffect() {
        appState.toggleBackgroundEffect()
        XCTAssertTrue(appState.backgroundEffectEnabled)
        appState.toggleBackgroundEffect()
        XCTAssertFalse(appState.backgroundEffectEnabled)
    }

    func testSetBackgroundMode() {
        appState.backgroundMode = .replace
        XCTAssertEqual(appState.backgroundMode, .replace)
        appState.backgroundMode = .remove
        XCTAssertEqual(appState.backgroundMode, .remove)
    }

    // MARK: - Combined States

    func testBackgroundEffectPersistsAcrossFreezeToggle() {
        appState.backgroundEffectEnabled = true
        appState.toggleFreeze()
        XCTAssertTrue(appState.backgroundEffectEnabled)
        XCTAssertEqual(appState.pipelineMode, .frozen)
    }

    func testBackgroundEffectPersistsAcrossLoopToggle() {
        appState.backgroundEffectEnabled = true
        appState.toggleLoop()
        XCTAssertTrue(appState.backgroundEffectEnabled)
        XCTAssertEqual(appState.pipelineMode, .looping)
    }

    // MARK: - Deferred Changes

    func testEffectChangesAreDeferredWhenFrozen() {
        appState.toggleFreeze()
        XCTAssertTrue(appState.hasDeferredChanges == false)
        appState.blurIntensity = 0.5
        XCTAssertTrue(appState.hasDeferredChanges)
    }

    func testEffectChangesAreDeferredWhenLooping() {
        appState.toggleLoop()
        appState.backgroundMode = .replace
        XCTAssertTrue(appState.hasDeferredChanges)
    }

    func testDeferredChangesApplyOnResume() {
        appState.backgroundEffectEnabled = true
        appState.blurIntensity = 0.75
        appState.toggleFreeze()

        // Change while frozen
        appState.blurIntensity = 0.5
        XCTAssertTrue(appState.hasDeferredChanges)

        // Resume — deferred changes should be applied
        appState.toggleFreeze()
        XCTAssertEqual(appState.blurIntensity, 0.5)
        XCTAssertFalse(appState.hasDeferredChanges)
    }

    func testNoFalsePositiveDeferredChangesWhenLive() {
        appState.blurIntensity = 0.5
        XCTAssertFalse(appState.hasDeferredChanges)
    }

    // MARK: - Virtual Camera

    func testVirtualCameraActiveFlag() {
        XCTAssertFalse(appState.virtualCameraActive)
        appState.virtualCameraActive = true
        XCTAssertTrue(appState.virtualCameraActive)
    }

    func testHasActiveConsumers() {
        XCTAssertFalse(appState.hasActiveConsumers)
        appState.activeConsumerBundleIDs.insert("us.zoom.xos")
        XCTAssertTrue(appState.hasActiveConsumers)
    }

    // MARK: - Slider Defaults

    func testDefaultSliderValues() {
        XCTAssertEqual(appState.blurIntensity, AppConstants.Defaults.blurIntensity)
        XCTAssertEqual(appState.edgeSoftness, AppConstants.Defaults.edgeSoftness)
        XCTAssertEqual(appState.bufferDuration, AppConstants.Defaults.bufferDuration)
        XCTAssertEqual(appState.crossfadeDuration, AppConstants.Defaults.crossfadeDuration)
        XCTAssertEqual(appState.resumeTransition, AppConstants.Defaults.resumeTransition)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamTests/AppStateTests 2>&1 | tail -5
```

Expected: FAIL — `AppState` not found

**Step 3: Write minimal implementation**

```swift
// MacMeetingCam/App/AppState.swift
import Foundation
import Combine

enum PipelineMode: Equatable {
    case live
    case frozen
    case looping
}

enum BackgroundMode: String, Equatable, CaseIterable {
    case blur
    case remove
    case replace
}

enum SegmentationQuality: String, Equatable, CaseIterable {
    case fast
    case balanced
    case accurate
}

@MainActor
final class AppState: ObservableObject {

    // MARK: - Pipeline Mode

    @Published private(set) var pipelineMode: PipelineMode = .live

    // MARK: - Background Effect

    @Published var backgroundEffectEnabled: Bool = false
    @Published var backgroundMode: BackgroundMode = .blur {
        didSet { trackDeferredChangeIfNeeded() }
    }
    @Published var blurIntensity: Double = AppConstants.Defaults.blurIntensity {
        didSet { trackDeferredChangeIfNeeded() }
    }
    @Published var edgeSoftness: Double = AppConstants.Defaults.edgeSoftness {
        didSet { trackDeferredChangeIfNeeded() }
    }

    // MARK: - Loop / Buffer

    @Published var bufferEnabled: Bool = true
    @Published var bufferDuration: TimeInterval = AppConstants.Defaults.bufferDuration
    @Published var crossfadeDuration: TimeInterval = AppConstants.Defaults.crossfadeDuration
    @Published var resumeTransition: TimeInterval = AppConstants.Defaults.resumeTransition

    // MARK: - Camera

    @Published var selectedCameraID: String?
    @Published var selectedResolution: String = "1920x1080"
    @Published var selectedFramerate: Int = AppConstants.Defaults.targetFramerate

    // MARK: - Virtual Camera

    @Published var virtualCameraActive: Bool = false
    @Published var activeConsumerBundleIDs: Set<String> = []

    var hasActiveConsumers: Bool {
        !activeConsumerBundleIDs.isEmpty
    }

    // MARK: - Segmentation

    @Published var segmentationQuality: SegmentationQuality = .balanced

    // MARK: - General

    @Published var launchAtLogin: Bool = true
    @Published var showInMenubar: Bool = true
    @Published var showInDock: Bool = false
    @Published var autoCheckUpdates: Bool = true

    // MARK: - Background Images

    @Published var backgroundImagePaths: [String] = []
    @Published var selectedBackgroundImagePath: String?

    // MARK: - Deferred Changes

    @Published private(set) var hasDeferredChanges: Bool = false
    private var changeTrackingEnabled: Bool = false

    // MARK: - State Transitions

    func toggleFreeze() {
        switch pipelineMode {
        case .live:
            changeTrackingEnabled = true
            pipelineMode = .frozen
        case .frozen:
            applyDeferredChanges()
            pipelineMode = .live
        case .looping:
            pipelineMode = .frozen
        }
    }

    func toggleLoop() {
        switch pipelineMode {
        case .live:
            changeTrackingEnabled = true
            pipelineMode = .looping
        case .looping:
            applyDeferredChanges()
            pipelineMode = .live
        case .frozen:
            pipelineMode = .looping
        }
    }

    func toggleBackgroundEffect() {
        backgroundEffectEnabled.toggle()
    }

    // MARK: - Deferred Change Tracking

    private func trackDeferredChangeIfNeeded() {
        if pipelineMode != .live && changeTrackingEnabled {
            hasDeferredChanges = true
        }
    }

    private func applyDeferredChanges() {
        hasDeferredChanges = false
        changeTrackingEnabled = false
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamTests/AppStateTests 2>&1 | tail -5
```

Expected: PASS

**Step 5: Commit**

```bash
git add MacMeetingCam/App/AppState.swift Tests/UnitTests/App/AppStateTests.swift
git commit -m "feat: implement AppState with pipeline mode transitions and deferred changes"
```

---

### Task 8: SettingsStore — UserDefaults Persistence

**Files:**
- Create: `MacMeetingCam/Persistence/SettingsStore.swift`
- Create: `Tests/UnitTests/Persistence/SettingsStoreTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/UnitTests/Persistence/SettingsStoreTests.swift
import XCTest
@testable import MacMeetingCam

final class SettingsStoreTests: XCTestCase {

    var store: SettingsStore!
    var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.tapnetix.MacMeetingCam.Tests.\(UUID().uuidString)")!
        store = SettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.description)
        super.tearDown()
    }

    // MARK: - Defaults

    func testDefaultBlurIntensity() {
        XCTAssertEqual(store.blurIntensity, AppConstants.Defaults.blurIntensity)
    }

    func testDefaultEdgeSoftness() {
        XCTAssertEqual(store.edgeSoftness, AppConstants.Defaults.edgeSoftness)
    }

    func testDefaultBufferDuration() {
        XCTAssertEqual(store.bufferDuration, AppConstants.Defaults.bufferDuration)
    }

    func testDefaultCrossfadeDuration() {
        XCTAssertEqual(store.crossfadeDuration, AppConstants.Defaults.crossfadeDuration)
    }

    func testDefaultBackgroundMode() {
        XCTAssertEqual(store.backgroundMode, .blur)
    }

    func testDefaultSegmentationQuality() {
        XCTAssertEqual(store.segmentationQuality, .balanced)
    }

    // MARK: - Persistence Round-Trip

    func testPersistsBlurIntensity() {
        store.blurIntensity = 0.42
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.blurIntensity, 0.42, accuracy: 0.001)
    }

    func testPersistsEdgeSoftness() {
        store.edgeSoftness = 0.65
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.edgeSoftness, 0.65, accuracy: 0.001)
    }

    func testPersistsBufferDuration() {
        store.bufferDuration = 60.0
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.bufferDuration, 60.0, accuracy: 0.001)
    }

    func testPersistsBackgroundMode() {
        store.backgroundMode = .replace
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.backgroundMode, .replace)
    }

    func testPersistsBackgroundEffectEnabled() {
        store.backgroundEffectEnabled = true
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertTrue(store2.backgroundEffectEnabled)
    }

    func testPersistsLaunchAtLogin() {
        store.launchAtLogin = false
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertFalse(store2.launchAtLogin)
    }

    func testPersistsSegmentationQuality() {
        store.segmentationQuality = .accurate
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.segmentationQuality, .accurate)
    }

    func testPersistsSelectedCameraID() {
        store.selectedCameraID = "usb-cam-001"
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.selectedCameraID, "usb-cam-001")
    }

    func testPersistsBufferEnabled() {
        store.bufferEnabled = false
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertFalse(store2.bufferEnabled)
    }

    // MARK: - Clamping

    func testClampsBufferDurationToMax() {
        store.bufferDuration = 999
        XCTAssertEqual(store.bufferDuration, AppConstants.Defaults.maxBufferDuration)
    }

    func testClampsBufferDurationToMin() {
        store.bufferDuration = 0.5
        XCTAssertEqual(store.bufferDuration, AppConstants.Defaults.minBufferDuration)
    }

    func testClampsBlurIntensityTo0_1() {
        store.blurIntensity = 1.5
        XCTAssertEqual(store.blurIntensity, 1.0)
        store.blurIntensity = -0.5
        XCTAssertEqual(store.blurIntensity, 0.0)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamTests/SettingsStoreTests 2>&1 | tail -5
```

Expected: FAIL — `SettingsStore` not found

**Step 3: Write minimal implementation**

```swift
// MacMeetingCam/Persistence/SettingsStore.swift
import Foundation

final class SettingsStore {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Keys

    private enum Key: String {
        case blurIntensity, edgeSoftness, bufferDuration, crossfadeDuration
        case resumeTransition, backgroundMode, backgroundEffectEnabled
        case launchAtLogin, showInMenubar, showInDock, autoCheckUpdates
        case segmentationQuality, selectedCameraID, bufferEnabled
        case selectedResolution, selectedFramerate
    }

    // MARK: - Background Effect

    var blurIntensity: Double {
        get { getDouble(.blurIntensity, default: AppConstants.Defaults.blurIntensity) }
        set { defaults.set(clamp(newValue, 0.0, 1.0), forKey: Key.blurIntensity.rawValue) }
    }

    var edgeSoftness: Double {
        get { getDouble(.edgeSoftness, default: AppConstants.Defaults.edgeSoftness) }
        set { defaults.set(clamp(newValue, 0.0, 1.0), forKey: Key.edgeSoftness.rawValue) }
    }

    var backgroundEffectEnabled: Bool {
        get { defaults.object(forKey: Key.backgroundEffectEnabled.rawValue) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.backgroundEffectEnabled.rawValue) }
    }

    var backgroundMode: BackgroundMode {
        get {
            guard let raw = defaults.string(forKey: Key.backgroundMode.rawValue),
                  let mode = BackgroundMode(rawValue: raw) else { return .blur }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: Key.backgroundMode.rawValue) }
    }

    // MARK: - Loop / Buffer

    var bufferEnabled: Bool {
        get { defaults.object(forKey: Key.bufferEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.bufferEnabled.rawValue) }
    }

    var bufferDuration: TimeInterval {
        get { getDouble(.bufferDuration, default: AppConstants.Defaults.bufferDuration) }
        set {
            let clamped = clamp(newValue,
                                AppConstants.Defaults.minBufferDuration,
                                AppConstants.Defaults.maxBufferDuration)
            defaults.set(clamped, forKey: Key.bufferDuration.rawValue)
        }
    }

    var crossfadeDuration: TimeInterval {
        get { getDouble(.crossfadeDuration, default: AppConstants.Defaults.crossfadeDuration) }
        set {
            let clamped = clamp(newValue,
                                AppConstants.Defaults.minCrossfadeDuration,
                                AppConstants.Defaults.maxCrossfadeDuration)
            defaults.set(clamped, forKey: Key.crossfadeDuration.rawValue)
        }
    }

    var resumeTransition: TimeInterval {
        get { getDouble(.resumeTransition, default: AppConstants.Defaults.resumeTransition) }
        set {
            let clamped = clamp(newValue,
                                AppConstants.Defaults.minResumeTransition,
                                AppConstants.Defaults.maxResumeTransition)
            defaults.set(clamped, forKey: Key.resumeTransition.rawValue)
        }
    }

    // MARK: - Camera

    var selectedCameraID: String? {
        get { defaults.string(forKey: Key.selectedCameraID.rawValue) }
        set { defaults.set(newValue, forKey: Key.selectedCameraID.rawValue) }
    }

    // MARK: - General

    var launchAtLogin: Bool {
        get { defaults.object(forKey: Key.launchAtLogin.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.launchAtLogin.rawValue) }
    }

    var showInMenubar: Bool {
        get { defaults.object(forKey: Key.showInMenubar.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showInMenubar.rawValue) }
    }

    var showInDock: Bool {
        get { defaults.object(forKey: Key.showInDock.rawValue) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.showInDock.rawValue) }
    }

    var autoCheckUpdates: Bool {
        get { defaults.object(forKey: Key.autoCheckUpdates.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.autoCheckUpdates.rawValue) }
    }

    var segmentationQuality: SegmentationQuality {
        get {
            guard let raw = defaults.string(forKey: Key.segmentationQuality.rawValue),
                  let quality = SegmentationQuality(rawValue: raw) else { return .balanced }
            return quality
        }
        set { defaults.set(newValue.rawValue, forKey: Key.segmentationQuality.rawValue) }
    }

    // MARK: - Helpers

    private func getDouble(_ key: Key, default defaultValue: Double) -> Double {
        defaults.object(forKey: key.rawValue) != nil
            ? defaults.double(forKey: key.rawValue)
            : defaultValue
    }

    private func clamp(_ value: Double, _ min: Double, _ max: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamTests/SettingsStoreTests 2>&1 | tail -5
```

Expected: PASS

**Step 5: Commit**

```bash
git add MacMeetingCam/Persistence/SettingsStore.swift Tests/UnitTests/Persistence/SettingsStoreTests.swift
git commit -m "feat: implement SettingsStore with UserDefaults persistence and clamping"
```

---

### Task 9: BackgroundImageStore — Security-Scoped Bookmarks

**Files:**
- Create: `MacMeetingCam/Persistence/BackgroundImageStore.swift`
- Create: `Tests/UnitTests/Persistence/BackgroundImageStoreTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/UnitTests/Persistence/BackgroundImageStoreTests.swift
import XCTest
@testable import MacMeetingCam

final class BackgroundImageStoreTests: XCTestCase {

    var store: BackgroundImageStore!
    var defaults: UserDefaults!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.tapnetix.Tests.\(UUID().uuidString)")!
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = BackgroundImageStore(defaults: defaults)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testInitiallyEmpty() {
        XCTAssertTrue(store.imagePaths.isEmpty)
    }

    func testAddImage() {
        let path = createTempImage(named: "bg1.png")
        store.addImage(at: path)
        XCTAssertEqual(store.imagePaths.count, 1)
        XCTAssertEqual(store.imagePaths.first, path)
    }

    func testAddMultipleImages() {
        let path1 = createTempImage(named: "bg1.png")
        let path2 = createTempImage(named: "bg2.png")
        store.addImage(at: path1)
        store.addImage(at: path2)
        XCTAssertEqual(store.imagePaths.count, 2)
    }

    func testAddDuplicateImageIsIgnored() {
        let path = createTempImage(named: "bg1.png")
        store.addImage(at: path)
        store.addImage(at: path)
        XCTAssertEqual(store.imagePaths.count, 1)
    }

    func testRemoveImage() {
        let path = createTempImage(named: "bg1.png")
        store.addImage(at: path)
        store.removeImage(at: path)
        XCTAssertTrue(store.imagePaths.isEmpty)
    }

    func testPersistsAcrossInstances() {
        let path = createTempImage(named: "bg1.png")
        store.addImage(at: path)

        let store2 = BackgroundImageStore(defaults: defaults)
        XCTAssertEqual(store2.imagePaths.count, 1)
        XCTAssertEqual(store2.imagePaths.first, path)
    }

    func testValidateRemovesDeletedFiles() {
        let path = createTempImage(named: "bg1.png")
        store.addImage(at: path)

        // Delete the file
        try! FileManager.default.removeItem(atPath: path)

        let removed = store.validateAndCleanup()
        XCTAssertEqual(removed.count, 1)
        XCTAssertEqual(removed.first, path)
        XCTAssertTrue(store.imagePaths.isEmpty)
    }

    func testSelectedImageFallsBackWhenDeleted() {
        let path = createTempImage(named: "bg1.png")
        store.addImage(at: path)
        store.selectedImagePath = path

        try! FileManager.default.removeItem(atPath: path)
        store.validateAndCleanup()

        XCTAssertNil(store.selectedImagePath)
    }

    func testImageExistsAtPath() {
        let path = createTempImage(named: "bg1.png")
        store.addImage(at: path)
        XCTAssertTrue(store.imageExists(at: path))

        try! FileManager.default.removeItem(atPath: path)
        XCTAssertFalse(store.imageExists(at: path))
    }

    // MARK: - Helpers

    private func createTempImage(named name: String) -> String {
        let path = tempDir.appendingPathComponent(name).path
        // Create a minimal 1x1 PNG
        let data = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
            0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
            0x44, 0xAE, 0x42, 0x60, 0x82
        ])
        FileManager.default.createFile(atPath: path, contents: data)
        return path
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamTests/BackgroundImageStoreTests 2>&1 | tail -5
```

Expected: FAIL

**Step 3: Write minimal implementation**

```swift
// MacMeetingCam/Persistence/BackgroundImageStore.swift
import Foundation

final class BackgroundImageStore {

    private let defaults: UserDefaults
    private static let imagePathsKey = "backgroundImagePaths"
    private static let selectedImageKey = "selectedBackgroundImagePath"

    @Published private(set) var imagePaths: [String] = []
    @Published var selectedImagePath: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.imagePaths = defaults.stringArray(forKey: Self.imagePathsKey) ?? []
        self.selectedImagePath = defaults.string(forKey: Self.selectedImageKey)
    }

    func addImage(at path: String) {
        guard !imagePaths.contains(path) else { return }
        guard FileManager.default.fileExists(atPath: path) else { return }

        imagePaths.append(path)
        save()
    }

    func removeImage(at path: String) {
        imagePaths.removeAll { $0 == path }
        if selectedImagePath == path {
            selectedImagePath = nil
        }
        save()
    }

    func imageExists(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// Validates all stored paths exist on disk.
    /// Returns paths that were removed because the files no longer exist.
    @discardableResult
    func validateAndCleanup() -> [String] {
        let missing = imagePaths.filter { !FileManager.default.fileExists(atPath: $0) }

        if !missing.isEmpty {
            imagePaths.removeAll { missing.contains($0) }
            if let selected = selectedImagePath, missing.contains(selected) {
                selectedImagePath = nil
            }
            save()
        }

        return missing
    }

    private func save() {
        defaults.set(imagePaths, forKey: Self.imagePathsKey)
        defaults.set(selectedImagePath, forKey: Self.selectedImageKey)
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamTests/BackgroundImageStoreTests 2>&1 | tail -5
```

Expected: PASS

**Step 5: Commit**

```bash
git add MacMeetingCam/Persistence/BackgroundImageStore.swift Tests/UnitTests/Persistence/BackgroundImageStoreTests.swift
git commit -m "feat: implement BackgroundImageStore with path validation and cleanup"
```

---

### Task 10: ThumbnailCache

**Files:**
- Create: `MacMeetingCam/Persistence/ThumbnailCache.swift`
- Create: `Tests/UnitTests/Persistence/ThumbnailCacheTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/UnitTests/Persistence/ThumbnailCacheTests.swift
import XCTest
import AppKit
@testable import MacMeetingCam

final class ThumbnailCacheTests: XCTestCase {

    var cache: ThumbnailCache!
    var cacheDir: URL!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        cacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThumbnailCacheTests-\(UUID().uuidString)")
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThumbnailSources-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        cache = ThumbnailCache(cacheDirectory: cacheDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testGeneratesThumbnailForImage() {
        let imagePath = createTestImage(named: "photo.png", size: NSSize(width: 200, height: 200))
        let thumbnail = cache.thumbnail(for: imagePath, targetSize: NSSize(width: 90, height: 60))
        XCTAssertNotNil(thumbnail)
        XCTAssertLessThanOrEqual(thumbnail!.size.width, 90)
        XCTAssertLessThanOrEqual(thumbnail!.size.height, 60)
    }

    func testCacheHitReturnsSameImage() {
        let imagePath = createTestImage(named: "photo.png", size: NSSize(width: 200, height: 200))
        let size = NSSize(width: 90, height: 60)
        let thumb1 = cache.thumbnail(for: imagePath, targetSize: size)
        let thumb2 = cache.thumbnail(for: imagePath, targetSize: size)
        XCTAssertNotNil(thumb1)
        XCTAssertNotNil(thumb2)
        // Both should come from cache — verify cached file exists
        XCTAssertTrue(cache.hasCachedThumbnail(for: imagePath))
    }

    func testReturnsNilForNonexistentFile() {
        let thumbnail = cache.thumbnail(for: "/nonexistent/path.png", targetSize: NSSize(width: 90, height: 60))
        XCTAssertNil(thumbnail)
    }

    func testClearRemovesAllCachedThumbnails() {
        let path = createTestImage(named: "photo.png", size: NSSize(width: 200, height: 200))
        _ = cache.thumbnail(for: path, targetSize: NSSize(width: 90, height: 60))
        XCTAssertTrue(cache.hasCachedThumbnail(for: path))

        cache.clearAll()
        XCTAssertFalse(cache.hasCachedThumbnail(for: path))
    }

    func testCleanupRemovesOrphanedThumbnails() {
        let path = createTestImage(named: "photo.png", size: NSSize(width: 200, height: 200))
        _ = cache.thumbnail(for: path, targetSize: NSSize(width: 90, height: 60))

        // Delete source image
        try! FileManager.default.removeItem(atPath: path)

        let removed = cache.cleanupOrphaned(validPaths: [])
        XCTAssertEqual(removed, 1)
    }

    // MARK: - Helpers

    private func createTestImage(named name: String, size: NSSize) -> String {
        let path = tempDir.appendingPathComponent(name).path
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        let tiff = image.tiffRepresentation!
        let bitmap = NSBitmapImageRep(data: tiff)!
        let png = bitmap.representation(using: .png, properties: [:])!
        try! png.write(to: URL(fileURLWithPath: path))
        return path
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamTests/ThumbnailCacheTests 2>&1 | tail -5
```

Expected: FAIL

**Step 3: Write minimal implementation**

```swift
// MacMeetingCam/Persistence/ThumbnailCache.swift
import Foundation
import AppKit
import CryptoKit

final class ThumbnailCache {

    private let cacheDirectory: URL

    init(cacheDirectory: URL? = nil) {
        if let dir = cacheDirectory {
            self.cacheDirectory = dir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.cacheDirectory = appSupport.appendingPathComponent("MacMeetingCam/Thumbnails")
        }
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    func thumbnail(for imagePath: String, targetSize: NSSize) -> NSImage? {
        // Check cache first
        let cacheKey = cacheFileName(for: imagePath)
        let cachePath = cacheDirectory.appendingPathComponent(cacheKey)

        if FileManager.default.fileExists(atPath: cachePath.path),
           let cached = NSImage(contentsOf: cachePath) {
            return cached
        }

        // Generate thumbnail from source
        guard FileManager.default.fileExists(atPath: imagePath),
              let source = NSImage(contentsOfFile: imagePath) else {
            return nil
        }

        let thumbnail = resizeImage(source, to: targetSize)

        // Cache to disk
        if let tiff = thumbnail.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            try? png.write(to: cachePath)
        }

        return thumbnail
    }

    func hasCachedThumbnail(for imagePath: String) -> Bool {
        let cacheKey = cacheFileName(for: imagePath)
        let cachePath = cacheDirectory.appendingPathComponent(cacheKey)
        return FileManager.default.fileExists(atPath: cachePath.path)
    }

    func clearAll() {
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory,
                                                                    includingPropertiesForKeys: nil)) ?? []
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Removes cached thumbnails whose source images are not in `validPaths`.
    /// Returns the number of removed cache files.
    @discardableResult
    func cleanupOrphaned(validPaths: [String]) -> Int {
        let validKeys = Set(validPaths.map { cacheFileName(for: $0) })
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory,
                                                                    includingPropertiesForKeys: nil)) ?? []
        var removed = 0
        for file in files {
            if !validKeys.contains(file.lastPathComponent) {
                try? FileManager.default.removeItem(at: file)
                removed += 1
            }
        }
        return removed
    }

    // MARK: - Private

    private func cacheFileName(for path: String) -> String {
        let hash = SHA256.hash(data: Data(path.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined() + ".png"
    }

    private func resizeImage(_ image: NSImage, to targetSize: NSSize) -> NSImage {
        let sourceSize = image.size
        let widthRatio = targetSize.width / sourceSize.width
        let heightRatio = targetSize.height / sourceSize.height
        let scale = min(widthRatio, heightRatio)

        let newSize = NSSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )

        let result = NSImage(size: newSize)
        result.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: sourceSize),
                   operation: .copy,
                   fraction: 1.0)
        result.unlockFocus()
        return result
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamTests/ThumbnailCacheTests 2>&1 | tail -5
```

Expected: PASS

**Step 5: Commit**

```bash
git add MacMeetingCam/Persistence/ThumbnailCache.swift Tests/UnitTests/Persistence/ThumbnailCacheTests.swift
git commit -m "feat: implement ThumbnailCache with disk caching and orphan cleanup"
```

---

### Tasks 11–14: Remaining Data Layer

> **Tasks 11–14 follow the same red-green pattern. Listing concisely:**

### Task 11: SettingsStore ↔ AppState Integration

**Files:**
- Modify: `MacMeetingCam/App/AppState.swift`
- Create: `Tests/UnitTests/App/AppStateSettingsIntegrationTests.swift`

**Test:** AppState loads initial values from SettingsStore on init, and writes changes back.

```swift
func testLoadsBlurIntensityFromStore() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let store = SettingsStore(defaults: defaults)
    store.blurIntensity = 0.42
    let state = AppState(settingsStore: store)
    XCTAssertEqual(state.blurIntensity, 0.42, accuracy: 0.001)
}

func testPersistsBlurIntensityChanges() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let store = SettingsStore(defaults: defaults)
    let state = AppState(settingsStore: store)
    state.blurIntensity = 0.55
    XCTAssertEqual(store.blurIntensity, 0.55, accuracy: 0.001)
}
```

**Implementation:** Add `SettingsStore` dependency to `AppState.init`, sync published properties with Combine `sink`.

**Commit:** `git commit -m "feat: wire AppState to SettingsStore for persistence"`

---

### Task 12: Memory Estimation Utility

**Files:**
- Create: `MacMeetingCam/Loop/MemoryEstimator.swift`
- Create: `Tests/UnitTests/Loop/MemoryEstimatorTests.swift`

**Test:**

```swift
func testEstimateMemoryFor30sAt1080p30fps() {
    let estimate = MemoryEstimator.estimateBytes(
        durationSeconds: 30, width: 1920, height: 1080, fps: 30
    )
    // 30s * 30fps = 900 frames, each 1920*1080*4 bytes ≈ 7.46 GB raw
    // With compressed buffers, expect ~1.2 GB estimate
    XCTAssertGreaterThan(estimate, 0)
    XCTAssertEqual(estimate, 900 * 1920 * 1080 * 4) // raw estimate
}

func testFormattedString() {
    let formatted = MemoryEstimator.formattedEstimate(
        durationSeconds: 30, width: 1920, height: 1080, fps: 30
    )
    XCTAssertTrue(formatted.contains("GB"))
}
```

**Implementation:** Simple calculation: `frames * width * height * bytesPerPixel`.

**Commit:** `git commit -m "feat: add MemoryEstimator for loop buffer size display"`

---

### Task 13: Constants — Add Memory Estimation Constants

**Files:**
- Modify: `Shared/Constants.swift`

Add bytes-per-pixel constant (4 for BGRA), formatted output helper.

**Commit:** `git commit -m "feat: add pixel format constants to AppConstants"`

---

### Task 14: IPCProtocol — Complete Message Types

**Files:**
- Modify: `Shared/IPCProtocol.swift`
- Create: `Tests/UnitTests/Shared/IPCProtocolTests.swift`

**Test:**

```swift
func testIPCMessageEncodeDecode() {
    let message = IPCMessage.frameReady(surfaceID: 42, width: 1920, height: 1080, timestamp: 1.5)
    let data = try! JSONEncoder().encode(message)
    let decoded = try! JSONDecoder().decode(IPCMessage.self, from: data)
    XCTAssertEqual(message, decoded)
}

func testIPCResponseEncodeDecode() {
    let response = IPCResponse.clientConnected(bundleIdentifier: "us.zoom.xos")
    let data = try! JSONEncoder().encode(response)
    let decoded = try! JSONDecoder().decode(IPCResponse.self, from: data)
    XCTAssertEqual(response, decoded)
}
```

**Implementation:** Make `IPCMessage` and `IPCResponse` `Equatable`, verify all cases round-trip.

**Commit:** `git commit -m "feat: verify IPCProtocol serialization round-trip"`

---

## Phase 3: Video Pipeline (Tasks 15–28)

### Task 15: PersonSegmentor Protocol + MockSegmentor

**Files:**
- Create: `MacMeetingCam/Segmentation/PersonSegmentor.swift`
- Create: `Tests/TestHelpers/MockSegmentor.swift` (move from UnitTests)
- Create: `Tests/UnitTests/Segmentation/PersonSegmentorTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/UnitTests/Segmentation/PersonSegmentorTests.swift
import XCTest
import CoreVideo
@testable import MacMeetingCam

final class PersonSegmentorTests: XCTestCase {

    func testMockSegmentorReturnsMaskWithCorrectDimensions() async throws {
        let segmentor = MockSegmentor()
        let frame = SyntheticFrameGenerator.solidColor(width: 1920, height: 1080, red: 128, green: 128, blue: 128)!

        let mask = try await segmentor.segment(pixelBuffer: frame)

        XCTAssertEqual(CVPixelBufferGetWidth(mask), 1920)
        XCTAssertEqual(CVPixelBufferGetHeight(mask), 1080)
    }

    func testMockSegmentorReturnsSingleChannelMask() async throws {
        let segmentor = MockSegmentor()
        let frame = SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 0, green: 0, blue: 0)!

        let mask = try await segmentor.segment(pixelBuffer: frame)

        XCTAssertEqual(CVPixelBufferGetPixelFormatType(mask), kCVPixelFormatType_OneComponent8)
    }

    func testMockSegmentorWithCustomMask() async throws {
        let customMask = SyntheticFrameGenerator.personMask(
            width: 640, height: 480,
            personRect: CGRect(x: 200, y: 100, width: 240, height: 300)
        )!
        let segmentor = MockSegmentor(fixedMask: customMask)
        let frame = SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 0, green: 0, blue: 0)!

        let mask = try await segmentor.segment(pixelBuffer: frame)

        // Verify it returned our custom mask
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        let centerPixel = CVPixelBufferGetBaseAddress(mask)!
            .advanced(by: 250 * CVPixelBufferGetBytesPerRow(mask) + 320)
            .assumingMemoryBound(to: UInt8.self).pointee
        CVPixelBufferUnlockBaseAddress(mask, .readOnly)
        XCTAssertEqual(centerPixel, 255) // Inside person rect
    }

    func testSegmentorQualityOptions() {
        let balanced = MockSegmentor(quality: .balanced)
        let accurate = MockSegmentor(quality: .accurate)
        XCTAssertEqual(balanced.quality, .balanced)
        XCTAssertEqual(accurate.quality, .accurate)
    }
}
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Write minimal implementation**

```swift
// MacMeetingCam/Segmentation/PersonSegmentor.swift
import Foundation
import CoreVideo

protocol PersonSegmentor {
    var quality: SegmentationQuality { get set }
    func segment(pixelBuffer: CVPixelBuffer) async throws -> CVPixelBuffer
}

enum SegmentationError: Error {
    case invalidInput
    case processingFailed(underlying: Error)
    case unsupportedPixelFormat
}
```

```swift
// Tests/TestHelpers/MockSegmentor.swift
import Foundation
import CoreVideo
@testable import MacMeetingCam

final class MockSegmentor: PersonSegmentor {

    var quality: SegmentationQuality
    private let fixedMask: CVPixelBuffer?

    /// Track how many times segment was called (for testing)
    private(set) var segmentCallCount = 0

    init(quality: SegmentationQuality = .balanced, fixedMask: CVPixelBuffer? = nil) {
        self.quality = quality
        self.fixedMask = fixedMask
    }

    func segment(pixelBuffer: CVPixelBuffer) async throws -> CVPixelBuffer {
        segmentCallCount += 1

        if let mask = fixedMask {
            return mask
        }

        // Generate a centered person-shaped mask matching input dimensions
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let personRect = CGRect(
            x: Double(width) * 0.3,
            y: Double(height) * 0.1,
            width: Double(width) * 0.4,
            height: Double(height) * 0.8
        )

        guard let mask = SyntheticFrameGenerator.personMask(
            width: width, height: height, personRect: personRect
        ) else {
            throw SegmentationError.processingFailed(underlying: NSError(domain: "mock", code: -1))
        }

        return mask
    }
}
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git commit -m "feat: define PersonSegmentor protocol and MockSegmentor test double"
```

---

### Task 16: VisionSegmentor — Apple Vision Framework

**Files:**
- Create: `MacMeetingCam/Segmentation/VisionSegmentor.swift`
- Create: `Tests/UnitTests/Segmentation/VisionSegmentorTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/UnitTests/Segmentation/VisionSegmentorTests.swift
import XCTest
import CoreVideo
import Vision
@testable import MacMeetingCam

final class VisionSegmentorTests: XCTestCase {

    func testSegmentsFrameAndReturnsMask() async throws {
        let segmentor = VisionSegmentor()
        let frame = SyntheticFrameGenerator.solidColor(
            width: 640, height: 480, red: 128, green: 128, blue: 128
        )!

        let mask = try await segmentor.segment(pixelBuffer: frame)

        XCTAssertEqual(CVPixelBufferGetWidth(mask), 640)
        XCTAssertEqual(CVPixelBufferGetHeight(mask), 480)
    }

    func testBalancedQualityUsesCorrectRevision() {
        let segmentor = VisionSegmentor(quality: .balanced)
        XCTAssertEqual(segmentor.quality, .balanced)
    }

    func testAccurateQualityUsesCorrectRevision() {
        let segmentor = VisionSegmentor(quality: .accurate)
        XCTAssertEqual(segmentor.quality, .accurate)
    }

    func testQualityCanBeChanged() {
        var segmentor = VisionSegmentor(quality: .balanced)
        segmentor.quality = .accurate
        XCTAssertEqual(segmentor.quality, .accurate)
    }
}
```

**Step 3: Write minimal implementation**

```swift
// MacMeetingCam/Segmentation/VisionSegmentor.swift
import Foundation
import CoreVideo
import Vision

final class VisionSegmentor: PersonSegmentor {

    var quality: SegmentationQuality

    init(quality: SegmentationQuality = .balanced) {
        self.quality = quality
    }

    func segment(pixelBuffer: CVPixelBuffer) async throws -> CVPixelBuffer {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = visionQualityLevel

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInteractive).async {
                do {
                    try handler.perform([request])
                    guard let result = request.results?.first,
                          let mask = result.pixelBuffer else {
                        continuation.resume(throwing: SegmentationError.processingFailed(
                            underlying: NSError(domain: "VisionSegmentor", code: -1,
                                                userInfo: [NSLocalizedDescriptionKey: "No segmentation result"])
                        ))
                        return
                    }

                    // Resize mask to match input dimensions if needed
                    let inputWidth = CVPixelBufferGetWidth(pixelBuffer)
                    let inputHeight = CVPixelBufferGetHeight(pixelBuffer)
                    let maskWidth = CVPixelBufferGetWidth(mask)
                    let maskHeight = CVPixelBufferGetHeight(mask)

                    if maskWidth == inputWidth && maskHeight == inputHeight {
                        continuation.resume(returning: mask)
                    } else {
                        // Vision may return a smaller mask — scale it
                        let resized = Self.resizeMask(mask, toWidth: inputWidth, height: inputHeight)
                        continuation.resume(returning: resized ?? mask)
                    }
                } catch {
                    continuation.resume(throwing: SegmentationError.processingFailed(underlying: error))
                }
            }
        }
    }

    private var visionQualityLevel: VNGeneratePersonSegmentationRequest.QualityLevel {
        switch quality {
        case .fast: return .fast
        case .balanced: return .balanced
        case .accurate: return .accurate
        }
    }

    private static func resizeMask(_ mask: CVPixelBuffer, toWidth width: Int, height: Int) -> CVPixelBuffer? {
        var resized: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            CVPixelBufferGetPixelFormatType(mask), nil, &resized)
        guard let output = resized else { return nil }

        let ciImage = CIImage(cvPixelBuffer: mask)
        let scaleX = CGFloat(width) / CGFloat(CVPixelBufferGetWidth(mask))
        let scaleY = CGFloat(height) / CGFloat(CVPixelBufferGetHeight(mask))
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let context = CIContext()
        context.render(scaled, to: output)
        return output
    }
}
```

**Commit:** `git commit -m "feat: implement VisionSegmentor with Apple Vision person segmentation"`

---

### Task 17: Compositor — Blur Mode

**Files:**
- Create: `MacMeetingCam/Pipeline/Compositor.swift`
- Create: `Tests/UnitTests/Pipeline/CompositorTests.swift`

**Test:** Feed a solid-color frame + person mask to the compositor in blur mode. Verify that pixels inside the mask are unchanged and pixels outside the mask are blurred (different from original).

```swift
func testBlurModePreservesPersonRegion() {
    let frame = SyntheticFrameGenerator.solidColor(width: 100, height: 100, red: 255, green: 0, blue: 0)!
    let mask = SyntheticFrameGenerator.personMask(width: 100, height: 100,
        personRect: CGRect(x: 30, y: 30, width: 40, height: 40))!
    let compositor = Compositor()
    let result = compositor.apply(frame: frame, mask: mask, mode: .blur, blurIntensity: 0.5, edgeSoftness: 0.3, backgroundImage: nil)
    XCTAssertNotNil(result)
    XCTAssertEqual(CVPixelBufferGetWidth(result!), 100)
}
```

**Implementation:** Core Image filter chain: invert mask → apply `CIGaussianBlur` to background → composite with `CIBlendWithMask`.

**Commit:** `git commit -m "feat: implement Compositor with blur mode using Core Image"`

---

### Task 18: Compositor — Remove Mode

**Test:** Verify remove mode replaces background with solid color (default: green).

```swift
func testRemoveModeReplacesBackgroundWithColor() {
    // Similar setup to blur, verify background pixels are the replacement color
}
```

**Implementation:** Use `CIConstantColorGenerator` + `CIBlendWithMask`.

**Commit:** `git commit -m "feat: add remove mode to Compositor"`

---

### Task 19: Compositor — Replace Mode

**Test:** Verify replace mode composites person over a background image using aspect-fill.

```swift
func testReplaceModeCompositesOverBackgroundImage() {
    let frame = SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 255, green: 0, blue: 0)!
    let mask = SyntheticFrameGenerator.personMask(width: 640, height: 480,
        personRect: CGRect(x: 200, y: 100, width: 240, height: 300))!
    let bgImage = CIImage(cvPixelBuffer:
        SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 0, green: 0, blue: 255)!)
    let compositor = Compositor()
    let result = compositor.apply(frame: frame, mask: mask, mode: .replace,
        blurIntensity: 0, edgeSoftness: 0.3, backgroundImage: bgImage)
    XCTAssertNotNil(result)
}

func testReplaceModeScalesBackgroundToAspectFill() {
    // Use a non-matching aspect ratio background, verify no letterboxing
}
```

**Implementation:** Scale background `CIImage` to aspect-fill, then `CIBlendWithMask`.

**Commit:** `git commit -m "feat: add replace mode with aspect-fill scaling to Compositor"`

---

### Task 20: Compositor — Edge Feathering

**Test:** Verify that edge softness parameter produces a feathered mask edge.

**Implementation:** Apply `CIGaussianBlur` to the mask itself before using it for compositing. Blur radius = `edgeSoftness * maxFeatherRadius`.

**Commit:** `git commit -m "feat: add edge feathering to Compositor via mask blur"`

---

### Task 21: FrameBuffer — Ring Buffer Core

**Files:**
- Create: `MacMeetingCam/Loop/FrameBuffer.swift`
- Create: `Tests/UnitTests/Loop/FrameBufferTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/UnitTests/Loop/FrameBufferTests.swift
import XCTest
import CoreVideo
import CoreMedia
@testable import MacMeetingCam

final class FrameBufferTests: XCTestCase {

    func testInitiallyEmpty() {
        let buffer = FrameBuffer(maxDuration: 10.0)
        XCTAssertEqual(buffer.frameCount, 0)
        XCTAssertTrue(buffer.isEmpty)
    }

    func testAppendFrame() {
        let buffer = FrameBuffer(maxDuration: 10.0)
        let frame = SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 255, green: 0, blue: 0)!
        let time = CMTime(seconds: 0.0, preferredTimescale: 90000)
        buffer.append(frame: frame, timestamp: time)
        XCTAssertEqual(buffer.frameCount, 1)
    }

    func testCapacityLimitsFrameCount() {
        let buffer = FrameBuffer(maxDuration: 1.0) // 1 second
        let frames = SyntheticFrameGenerator.frameSequence(count: 60, width: 64, height: 64, fps: 30)

        for f in frames {
            buffer.append(frame: f.buffer, timestamp: f.timestamp)
        }

        // At 30fps, 1 second = 30 frames max. Buffer should have evicted old frames.
        XCTAssertLessThanOrEqual(buffer.frameCount, 31) // Allow 1 frame of slack
    }

    func testOverwriteEvictsOldestFrames() {
        let buffer = FrameBuffer(maxDuration: 0.5) // 0.5 second
        let frames = SyntheticFrameGenerator.frameSequence(count: 30, width: 64, height: 64, fps: 30)

        for f in frames {
            buffer.append(frame: f.buffer, timestamp: f.timestamp)
        }

        // Oldest timestamp should be recent, not 0.0
        let oldest = buffer.oldestTimestamp
        XCTAssertNotNil(oldest)
        XCTAssertGreaterThan(oldest!.seconds, 0.3)
    }

    func testRetrieveFramesInOrder() {
        let buffer = FrameBuffer(maxDuration: 10.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 5, width: 64, height: 64, fps: 30)
        for f in frames { buffer.append(frame: f.buffer, timestamp: f.timestamp) }

        let retrieved = buffer.allFrames()
        XCTAssertEqual(retrieved.count, 5)

        // Verify chronological order
        for i in 1..<retrieved.count {
            XCTAssertGreaterThan(retrieved[i].timestamp.seconds, retrieved[i-1].timestamp.seconds)
        }
    }

    func testFlushClearsBuffer() {
        let buffer = FrameBuffer(maxDuration: 10.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 10, width: 64, height: 64, fps: 30)
        for f in frames { buffer.append(frame: f.buffer, timestamp: f.timestamp) }

        buffer.flush()
        XCTAssertEqual(buffer.frameCount, 0)
        XCTAssertTrue(buffer.isEmpty)
    }

    func testDurationProperty() {
        let buffer = FrameBuffer(maxDuration: 10.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 30, width: 64, height: 64, fps: 30)
        for f in frames { buffer.append(frame: f.buffer, timestamp: f.timestamp) }

        let duration = buffer.currentDuration
        XCTAssertEqual(duration, 29.0/30.0, accuracy: 0.01)
    }

    func testMaxDurationCanBeUpdated() {
        let buffer = FrameBuffer(maxDuration: 10.0)
        let frames = SyntheticFrameGenerator.frameSequence(count: 60, width: 64, height: 64, fps: 30)
        for f in frames { buffer.append(frame: f.buffer, timestamp: f.timestamp) }

        buffer.maxDuration = 0.5
        // Should trim old frames
        XCTAssertLessThanOrEqual(buffer.frameCount, 16)
    }

    func testPartiallyFilledBuffer() {
        let buffer = FrameBuffer(maxDuration: 30.0) // 30 seconds capacity
        // Add only 3 frames
        let frames = SyntheticFrameGenerator.frameSequence(count: 3, width: 64, height: 64, fps: 30)
        for f in frames { buffer.append(frame: f.buffer, timestamp: f.timestamp) }

        XCTAssertEqual(buffer.frameCount, 3)
        let all = buffer.allFrames()
        XCTAssertEqual(all.count, 3)
    }

    func testSingleFrameBuffer() {
        let buffer = FrameBuffer(maxDuration: 30.0)
        let frame = SyntheticFrameGenerator.solidColor(width: 64, height: 64, red: 0, green: 0, blue: 0)!
        buffer.append(frame: frame, timestamp: CMTime(seconds: 0, preferredTimescale: 90000))

        XCTAssertEqual(buffer.frameCount, 1)
        XCTAssertEqual(buffer.currentDuration, 0.0)
    }
}
```

**Step 3: Write minimal implementation**

```swift
// MacMeetingCam/Loop/FrameBuffer.swift
import Foundation
import CoreVideo
import CoreMedia

final class FrameBuffer {

    struct Entry {
        let buffer: CVPixelBuffer
        let timestamp: CMTime
    }

    var maxDuration: TimeInterval {
        didSet { trim() }
    }

    private var entries: [Entry] = []
    private let lock = NSLock()

    init(maxDuration: TimeInterval) {
        self.maxDuration = maxDuration
    }

    var frameCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return entries.isEmpty
    }

    var oldestTimestamp: CMTime? {
        lock.lock()
        defer { lock.unlock() }
        return entries.first?.timestamp
    }

    var newestTimestamp: CMTime? {
        lock.lock()
        defer { lock.unlock() }
        return entries.last?.timestamp
    }

    var currentDuration: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        guard let first = entries.first, let last = entries.last else { return 0 }
        return last.timestamp.seconds - first.timestamp.seconds
    }

    func append(frame: CVPixelBuffer, timestamp: CMTime) {
        lock.lock()
        entries.append(Entry(buffer: frame, timestamp: timestamp))
        lock.unlock()
        trim()
    }

    func allFrames() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    func flush() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    private func trim() {
        lock.lock()
        defer { lock.unlock() }
        guard let newest = entries.last else { return }
        let cutoff = newest.timestamp.seconds - maxDuration
        entries.removeAll { $0.timestamp.seconds < cutoff }
    }
}
```

**Commit:** `git commit -m "feat: implement FrameBuffer ring buffer with timestamp-based eviction"`

---

### Task 22: LoopEngine — Playback and Crossfade

**Files:**
- Create: `MacMeetingCam/Loop/LoopEngine.swift`
- Create: `Tests/UnitTests/Loop/LoopEngineTests.swift`

**Test key behaviors:**
- `testActivateCapuresCurrentBufferContents`
- `testPlaybackReturnsFramesInSequence`
- `testCrossfadeBlendsBoundaryFrames` — verify alpha interpolation formula
- `testDeactivateReturnsCrossfadeToLive`
- `testActivationMidBuffer`
- `testDeactivationAtVariousLoopPositions`
- `testPlaybackTimingMatchesOriginalFramerate`

**Implementation:** LoopEngine takes a FrameBuffer reference, snapshots frames on activation, pre-computes crossfade region, provides `nextFrame() -> CVPixelBuffer?` for the output stage.

**Crossfade math test:**

```swift
func testCrossfadeBlendsMath() {
    // At t=0.0 of crossfade, output should be 100% frame_start
    // At t=1.0 of crossfade, output should be 100% frame_end
    // At t=0.5, output should be 50/50 blend
    let engine = LoopEngine(crossfadeDuration: 1.0, resumeTransition: 0.3)
    let blend = engine.crossfadeAlpha(t: 0.5)
    XCTAssertEqual(blend, 0.5, accuracy: 0.001)
}
```

**Commit:** `git commit -m "feat: implement LoopEngine with crossfade blending and timestamp-based playback"`

---

### Task 23: LoopEngine — Freeze Mode

**Test:**
```swift
func testFreezeReturnsLastFrame() {
    // Append frames, activate freeze, verify nextFrame always returns same frame
}

func testFreezeToLoopTransition() {
    // Freeze, then switch to loop, verify loop starts from buffer
}
```

**Commit:** `git commit -m "feat: add freeze mode to LoopEngine"`

---

### Task 24: CaptureManager — Camera Enumeration

**Files:**
- Create: `MacMeetingCam/Pipeline/CaptureManager.swift`
- Create: `Tests/UnitTests/Pipeline/CaptureManagerTests.swift`

**Test:** Use protocol-based camera discovery to test enumeration without hardware.

```swift
protocol CameraDiscovery {
    func availableCameras() -> [CameraInfo]
}

struct CameraInfo: Equatable, Identifiable {
    let id: String
    let name: String
    let formats: [CameraFormat]
}
```

**Commit:** `git commit -m "feat: implement CaptureManager with protocol-based camera discovery"`

---

### Task 25: CaptureManager — Session Lifecycle

**Test:** Start/stop capture session, verify delegate callbacks fire with frames.

**Commit:** `git commit -m "feat: add capture session start/stop to CaptureManager"`

---

### Task 26: CaptureManager — Disconnect/Reconnect Handling

**Test:** Simulate camera disconnect notification, verify CaptureManager emits disconnect event. Simulate reconnect, verify auto-recovery.

**Commit:** `git commit -m "feat: add camera disconnect/reconnect handling to CaptureManager"`

---

### Task 27: FrameProcessor — Pipeline Orchestration

**Files:**
- Create: `MacMeetingCam/Pipeline/FrameProcessor.swift`
- Create: `Tests/UnitTests/Pipeline/FrameProcessorTests.swift`

**Test:** Feed a frame through the full pipeline (segmentor → compositor → buffer) using mock segmentor. Verify output frame exists and buffer is populated.

```swift
func testProcessesFrameThroughFullPipeline() async {
    let segmentor = MockSegmentor()
    let compositor = Compositor()
    let buffer = FrameBuffer(maxDuration: 10.0)
    let processor = FrameProcessor(segmentor: segmentor, compositor: compositor, buffer: buffer)

    let frame = SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 128, green: 128, blue: 128)!
    let time = CMTime(seconds: 0.0, preferredTimescale: 90000)

    let output = try await processor.process(frame: frame, timestamp: time,
        backgroundMode: .blur, blurIntensity: 0.5, edgeSoftness: 0.3, backgroundImage: nil)

    XCTAssertNotNil(output)
    XCTAssertEqual(buffer.frameCount, 1)
    XCTAssertEqual(segmentor.segmentCallCount, 1)
}

func testSkipsSegmentationWhenNoEffectEnabled() async {
    let segmentor = MockSegmentor()
    let compositor = Compositor()
    let buffer = FrameBuffer(maxDuration: 10.0)
    let processor = FrameProcessor(segmentor: segmentor, compositor: compositor, buffer: buffer)

    let frame = SyntheticFrameGenerator.solidColor(width: 640, height: 480, red: 128, green: 128, blue: 128)!
    let time = CMTime(seconds: 0.0, preferredTimescale: 90000)

    let output = try await processor.process(frame: frame, timestamp: time,
        backgroundMode: nil, blurIntensity: 0, edgeSoftness: 0, backgroundImage: nil)

    XCTAssertNotNil(output)
    XCTAssertEqual(segmentor.segmentCallCount, 0) // Should skip segmentation
}
```

**Commit:** `git commit -m "feat: implement FrameProcessor pipeline orchestration"`

---

### Task 28: ExtensionBridge — IPC Frame Delivery

**Files:**
- Create: `MacMeetingCam/Pipeline/ExtensionBridge.swift`
- Create: `Tests/UnitTests/Pipeline/ExtensionBridgeTests.swift`

**Test:** Verify frame metadata serialization, connection state machine, and frame delivery signaling (without actual XPC — test the protocol layer).

```swift
func testFrameReadyMessageContainsCorrectMetadata() {
    let message = IPCMessage.frameReady(surfaceID: 42, width: 1920, height: 1080, timestamp: 1.5)
    if case .frameReady(let sid, let w, let h, let t) = message {
        XCTAssertEqual(sid, 42)
        XCTAssertEqual(w, 1920)
        XCTAssertEqual(h, 1080)
        XCTAssertEqual(t, 1.5)
    } else {
        XCTFail("Expected frameReady")
    }
}
```

**Commit:** `git commit -m "feat: implement ExtensionBridge IPC layer"`

---

## Phase 4: Camera Extension (Tasks 29–32)

### Task 29: CameraProvider

**Files:**
- Modify: `CameraExtension/CameraExtensionMain.swift`
- Create: `CameraExtension/CameraProvider.swift`

**Implementation:** Implement `CMIOExtensionProviderSource` that creates and registers the virtual camera device.

**Commit:** `git commit -m "feat: implement CameraProvider extension entry point"`

---

### Task 30: CameraDevice

**Files:**
- Create: `CameraExtension/CameraDevice.swift`

**Implementation:** Implement `CMIOExtensionDeviceSource` that describes the virtual camera device properties.

**Commit:** `git commit -m "feat: implement CameraDevice with device properties"`

---

### Task 31: CameraStream

**Files:**
- Create: `CameraExtension/CameraStream.swift`

**Implementation:** Implement `CMIOExtensionStreamSource` that provides the video stream. Receives frames from the host app via IPC and outputs them to consumers.

**Commit:** `git commit -m "feat: implement CameraStream for frame output to meeting apps"`

---

### Task 32: Camera Extension — Last Frame on Disconnect

**Test (integration):** Verify that when the host app IPC connection drops, the extension holds the last received frame.

**Commit:** `git commit -m "feat: add last-frame hold on host disconnect in CameraStream"`

---

## Phase 5: Hotkeys (Tasks 33–34)

### Task 33: HotkeyManager

**Files:**
- Create: `MacMeetingCam/Hotkeys/HotkeyManager.swift`
- Create: `Tests/UnitTests/Hotkeys/HotkeyManagerTests.swift`

**Test:**
```swift
func testRegisterShortcut() {
    let manager = HotkeyManager()
    manager.register(action: .toggleFreeze, shortcut: mockShortcut)
    XCTAssertNotNil(manager.shortcut(for: .toggleFreeze))
}

func testConflictDetection() {
    let manager = HotkeyManager()
    manager.register(action: .toggleFreeze, shortcut: mockShortcut)
    let conflict = manager.hasConflict(shortcut: mockShortcut, excluding: .toggleLoop)
    XCTAssertTrue(conflict)
}

func testRestoreDefaults() {
    let manager = HotkeyManager()
    manager.register(action: .toggleFreeze, shortcut: customShortcut)
    manager.restoreDefaults()
    // Verify default shortcuts are restored
}
```

**Implementation:** Wraps `KeyboardShortcuts` library. Defines 4 actions: `toggleBackgroundEffect`, `toggleFreeze`, `toggleLoop`, `toggleCamera`.

**Commit:** `git commit -m "feat: implement HotkeyManager with conflict detection and defaults"`

---

### Task 34: HotkeyManager — Persistence

**Test:** Register custom shortcut, create new HotkeyManager instance, verify shortcut persisted.

**Commit:** `git commit -m "feat: add persistence to HotkeyManager via UserDefaults"`

---

## Phase 6: UI (Tasks 35–50)

> Each UI task follows the same pattern:
> 1. Write ViewInspector test verifying the view renders with expected elements
> 2. Implement the SwiftUI view
> 3. Commit

### Task 35: SettingsView — Tab Container

**Files:**
- Create: `MacMeetingCam/Views/Settings/SettingsView.swift`
- Create: `Tests/UnitTests/Views/SettingsViewTests.swift`

**Test:** Verify all 5 sidebar tabs exist and are tappable.

**Commit:** `git commit -m "feat: implement SettingsView sidebar tab container"`

---

### Task 36: CameraTabView

**Files:**
- Create: `MacMeetingCam/Views/Settings/CameraTabView.swift`
- Create: `Tests/UnitTests/Views/CameraTabViewTests.swift`

**Test:** Verify camera dropdown, resolution picker, framerate picker, preview area, and virtual camera status indicator exist.

**Wireframe reference:** Section 1 of `wireframes/index.html`

**Commit:** `git commit -m "feat: implement CameraTabView with preview and camera selection"`

---

### Task 37: BackgroundTabView

**Files:**
- Create: `MacMeetingCam/Views/Settings/BackgroundTabView.swift`
- Create: `Tests/UnitTests/Views/BackgroundTabViewTests.swift`

**Test:** Verify on/off toggle, mode tabs (blur/remove/replace), blur intensity slider, edge softness slider, image grid with add button.

**Wireframe reference:** Section 2

**Commit:** `git commit -m "feat: implement BackgroundTabView with mode selection and image grid"`

---

### Task 38: LoopTabView

**Files:**
- Create: `MacMeetingCam/Views/Settings/LoopTabView.swift`
- Create: `Tests/UnitTests/Views/LoopTabViewTests.swift`

**Test:** Verify buffer toggle, duration slider, memory estimate display, crossfade slider, resume transition slider, timeline visualization.

**Wireframe reference:** Section 3

**Commit:** `git commit -m "feat: implement LoopTabView with buffer controls and memory estimate"`

---

### Task 39: HotkeysTabView

**Files:**
- Create: `MacMeetingCam/Views/Settings/HotkeysTabView.swift`
- Create: `Tests/UnitTests/Views/HotkeysTabViewTests.swift`

**Test:** Verify all 4 hotkey rows exist with record buttons, restore defaults button.

**Wireframe reference:** Section 4

**Commit:** `git commit -m "feat: implement HotkeysTabView with key recorder"`

---

### Task 40: GeneralTabView

**Files:**
- Create: `MacMeetingCam/Views/Settings/GeneralTabView.swift`
- Create: `Tests/UnitTests/Views/GeneralTabViewTests.swift`

**Test:** Verify checkboxes (launch at login, menubar, dock, updates), segmentation quality picker, version display.

**Wireframe reference:** Section 5

**Commit:** `git commit -m "feat: implement GeneralTabView with preferences"`

---

### Task 41: MenubarController

**Files:**
- Create: `MacMeetingCam/Views/Menubar/MenubarController.swift`

**Implementation:** NSStatusItem setup with state-dependent icon (live, effect active, frozen, looping). Left-click shows popover, right-click shows context menu.

**Commit:** `git commit -m "feat: implement MenubarController with state-dependent icon"`

---

### Task 42: PopoverView

**Files:**
- Create: `MacMeetingCam/Views/Menubar/PopoverView.swift`
- Create: `Tests/UnitTests/Views/PopoverViewTests.swift`

**Test:** Verify mini preview, status indicator, 3 quick toggle buttons (BG, Freeze, Loop), camera selector, settings/quit links.

**Wireframe reference:** Section 6

**Commit:** `git commit -m "feat: implement PopoverView with quick controls and preview"`

---

### Task 43: PopoverView — State Variants

**Test:** Verify popover displays correctly in all 3 states (live, frozen, looping) with correct status colors and labels.

**Wireframe reference:** Section 8 (Popover States)

**Commit:** `git commit -m "feat: add state-dependent appearance to PopoverView"`

---

### Task 44: Context Menu

**Implementation:** Right-click menu with camera selection, effect toggles with hotkey hints, settings, quit.

**Wireframe reference:** Section 6 (right-click menu)

**Commit:** `git commit -m "feat: implement right-click context menu for menubar"`

---

### Task 45: FloatingPreviewWindow

**Files:**
- Create: `MacMeetingCam/Views/FloatingPreview/FloatingPreviewWindow.swift`
- Create: `Tests/UnitTests/Views/FloatingPreviewWindowTests.swift`

**Test:** Verify pin button, compact controls (BG/Freeze/Loop), status indicator.

**Wireframe reference:** Section 7

**Implementation:** NSPanel subclass (for floating behavior) hosting a SwiftUI view. Always-on-top toggle, semi-transparent when not hovered, resizable, position/size persisted.

**Commit:** `git commit -m "feat: implement FloatingPreviewWindow with always-on-top pin"`

---

### Task 46: OnboardingView — Welcome Screen

**Files:**
- Create: `MacMeetingCam/Views/Onboarding/OnboardingView.swift`

**Implementation:** Step 1 of onboarding: app intro + "Get Started" button.

**Commit:** `git commit -m "feat: implement OnboardingView welcome screen"`

---

### Task 47: OnboardingView — Permission Steps

**Implementation:** Steps 2–4: camera permission, accessibility permission, camera extension approval. Each with explanation text and action button.

**Commit:** `git commit -m "feat: add permission request steps to OnboardingView"`

---

### Task 48: OnboardingView — Complete Flow

**Implementation:** Step 5: done screen. Wire up the step progression. Add `--skip-onboarding` launch argument support for tests.

**Commit:** `git commit -m "feat: complete OnboardingView flow with skip support for tests"`

---

### Task 49: Window Behavior — Close Hides, Quit Confirmation

**Modify:** `MacMeetingCam/App/MacMeetingCamApp.swift`

**Implementation:**
- Override close button to hide window instead of quit
- Implement quit confirmation dialog when `hasActiveConsumers` is true
- Support `--reset-settings` and `--e2e-testing` launch arguments

**Commit:** `git commit -m "feat: implement close-hides-window and quit confirmation when camera in use"`

---

### Task 50: Deferred Changes Label

**Modify:** `MacMeetingCam/Views/Settings/BackgroundTabView.swift`

**Implementation:** Show "Changes apply when live" label when `appState.hasDeferredChanges` is true and pipeline mode is not `.live`.

**Commit:** `git commit -m "feat: add deferred changes label to BackgroundTabView"`

---

## Phase 7: Integration Tests (Tasks 51–56)

### Task 51: Pipeline Integration Test

**Files:**
- Create: `Tests/IntegrationTests/PipelineIntegrationTests.swift`

**Test:** Feed 300 synthetic frames (10 seconds at 30fps) through the full pipeline with MockSegmentor. Verify:
- All 300 frames are processed
- No frame drops
- Output pixel format is correct
- Buffer contains frames
- Timing is consistent

```swift
func testFullPipelineProcesses10SecondsWithoutDrops() async {
    let frames = SyntheticFrameGenerator.frameSequence(count: 300, width: 640, height: 480, fps: 30)
    let segmentor = MockSegmentor()
    let compositor = Compositor()
    let buffer = FrameBuffer(maxDuration: 30.0)
    let processor = FrameProcessor(segmentor: segmentor, compositor: compositor, buffer: buffer)

    var outputCount = 0
    for frame in frames {
        let result = try await processor.process(
            frame: frame.buffer, timestamp: frame.timestamp,
            backgroundMode: .blur, blurIntensity: 0.5, edgeSoftness: 0.3, backgroundImage: nil
        )
        if result != nil { outputCount += 1 }
    }

    XCTAssertEqual(outputCount, 300)
    XCTAssertEqual(segmentor.segmentCallCount, 300)
}
```

**Commit:** `git commit -m "test: add pipeline integration test for sustained frame processing"`

---

### Task 52: IPC Integration Test

**Files:**
- Create: `Tests/IntegrationTests/IPCIntegrationTests.swift`

**Test:** Verify ExtensionBridge can serialize frames, handle connection state transitions, and recover from connection drops.

**Commit:** `git commit -m "test: add IPC integration tests for frame delivery and reconnection"`

---

### Task 53: State Persistence Integration Test

**Files:**
- Create: `Tests/IntegrationTests/StatePersistenceTests.swift`

**Test:** Set all settings to non-default values, create new AppState + SettingsStore instances, verify all values survived.

**Commit:** `git commit -m "test: add settings persistence round-trip integration test"`

---

### Task 54: Memory Stability Integration Test

**Files:**
- Create: `Tests/IntegrationTests/MemoryStabilityTests.swift`

**Test:** Run loop buffer at 120s max duration for 60 seconds, use `XCTMetric` to verify no memory growth beyond expected bounds.

**Commit:** `git commit -m "test: add memory stability integration test for max buffer duration"`

---

### Task 55: Camera Hot-Plug Integration Test

**Files:**
- Create: `Tests/IntegrationTests/CameraHotPlugTests.swift`

**Test:** Use mock camera discovery. Simulate camera appearing and disappearing. Verify CaptureManager state transitions and notifications.

**Commit:** `git commit -m "test: add camera hot-plug simulation integration test"`

---

### Task 56: Permission Flow Integration Test

**Files:**
- Create: `Tests/IntegrationTests/PermissionFlowTests.swift`

**Test:** Verify reduced-mode behavior: app functions without accessibility permission (no hotkeys), without camera permission (shows permission banner).

**Commit:** `git commit -m "test: add permission degraded-mode integration test"`

---

## Phase 8: E2E Tests + Visual Regression (Tasks 57–70)

> All E2E tests use XCUITest. Each test launches the app via `AppLaunchHelper`, interacts with UI elements, and verifies behavior.

### Task 57: Onboarding E2E Test

**Files:**
- Create: `Tests/E2ETests/OnboardingE2ETests.swift`

**Test:**
```swift
func testOnboardingFlowCompletes() {
    let app = AppLaunchHelper.launch(skipOnboarding: false, resetSettings: true)
    // Verify welcome screen appears
    XCTAssertTrue(app.staticTexts["Welcome to MacMeetingCam"].waitForExistence(timeout: 5))
    // Tap Get Started
    app.buttons["Get Started"].tap()
    // Verify camera permission step
    XCTAssertTrue(app.staticTexts["Camera Access"].waitForExistence(timeout: 5))
    // Continue through remaining steps...
}
```

**Commit:** `git commit -m "test: add onboarding E2E test"`

---

### Task 58: Camera Tab E2E Test

**Files:**
- Create: `Tests/E2ETests/CameraTabE2ETests.swift`

**Test:** Navigate to Camera tab, verify preview exists, interact with camera dropdown, verify resolution/framerate pickers respond.

**Commit:** `git commit -m "test: add Camera tab E2E test"`

---

### Task 59: Background Tab E2E Test

**Files:**
- Create: `Tests/E2ETests/BackgroundTabE2ETests.swift`

**Test:** Navigate to Background tab, toggle effect on/off, switch modes (blur/remove/replace), adjust sliders, verify state changes.

**Commit:** `git commit -m "test: add Background tab E2E test"`

---

### Task 60: Loop Tab E2E Test

**Files:**
- Create: `Tests/E2ETests/LoopTabE2ETests.swift`

**Test:** Navigate to Loop tab, toggle buffer, adjust duration slider (verify memory estimate updates), adjust crossfade sliders.

**Commit:** `git commit -m "test: add Loop tab E2E test"`

---

### Task 61: Hotkeys Tab E2E Test

**Files:**
- Create: `Tests/E2ETests/HotkeysTabE2ETests.swift`

**Test:** Navigate to Hotkeys tab, verify all 4 shortcut rows, tap Record button, verify restore defaults.

**Commit:** `git commit -m "test: add Hotkeys tab E2E test"`

---

### Task 62: General Tab E2E Test

**Files:**
- Create: `Tests/E2ETests/GeneralTabE2ETests.swift`

**Test:** Navigate to General tab, toggle checkboxes, change segmentation quality, verify all controls respond.

**Commit:** `git commit -m "test: add General tab E2E test"`

---

### Task 63: Menubar Popover E2E Test

**Files:**
- Create: `Tests/E2ETests/MenubarPopoverE2ETests.swift`

**Test:** Click menubar icon, verify popover opens with preview, status, quick buttons, camera selector, settings/quit links. Test all 3 quick toggle buttons.

**Commit:** `git commit -m "test: add Menubar popover E2E test"`

---

### Task 64: Floating Preview E2E Test

**Files:**
- Create: `Tests/E2ETests/FloatingPreviewE2ETests.swift`

**Test:** Open floating preview, verify pin toggle, verify controls mirror popover state, verify it stays on top.

**Commit:** `git commit -m "test: add Floating preview E2E test"`

---

### Task 65: Freeze/Loop E2E Test

**Files:**
- Create: `Tests/E2ETests/FreezeLoopE2ETests.swift`

**Test:**
```swift
func testFreezeViaPopoverButton() {
    // Open popover, tap Freeze, verify status changes to "Frozen", tap again, verify "Live"
}

func testLoopViaPopoverButton() {
    // Open popover, tap Loop, verify status changes to "Looping", tap again, verify "Live"
}

func testFreezeToLoopTransition() {
    // Freeze, then tap Loop, verify status changes to "Looping"
}
```

**Commit:** `git commit -m "test: add freeze/loop E2E tests via popover controls"`

---

### Task 66: Error States E2E Test

**Files:**
- Create: `Tests/E2ETests/ErrorStatesE2ETests.swift`

**Test:** Verify permission banner appears when launched without camera permission (simulated via launch arg).

**Commit:** `git commit -m "test: add error states E2E test for permission banners"`

---

### Task 67: Visual Regression — Settings Tabs

**Files:**
- Create: `Tests/E2ETests/VisualRegressionTests.swift`

**Test:**
```swift
func testCameraTabMatchesWireframe() {
    let app = AppLaunchHelper.launchToSettingsTab(.camera)
    SnapshotTestHelper.assertWindowMatchesReference(app, named: "Settings_CameraTab")
}

func testBackgroundTabMatchesWireframe() {
    let app = AppLaunchHelper.launchToSettingsTab(.background)
    SnapshotTestHelper.assertWindowMatchesReference(app, named: "Settings_BackgroundTab")
}

func testLoopTabMatchesWireframe() {
    let app = AppLaunchHelper.launchToSettingsTab(.loop)
    SnapshotTestHelper.assertWindowMatchesReference(app, named: "Settings_LoopTab")
}

func testHotkeysTabMatchesWireframe() {
    let app = AppLaunchHelper.launchToSettingsTab(.hotkeys)
    SnapshotTestHelper.assertWindowMatchesReference(app, named: "Settings_HotkeysTab")
}

func testGeneralTabMatchesWireframe() {
    let app = AppLaunchHelper.launchToSettingsTab(.general)
    SnapshotTestHelper.assertWindowMatchesReference(app, named: "Settings_GeneralTab")
}
```

**Commit:** `git commit -m "test: add visual regression tests for all 5 settings tabs"`

---

### Task 68: Visual Regression — Menubar States

**Test:**
```swift
func testMenubarPopoverLiveMatchesWireframe() {
    let app = AppLaunchHelper.launch()
    // Open popover
    SnapshotTestHelper.assertMatchesReference(popover, named: "Menubar_Live")
}

func testMenubarPopoverFrozenMatchesWireframe() {
    // Activate freeze, open popover
    SnapshotTestHelper.assertMatchesReference(popover, named: "Menubar_Frozen")
}

func testMenubarPopoverLoopingMatchesWireframe() {
    // Activate loop, open popover
    SnapshotTestHelper.assertMatchesReference(popover, named: "Menubar_Looping")
}
```

**Commit:** `git commit -m "test: add visual regression tests for menubar popover states"`

---

### Task 69: Visual Regression — Floating Preview & Context Menu

**Test:**
```swift
func testFloatingPreviewMatchesWireframe() {
    SnapshotTestHelper.assertMatchesReference(floatingWindow, named: "FloatingPreview")
}

func testContextMenuMatchesWireframe() {
    // Right-click menubar icon
    SnapshotTestHelper.assertMatchesReference(menu, named: "ContextMenu")
}
```

**Commit:** `git commit -m "test: add visual regression tests for floating preview and context menu"`

---

### Task 70: Visual Regression — Onboarding Screens

**Test:**
```swift
func testWelcomeScreenMatchesWireframe() {
    let app = AppLaunchHelper.launch(skipOnboarding: false)
    SnapshotTestHelper.assertWindowMatchesReference(app, named: "Onboarding/Welcome")
}

// Similar for CameraPermission, AccessibilityPermission, ExtensionApproval
```

**Commit:** `git commit -m "test: add visual regression tests for onboarding screens"`

---

## Phase 9: Performance Tests & Final CI (Tasks 71–75)

### Task 71: Frame Processing Benchmark

**Files:**
- Create: `Tests/PerformanceTests/FrameProcessingBenchmark.swift`

**Test:**
```swift
func testFrameProcessingLatency() {
    let segmentor = MockSegmentor()
    let compositor = Compositor()
    let processor = FrameProcessor(segmentor: segmentor, compositor: compositor, buffer: FrameBuffer(maxDuration: 10))

    measure(metrics: [XCTClockMetric()]) {
        let frame = SyntheticFrameGenerator.solidColor(width: 1920, height: 1080, red: 128, green: 128, blue: 128)!
        let time = CMTime(seconds: 0, preferredTimescale: 90000)
        _ = try? awaitSync {
            try await processor.process(frame: frame, timestamp: time,
                backgroundMode: .blur, blurIntensity: 0.5, edgeSoftness: 0.3, backgroundImage: nil)
        }
    }
    // Assert: < 20ms per frame at 1080p/30fps
}
```

**Commit:** `git commit -m "test: add frame processing latency benchmark"`

---

### Task 72: Memory Benchmark

**Files:**
- Create: `Tests/PerformanceTests/MemoryBenchmark.swift`

**Test:** Measure memory baseline without loop buffer (target: <100MB). Measure with 30s buffer at 1080p.

**Commit:** `git commit -m "test: add memory usage benchmark"`

---

### Task 73: CPU Usage Benchmark

**Files:**
- Create: `Tests/PerformanceTests/CPUUsageBenchmark.swift`

**Test:** Measure idle CPU (buffer recording, no effects, target: <5%) and active CPU (segmentation + blur, target: <15%).

**Commit:** `git commit -m "test: add CPU usage benchmark"`

---

### Task 74: Generate Initial Reference Snapshots

**Step 1:** Run the reference snapshot generator

```bash
./Scripts/generate-reference-snapshots.sh
```

**Step 2:** Verify snapshots exist in `Tests/ReferenceSnapshots/`

**Step 3:** Commit reference snapshots

```bash
git add Tests/ReferenceSnapshots/
git commit -m "feat: add initial reference snapshots from wireframes"
```

---

### Task 75: Final CI Validation

**Step 1:** Run full CI locally

```bash
./Scripts/ci-test.sh
```

**Step 2:** Verify:
- All unit tests pass
- All integration tests pass
- All E2E tests pass (including visual regression)
- All performance benchmarks pass
- Coverage is >90%

**Step 3:** Push and verify GitHub Actions passes

```bash
git push origin main
```

**Step 4:** Commit any CI fixes

```bash
git commit -m "fix: resolve CI pipeline issues"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1: Foundation | 1–6 | Xcode project, SPM, test helpers, CI scripts |
| 2: Data Layer | 7–14 | AppState, SettingsStore, BackgroundImageStore, ThumbnailCache |
| 3: Video Pipeline | 15–28 | Segmentation, Compositor, FrameBuffer, LoopEngine, CaptureManager, FrameProcessor, ExtensionBridge |
| 4: Camera Extension | 29–32 | CMIOExtension: Provider, Device, Stream |
| 5: Hotkeys | 33–34 | HotkeyManager with KeyboardShortcuts |
| 6: UI | 35–50 | Settings tabs, Menubar, Popover, FloatingPreview, Onboarding |
| 7: Integration Tests | 51–56 | Pipeline, IPC, persistence, memory, hot-plug, permissions |
| 8: E2E + Visual Regression | 57–70 | Full app interaction tests + snapshot comparison against wireframes |
| 9: Performance + CI | 71–75 | Benchmarks, reference snapshots, final CI validation |

**Total: 75 tasks, strict red-green TDD throughout, >90% coverage target.**

Every user-facing feature has at least one E2E test. Every UI surface has a visual regression snapshot test compared against the wireframes. Coverage is enforced by CI and blocks merge if below 90%.
