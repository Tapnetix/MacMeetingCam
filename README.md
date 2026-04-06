# MacMeetingCam

A macOS virtual camera app with background effects and seamless pause/loop for video meetings.

MacMeetingCam registers as a virtual camera that any meeting app (Zoom, Teams, Google Meet, FaceTime, WebEx) can use. It processes your real camera feed in real-time, applying background effects and providing freeze/loop capabilities.

## Features

**Background Effects**
- **Blur** -- Gaussian blur on the background with adjustable intensity
- **Remove** -- Replace background with a solid color
- **Replace** -- Composite yourself over a background image (aspect-fill, no letterboxing)
- Adjustable edge softness for natural-looking segmentation
- Powered by Apple Vision framework (runs on Neural Engine)

**Pause / Loop**
- **Freeze** -- Instantly hold the last frame. Participants see you frozen (looks like "bad internet")
- **Loop** -- Replay the last N seconds in a seamless loop with crossfade blending at the boundaries
- Rolling buffer always recording (3--120 seconds, configurable)
- Crossfade transition on activate and deactivate -- no jarring cuts
- Designed to be invisible to meeting participants

**Virtual Camera**
- Registers as "MacMeetingCam" in any app's camera picker via CMIOExtension
- Works with any camera macOS recognizes (built-in, USB, capture cards)
- Multiple meeting apps can use it simultaneously

**Interface**
- Settings window with live preview for configuration
- Menubar icon with quick-access popover (toggle effects with one click)
- Floating always-on-top mini preview window
- Configurable global keyboard shortcuts for all actions
- Right-click context menu for fast access

## Requirements

- macOS 14 (Sonoma) or later
- Any Mac with Apple Silicon or Intel (Neural Engine recommended for best performance)

## Getting Started

### For Users

1. Download the latest release
2. Move `MacMeetingCam.app` to Applications
3. Launch and follow the onboarding steps (camera permission, accessibility, extension approval)
4. Select "MacMeetingCam" as your camera in Zoom, Teams, or any meeting app

### For Developers

**Prerequisites:**
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

**Build and run:**

```bash
git clone git@github.com:Tapnetix/MacMeetingCam.git
cd MacMeetingCam
xcodegen generate
open MacMeetingCam.xcodeproj
```

Two Xcode schemes are available:

- **MacMeetingCam** -- Full build including the Camera Extension. Requires an Apple Developer account for code signing. Run `Scripts/setup-dev.sh` to configure your team ID.
- **MacMeetingCam (No Extension)** -- Host app only, no signing required. The video pipeline and UI work fully, but no virtual camera is registered. Ideal for most contributions.

**Run tests:**

```bash
# Unit tests (216 tests)
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamTests

# Integration tests (12 tests)
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamIntegrationTests

# E2E tests (31 tests, includes visual regression)
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamE2ETests

# Performance benchmarks (7 tests)
xcodebuild test -scheme "MacMeetingCam (No Extension)" -destination "platform=macOS" -only-testing:MacMeetingCamPerformanceTests

# All tests
Scripts/ci-test.sh
```

## Architecture

```
Real Camera --> Capture --> Segmentation --> Compositor --> Loop Buffer --> Camera Extension --> Meeting App
```

| Component | Description |
|-----------|-------------|
| **Host App** | SwiftUI application with settings, menubar, and video processing pipeline |
| **Camera Extension** | Thin CMIOExtension that relays processed frames as a virtual camera |
| **Segmentation Engine** | Pluggable `PersonSegmentor` protocol, ships with Apple Vision implementation |
| **Compositor** | Core Image filter chain for blur, remove, and replace modes |
| **Loop Engine** | Ring buffer with timestamp-based playback and crossfade blending |

**Threading:** Dedicated serial dispatch queue per pipeline stage (capture, processing, output). UI updates on `@MainActor`. No shared mutable state between queues.

**IPC:** Host app communicates with Camera Extension via `IOSurface` shared memory for frames and XPC for signaling.

## Project Structure

```
MacMeetingCam/
  App/              -- @main entry, AppState
  Views/            -- Settings tabs, Menubar, Popover, FloatingPreview, Onboarding
  Pipeline/         -- CaptureManager, FrameProcessor, Compositor, ExtensionBridge
  Segmentation/     -- PersonSegmentor protocol, VisionSegmentor
  Loop/             -- FrameBuffer, LoopEngine, MemoryEstimator
  Hotkeys/          -- HotkeyManager (KeyboardShortcuts)
  Persistence/      -- SettingsStore, BackgroundImageStore, ThumbnailCache
CameraExtension/    -- CMIOExtension (Provider, Device, Stream)
Shared/             -- Constants, IPCProtocol (shared between both targets)
Tests/
  UnitTests/        -- 216 tests
  IntegrationTests/ -- 12 tests
  E2ETests/         -- 31 tests (functional + visual regression)
  PerformanceTests/ -- 7 benchmarks
```

## Tech Stack

- **Swift / SwiftUI** with minimal AppKit bridges
- **AVFoundation** -- camera capture
- **Vision** -- person segmentation (Neural Engine)
- **Core Image** -- compositing and effects
- **CoreMediaIO** -- virtual camera extension
- **KeyboardShortcuts** -- global hotkeys
- **Sparkle** -- auto-updates

## License

GPL-3.0. See [LICENSE](LICENSE) for details.
