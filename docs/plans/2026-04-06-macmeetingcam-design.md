# MacMeetingCam — Design Document

**Date:** 2026-04-06
**Status:** Approved

## Overview

MacMeetingCam is a macOS virtual camera app (Sonoma 14.0+) that provides background effects (blur, remove, replace with images) and a pause/loop system (freeze frame, seamless rolling loop with crossfade) for video meetings. It targets general consumers familiar with XSplit VCam who find OBS too complex.

- **Distribution:** Open source, potential pro tier
- **UI Framework:** SwiftUI (with minimal AppKit bridges where needed)
- **Camera Sources:** Any camera macOS recognizes (built-in, USB, capture cards)
- **Background Sources (v1):** Static images (JPEG/PNG), with blur and solid color modes
- **Dependency Management:** Swift Package Manager (Xcode-integrated)

## Architecture

Three main components:

1. **Host App** — SwiftUI application with settings window, menubar presence, and the video processing pipeline. All processing logic lives here.
2. **Camera Extension (CMIOExtension)** — Thin system extension that registers a virtual camera ("MacMeetingCam"). Receives processed frames from the host via IPC and presents them to meeting apps.
3. **Segmentation Engine** — Pluggable `PersonSegmentor` protocol. Ships with `VisionSegmentor` (Apple's `VNGeneratePersonSegmentationRequest`), designed so alternative CoreML models can be swapped in later.

**Data flow:** Real Camera → Capture → Segmentation → Effect Compositor → Loop Buffer → Camera Extension → Meeting App

## Video Processing Pipeline

Runs per-frame, targeting 30fps minimum (matching source camera framerate).

### Threading Model
Each pipeline stage has its own dedicated serial dispatch queue. Frames flow forward through the pipeline:
- **Capture queue** → receives `CMSampleBuffer` from `AVCaptureSession`
- **Processing queue** → runs segmentation + compositing
- **Output queue** → writes to loop buffer + sends to Camera Extension via IPC
- **Main thread** → UI updates only, via `@Published` properties on `@MainActor`

This linear serial-queue-per-stage model is the proven pattern for real-time video on Apple platforms. No shared mutable state between queues — frames are passed forward as values.

### Capture Stage
- `AVCaptureSession` with user-selected camera as input
- Outputs `CMSampleBuffer` frames to a dedicated serial dispatch queue

### Segmentation Stage
- `PersonSegmentor` protocol: takes `CVPixelBuffer`, returns single-channel grayscale mask
- Apple Vision runs on Neural Engine, keeping GPU/CPU free
- Mask quality setting: `.balanced` (default) or `.accurate`
- Mask caching for static scenes as optimization

### Compositing Stage
- Core Image (`CIFilter` chain):
  - **Blur:** `CIGaussianBlur` on background region (inverted mask), user-adjustable radius
  - **Remove:** Replace background with solid color
  - **Replace:** Composite masked foreground over user's background image, scaled via aspect-fill (crop to fit, no letterboxing)
- Edge refinement: feathering via `CIGaussianBlur` on the mask itself
- Segments all people in frame (Apple Vision default). No single-person isolation in v1

### Output Stage
- Composited frame written to both the rolling loop buffer and Camera Extension via IPC
- All processing targets Metal-backed `CVPixelBuffer` for GPU residency

## Pause & Loop System

### Rolling Buffer
- Ring buffer of `(CVPixelBuffer, CMTime)` tuples — each frame carries its presentation timestamp for framerate-independent playback
- User-configurable duration (3–120 seconds, uncapped input with 120s max)
- At 30fps/1080p, 30 seconds ≈ 900 frames, ~1.2GB memory. Estimated usage displayed in settings.
- Starts filling when the app is active and a camera is selected
- Always recording (no manual start required)
- **Resolution/camera change:** Buffer is flushed and refilled from scratch. If the user is currently frozen or looping, a confirmation dialog appears: "Changing resolution will end the current loop. Continue?"

### Freeze Mode
- Hotkey or button press → last frame held and continuously output
- Visually instant, no transition needed
- Menubar icon changes state (not visible to meeting participants)
- **Activation feedback:** Visual only — menubar icon state change + brief "Frozen" overlay on floating preview (fades after 1s). No sound, no haptic, no system notification. Nothing that could leak via screen share

### Loop Mode
- Activates on hotkey → current buffer contents become loop source
- Frames played back at original framerate
- **Crossfade blending:** Last ~0.5–1s crossfades into first ~0.5–1s, pre-computed at activation
- Formula: `output = frame_end * (1-t) + frame_start * t`
- Deactivation: crossfades from current loop position back to live feed over ~0.3s

### Effect Changes While Frozen/Looping
- Effect controls remain enabled while frozen or looping
- Changes (blur intensity, background image, mode switches) are **deferred** — they take effect when the user resumes live mode
- A subtle label in the Background tab shows "Changes apply when live" while frozen/looping
- This lets users prepare their next look while looping without complex real-time reprocessing

### Resume Behavior
- Both freeze and loop resume with brief crossfade to live video
- Prevents jarring "jump cut" that would reveal the feature is in use

## Camera Extension & IPC

### Extension
- Bundled at `MacMeetingCam.app/Contents/Library/SystemExtensions/`
- Registers virtual camera visible in any app's camera picker
- Minimal — frame relay only, not a processor
- Supports output resolutions matching source, with 1080p/720p fallbacks

### IPC
- **Primary:** `IOSurface` shared memory for frame data (fastest path)
- XPC connection for signaling ("new frame ready") and control messages (start/stop, resolution, framerate)
- If host app not running, extension outputs the last received frame (freeze) as graceful degradation. Falls back to a static placeholder only if no frame was ever received

### Lifecycle
- macOS manages extension activation/suspension
- First-time setup requires user approval in System Settings → Privacy & Security → Camera Extensions
- Extension updates handled silently via `OSSystemExtensionManager` replacement

## User Interface

### Settings Window
Tabbed layout with sidebar navigation:

- **Camera tab:** Source camera dropdown, resolution/framerate selection, live preview, virtual camera status
- **Background tab:** On/off toggle, mode selector (blur/remove/replace), blur intensity slider, edge softness slider, background image grid with add button
- **Loop tab:** Buffer on/off, duration slider with memory estimate, crossfade duration slider, resume transition slider, buffer timeline visualization
- **Hotkeys tab:** Key recorder table for 4 global shortcuts (toggle background, toggle freeze, toggle loop, camera on/off), restore defaults button
- **General tab:** Launch at login, show in menubar/dock, auto-update, default camera, segmentation quality (fast/balanced/accurate)

### Menubar
- Camera icon with state-dependent appearance (normal, effect active, frozen, looping)
- **Left-click → popover:** Mini live preview, status indicator, quick toggle buttons (BG, Freeze, Loop), camera selector, settings/quit links
- **Right-click → context menu:** Camera selection, effect toggles with hotkey hints, settings, quit

### Floating Mini Preview
- Detachable from popover, always-on-top pin toggle
- Shows processed feed, semi-transparent (50%) when not hovered
- Resizable, remembers position and size
- Compact controls: status indicator + BG/Freeze/Loop buttons

All actions available via both hotkeys and clickable UI elements.

### Window & Dock Behavior
- Closing the settings window hides it (does not quit). App continues running via menubar
- If dock icon is hidden, settings are accessible via menubar popover → "Settings" or via Cmd+, when any app window is focused
- **Quit protection:** Cmd+Q triggers a confirmation dialog if the virtual camera is actively in use by a meeting app: "MacMeetingCam is in use by Zoom. Quit anyway?" If no consumer is active, quits immediately without prompt

## First-Run Experience

Sequential onboarding:

1. **Welcome screen** — App intro, "Get Started" button
2. **Camera Permission** — Pre-permission explanation, then system dialog
3. **Accessibility Permission** — Required for global hotkeys. Deep link to System Settings, "Check Again" polling button
4. **Camera Extension Approval** — Step-by-step visual guide for System Settings → Privacy & Security
5. **Done** — Settings window with live preview, tutorial overlay for menubar icon and hotkeys

**Degraded mode:** If permissions denied, app remains functional where possible (e.g., no global hotkeys but buttons still work). Persistent dismissable banner shows missing permissions with fix buttons.

## Settings Persistence

- **User preferences** (toggles, sliders, hotkeys, selected camera, segmentation quality): stored in `UserDefaults`
- **Background images:** Referenced by file path via security-scoped bookmarks (not copied). Original files remain in-place. If the source file is deleted or moved, the image is removed from the grid and the app falls back to "remove" mode (no background)
- **Thumbnail cache:** Small preview thumbnails cached in `~/Library/Application Support/MacMeetingCam/Thumbnails/` for fast UI rendering. Regenerated on demand if missing
- **Floating preview state** (position, size, pin status): stored in `UserDefaults`, restored on launch

## Error Handling

- **Camera disconnected:** Hold last good frame (freeze), warn in menubar, auto-reconnect when camera returns
- **App not running:** Extension shows placeholder frame
- **Performance throttling:** Auto-reduce segmentation quality and processing resolution if frame budget exceeded, with indicator
- **Memory pressure:** Notify user, auto-reduce buffer to 3s minimum if critical
- **Multiple consumers:** Handled natively by `CMIOExtension`, all see same feed
- **Extension failure:** "Reinstall Extension" button, diagnostics logged to `~/Library/Logs/MacMeetingCam/`
- **Host app crash:** Extension holds the last received frame (participants see a freeze — looks like "bad internet"). App registers with `launchd` for auto-relaunch on crash. On relaunch, reconnects to the extension, resumes pipeline with last-known settings. Recovery takes 2–5 seconds
- **Background image missing:** If a referenced image file is deleted/moved, remove it from the image grid silently. If it was the active background, fall back to "remove" mode. No error dialog — the user deleted the file intentionally

## Project Structure

```
MacMeetingCam/
├── MacMeetingCam/                    # Host app target
│   ├── App/
│   │   ├── MacMeetingCamApp.swift
│   │   └── AppState.swift
│   ├── Views/
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift
│   │   │   ├── CameraTabView.swift
│   │   │   ├── BackgroundTabView.swift
│   │   │   ├── LoopTabView.swift
│   │   │   ├── HotkeysTabView.swift
│   │   │   └── GeneralTabView.swift
│   │   ├── Menubar/
│   │   │   ├── MenubarController.swift
│   │   │   └── PopoverView.swift
│   │   ├── FloatingPreview/
│   │   │   └── FloatingPreviewWindow.swift
│   │   └── Onboarding/
│   │       └── OnboardingView.swift
│   ├── Pipeline/
│   │   ├── CaptureManager.swift
│   │   ├── FrameProcessor.swift
│   │   ├── Compositor.swift
│   │   └── ExtensionBridge.swift
│   ├── Segmentation/
│   │   ├── PersonSegmentor.swift
│   │   └── VisionSegmentor.swift
│   ├── Loop/
│   │   ├── FrameBuffer.swift
│   │   └── LoopEngine.swift
│   ├── Hotkeys/
│   │   └── HotkeyManager.swift
│   ├── Persistence/
│   │   ├── SettingsStore.swift          # UserDefaults wrapper
│   │   ├── BackgroundImageStore.swift   # Security-scoped bookmark management
│   │   └── ThumbnailCache.swift         # Background image thumbnail cache
│   └── Resources/
│       └── Assets.xcassets
├── CameraExtension/                   # CMIOExtension target
│   ├── CameraExtensionMain.swift
│   ├── CameraProvider.swift
│   ├── CameraDevice.swift
│   └── CameraStream.swift
├── Shared/                            # Shared between both targets
│   ├── IPCProtocol.swift
│   └── Constants.swift
├── Tests/
│   ├── UnitTests/                     # XCTest unit test target
│   │   ├── Pipeline/
│   │   │   ├── CaptureManagerTests.swift
│   │   │   ├── CompositorTests.swift
│   │   │   ├── FrameProcessorTests.swift
│   │   │   └── ExtensionBridgeTests.swift
│   │   ├── Segmentation/
│   │   │   ├── VisionSegmentorTests.swift
│   │   │   └── MockSegmentor.swift
│   │   ├── Loop/
│   │   │   ├── FrameBufferTests.swift
│   │   │   └── LoopEngineTests.swift
│   │   ├── Hotkeys/
│   │   │   └── HotkeyManagerTests.swift
│   │   ├── App/
│   │   │   └── AppStateTests.swift
│   │   ├── Views/
│   │   │   ├── CameraTabViewTests.swift
│   │   │   ├── BackgroundTabViewTests.swift
│   │   │   ├── LoopTabViewTests.swift
│   │   │   ├── HotkeysTabViewTests.swift
│   │   │   └── GeneralTabViewTests.swift
│   │   └── TestHelpers/
│   │       ├── SyntheticFrameGenerator.swift
│   │       ├── MockCaptureDevice.swift
│   │       └── TestConstants.swift
│   ├── IntegrationTests/              # XCTest integration test target
│   │   ├── PipelineIntegrationTests.swift
│   │   ├── IPCIntegrationTests.swift
│   │   ├── PermissionFlowTests.swift
│   │   ├── CameraHotPlugTests.swift
│   │   ├── MemoryStabilityTests.swift
│   │   └── StatePersistenceTests.swift
│   ├── E2ETests/                      # XCUITest end-to-end target
│   │   ├── OnboardingE2ETests.swift
│   │   ├── CameraTabE2ETests.swift
│   │   ├── BackgroundTabE2ETests.swift
│   │   ├── LoopTabE2ETests.swift
│   │   ├── HotkeysTabE2ETests.swift
│   │   ├── GeneralTabE2ETests.swift
│   │   ├── MenubarPopoverE2ETests.swift
│   │   ├── FloatingPreviewE2ETests.swift
│   │   ├── FreezeLoopE2ETests.swift
│   │   ├── ErrorStatesE2ETests.swift
│   │   ├── VisualRegressionTests.swift
│   │   └── Helpers/
│   │       ├── SnapshotTestHelper.swift
│   │       └── AppLaunchHelper.swift
│   ├── PerformanceTests/              # XCTest performance test target
│   │   ├── FrameProcessingBenchmark.swift
│   │   ├── CPUUsageBenchmark.swift
│   │   └── MemoryBenchmark.swift
│   └── ReferenceSnapshots/            # Visual regression reference images
│       ├── Settings_CameraTab.png
│       ├── Settings_BackgroundTab.png
│       ├── Settings_LoopTab.png
│       ├── Settings_HotkeysTab.png
│       ├── Settings_GeneralTab.png
│       ├── Menubar_Live.png
│       ├── Menubar_Frozen.png
│       ├── Menubar_Looping.png
│       ├── FloatingPreview.png
│       ├── ContextMenu.png
│       └── Onboarding/
│           ├── Welcome.png
│           ├── CameraPermission.png
│           ├── AccessibilityPermission.png
│           └── ExtensionApproval.png
├── Scripts/
│   ├── check-coverage.sh              # Enforces >80% coverage threshold
│   ├── generate-reference-snapshots.sh # Renders wireframes to reference PNGs
│   ├── setup-dev.sh                   # Patches team ID/bundle ID for contributors
│   └── ci-test.sh                     # Full CI test runner
└── DeveloperSetup.md                  # Contributor guide for signing & building
```

## Code Signing & Entitlements

### Required Entitlements
- **Host app:** `com.apple.developer.system-extension.install` (to install the Camera Extension)
- **Camera Extension:** `com.apple.developer.system-extension.provider` with `com.apple.developer.system-extension.provider.category: com.apple.system-extension.cmio`
- Both targets must be signed with the same team ID

### Open Source Contributor Setup
Two Xcode schemes are provided:

1. **MacMeetingCam (Full)** — Builds both the host app and Camera Extension. Requires a valid Apple Developer account for code signing. A `Scripts/setup-dev.sh` script patches team ID and bundle identifiers in the Xcode project for the contributor's account
2. **MacMeetingCam (No Extension)** — Builds only the host app without the Camera Extension. Processed video previews in-app but no virtual camera is registered. Lets contributors work on UI, pipeline, segmentation, and loop logic without any signing setup. This covers the majority of contribution surface area

A `DeveloperSetup.md` guide walks through both paths.

## Technology Stack

- **Frameworks (Apple, no external deps for v1):** AVFoundation, Vision, Core Image, CoreMediaIO, SystemExtensions, SwiftUI
- **Optional dependencies:** Sparkle (auto-updates), KeyboardShortcuts by Sindre Sorhus (global hotkeys)
- **Build targets:** `MacMeetingCam` (host app, macOS 14.0+), `CameraExtension` (system extension, embedded)
- Both targets signed with same team ID (required for Camera Extensions)
- **Test dependencies:** ViewInspector (SwiftUI unit testing), swift-snapshot-testing (visual regression)

## Test Infrastructure

### Xcode Scheme & Targets
- **MacMeetingCamTests** — unit test target, linked against main app. Code coverage enabled in scheme settings with >80% threshold
- **MacMeetingCamIntegrationTests** — integration test target, separate scheme to allow longer timeouts
- **MacMeetingCamE2ETests** — XCUITest target for full app interaction and visual regression
- **MacMeetingCamPerformanceTests** — performance benchmark target with baseline assertions

### Coverage Enforcement
- Xcode scheme configured with "Gather coverage for: all targets" enabled
- `Scripts/check-coverage.sh` parses `xcodebuild -resultBundlePath` output, extracts line and branch coverage per target, fails if any target is below 80%
- Coverage report generated as both Xcode `.xcresult` and a human-readable summary written to `Tests/coverage-report.txt`
- CI runs `Scripts/ci-test.sh` which:
  1. Builds all targets
  2. Runs unit tests with coverage
  3. Runs integration tests
  4. Runs e2e tests (including visual regression)
  5. Runs performance benchmarks
  6. Executes `check-coverage.sh` — fails the pipeline if below threshold
  7. Archives coverage report as CI artifact

### Visual Regression Infrastructure
- `Scripts/generate-reference-snapshots.sh` renders `wireframes/index.html` headlessly (via `wkwebview` CLI tool or Safari WebDriver) at each UI section, crops to component bounds, saves as reference PNGs in `Tests/ReferenceSnapshots/`
- `SnapshotTestHelper.swift` wraps swift-snapshot-testing to:
  - Capture a screenshot of the current XCUITest window/element
  - Load the corresponding reference image from `Tests/ReferenceSnapshots/`
  - Compare with 2% pixel diff tolerance
  - On failure: save the actual screenshot and a diff image to `Tests/SnapshotFailures/` for review
- Reference snapshots are committed to git. Updates require explicit approval (PR diff shows image changes)
- Snapshots captured at a fixed window size (1280x800 for settings, native size for popover/floating) to ensure deterministic comparisons

### CI Pipeline (GitHub Actions)
- Triggered on every push and PR
- Runs on macOS runner (required for XCUITest and Camera framework access)
- Test matrix: macOS 14 (Sonoma) — expand to macOS 15 when supported
- Artifacts: coverage report, snapshot failure diffs (if any), performance benchmark results
- **Merge gates:** all tests pass, coverage >80%, no snapshot regressions

## Testing Strategy

**Coverage requirement: >80% of ALL code paths.** Every code path must be covered by at least one test tier. If a path cannot be unit tested, it must be covered by integration tests. If it cannot be integration tested, it must be covered by end-to-end tests. No exceptions.

### Unit Tests (target: >80% line + branch coverage)

**Pipeline:**
- `PersonSegmentor` protocol conformance with mock segmentor — verify mask dimensions, pixel format, error handling for invalid inputs
- `VisionSegmentor` — test with known reference images, verify mask quality thresholds, test `.balanced` vs `.accurate` modes
- `Compositor` — test each compositing mode (blur, remove, replace) with known inputs, verify output pixel values, edge feathering correctness
- `FrameBuffer` ring buffer — capacity limits, overwrite behavior, crossfade frame generation, partially-filled buffer, single-frame edge case, zero-duration edge case, memory accounting accuracy
- `LoopEngine` — playback timing accuracy, crossfade blending math (verify alpha interpolation), resume transition, activation mid-buffer, deactivation at various loop positions

**App Logic:**
- `HotkeyManager` — registration/deregistration, conflict detection, modifier key combinations, persistence of custom bindings
- `AppState` — all state transitions: live → frozen → live, live → looping → live, frozen → looping, combined states (background effect + loop), invalid transitions rejected
- `CaptureManager` — camera enumeration, selection, format negotiation, disconnect/reconnect handling
- `ExtensionBridge` — IPC message serialization, frame metadata correctness, connection lifecycle
- `SettingsStore` — persistence round-trip for all setting types, migration from older versions
- `BackgroundImageStore` — bookmark creation/resolution, handling of deleted/moved source files, graceful fallback
- `ThumbnailCache` — cache hit/miss, regeneration on demand, cleanup of orphaned thumbnails

**Views (SwiftUI previews + ViewInspector):**
- All settings tab views render without crashes for every combination of state
- Controls are bound to correct state properties
- Disabled/enabled states reflect permissions and app state

### Integration Tests

- **Full pipeline end-to-end:** Feed synthetic frames through capture → segmentation → compositing → buffer → output. Verify frame counts, timing, pixel format consistency, and no frame drops at 30fps for 10-second runs
- **Camera Extension IPC:** Verify frames arrive at the extension with correct format, resolution, and timing. Test connection drop and reconnection
- **Permission flow:** Test reduced-mode behavior when each permission is denied (camera, accessibility, extension)
- **Camera hot-plug:** Simulate device connect/disconnect, verify graceful fallback and auto-recovery
- **Memory stability:** Run loop buffer at max duration (120s) for extended period, verify no memory leaks via XCTest memory metrics
- **State persistence:** Verify all user settings survive app restart (camera selection, background images, hotkeys, slider values, buffer duration)

### End-to-End Tests (XCUITest)

**Coverage requirement:** Every user-facing feature must have at least one end-to-end test. These tests exercise the full app as a user would.

**Functional tests:**
- App launches, onboarding flow completes, virtual camera registers and appears in camera list
- Camera tab: select camera, change resolution/framerate, verify preview updates
- Background tab: toggle effect on/off, switch between blur/remove/replace modes, adjust sliders, add/select/remove background images
- Loop tab: toggle buffer, adjust duration slider (verify memory estimate updates), adjust crossfade sliders
- Hotkeys tab: record new shortcut, verify it activates from background, restore defaults
- General tab: toggle all checkboxes, change segmentation quality
- Menubar popover: opens on click, shows correct status, quick toggles work, camera dropdown works
- Freeze mode: activate via popover button, verify status changes, deactivate and verify resume
- Loop mode: activate via popover button, verify status changes, deactivate and verify resume
- Floating preview: detach from popover, verify pin toggle, verify controls mirror popover state
- Right-click context menu: all items present and functional
- Error states: verify banner appears when permissions missing, camera disconnected state shows correctly

**Visual regression tests (snapshot-based):**
- All five settings tabs captured and compared against reference snapshots derived from wireframes
- Menubar popover in all three states (live, frozen, looping) compared against reference snapshots
- Floating mini preview compared against reference snapshot
- Right-click context menu compared against reference snapshot
- Onboarding screens compared against reference snapshots
- **Tolerance:** Pixel diff threshold of 2% to account for antialiasing and system rendering differences
- **Reference images:** Generated from the wireframes (`wireframes/index.html`) and stored in `Tests/ReferenceSnapshots/`
- **CI enforcement:** Snapshot tests run on every PR. Failures block merge. Updated snapshots require explicit approval

### Performance Benchmarks
- Frame processing latency: < 20ms per frame at 1080p/30fps
- Idle CPU (buffer recording, no effects): < 5%
- Active CPU (segmentation + blur): < 15%
- Memory baseline without loop buffer: < 100MB
- Performance tests run as XCTest performance metrics with baseline assertions, failing the build if regressions exceed 10%
