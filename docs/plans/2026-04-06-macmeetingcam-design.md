# MacMeetingCam — Design Document

**Date:** 2026-04-06
**Status:** Approved

## Overview

MacMeetingCam is a macOS virtual camera app (Sonoma 14.0+) that provides background effects (blur, remove, replace with images) and a pause/loop system (freeze frame, seamless rolling loop with crossfade) for video meetings. It targets general consumers familiar with XSplit VCam who find OBS too complex.

- **Distribution:** Open source, potential pro tier
- **UI Framework:** SwiftUI (with minimal AppKit bridges where needed)
- **Camera Sources:** Any camera macOS recognizes (built-in, USB, capture cards)
- **Background Sources (v1):** Static images (JPEG/PNG), with blur and solid color modes

## Architecture

Three main components:

1. **Host App** — SwiftUI application with settings window, menubar presence, and the video processing pipeline. All processing logic lives here.
2. **Camera Extension (CMIOExtension)** — Thin system extension that registers a virtual camera ("MacMeetingCam"). Receives processed frames from the host via IPC and presents them to meeting apps.
3. **Segmentation Engine** — Pluggable `PersonSegmentor` protocol. Ships with `VisionSegmentor` (Apple's `VNGeneratePersonSegmentationRequest`), designed so alternative CoreML models can be swapped in later.

**Data flow:** Real Camera → Capture → Segmentation → Effect Compositor → Loop Buffer → Camera Extension → Meeting App

## Video Processing Pipeline

Runs per-frame, targeting 30fps minimum (matching source camera framerate).

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
  - **Replace:** Composite masked foreground over user's background image
- Edge refinement: feathering via `CIGaussianBlur` on the mask itself

### Output Stage
- Composited frame written to both the rolling loop buffer and Camera Extension via IPC
- All processing targets Metal-backed `CVPixelBuffer` for GPU residency

## Pause & Loop System

### Rolling Buffer
- Ring buffer of processed frames, user-configurable duration (3–120 seconds, uncapped input with 120s max)
- At 30fps/1080p, 30 seconds ≈ 900 frames, ~1.2GB memory. Estimated usage displayed in settings.
- Starts filling when the app is active and a camera is selected
- Always recording (no manual start required)

### Freeze Mode
- Hotkey or button press → last frame held and continuously output
- Visually instant, no transition needed
- Menubar icon changes state (not visible to meeting participants)

### Loop Mode
- Activates on hotkey → current buffer contents become loop source
- Frames played back at original framerate
- **Crossfade blending:** Last ~0.5–1s crossfades into first ~0.5–1s, pre-computed at activation
- Formula: `output = frame_end * (1-t) + frame_start * t`
- Deactivation: crossfades from current loop position back to live feed over ~0.3s

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
- If host app not running, extension outputs static placeholder frame

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

## First-Run Experience

Sequential onboarding:

1. **Welcome screen** — App intro, "Get Started" button
2. **Camera Permission** — Pre-permission explanation, then system dialog
3. **Accessibility Permission** — Required for global hotkeys. Deep link to System Settings, "Check Again" polling button
4. **Camera Extension Approval** — Step-by-step visual guide for System Settings → Privacy & Security
5. **Done** — Settings window with live preview, tutorial overlay for menubar icon and hotkeys

**Degraded mode:** If permissions denied, app remains functional where possible (e.g., no global hotkeys but buttons still work). Persistent dismissable banner shows missing permissions with fix buttons.

## Error Handling

- **Camera disconnected:** Hold last good frame (freeze), warn in menubar, auto-reconnect when camera returns
- **App not running:** Extension shows placeholder frame
- **Performance throttling:** Auto-reduce segmentation quality and processing resolution if frame budget exceeded, with indicator
- **Memory pressure:** Notify user, auto-reduce buffer to 3s minimum if critical
- **Multiple consumers:** Handled natively by `CMIOExtension`, all see same feed
- **Extension failure:** "Reinstall Extension" button, diagnostics logged to `~/Library/Logs/MacMeetingCam/`

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
│   └── Resources/
│       └── Assets.xcassets
├── CameraExtension/                   # CMIOExtension target
│   ├── CameraExtensionMain.swift
│   ├── CameraProvider.swift
│   ├── CameraDevice.swift
│   └── CameraStream.swift
└── Shared/                            # Shared between both targets
    ├── IPCProtocol.swift
    └── Constants.swift
```

## Technology Stack

- **Frameworks (Apple, no external deps for v1):** AVFoundation, Vision, Core Image, CoreMediaIO, SystemExtensions, SwiftUI
- **Optional dependencies:** Sparkle (auto-updates), KeyboardShortcuts by Sindre Sorhus (global hotkeys)
- **Build targets:** `MacMeetingCam` (host app, macOS 14.0+), `CameraExtension` (system extension, embedded)
- Both targets signed with same team ID (required for Camera Extensions)

## Testing Strategy

### Unit Tests
- `PersonSegmentor` protocol conformance with mock segmentor
- `FrameBuffer` ring buffer: capacity, overwrite, crossfade generation, edge cases
- `LoopEngine`: playback timing, crossfade math, resume transition
- `HotkeyManager`: registration/deregistration, conflict detection
- `AppState`: state transitions (live ↔ frozen ↔ looping, combined states)

### Integration Tests
- Full pipeline with synthetic frames: capture → segmentation → compositing → buffer → output
- Camera Extension IPC: frame format and timing verification
- Permission flow: reduced-mode behavior when permissions denied

### Manual Testing Checklist
- Virtual camera visible in Zoom, Teams, Google Meet, FaceTime, WebEx
- Background effects render correctly at 720p and 1080p
- Freeze/loop activation with no visible glitch to participants
- Loop crossfade seamlessness (recorded test call review)
- Camera hot-plug (connect/disconnect USB mid-session)
- Memory stability during 30+ minute buffer recording
- Sleep/wake cycle behavior
- Multiple simultaneous meeting app consumers

### Performance Benchmarks
- Frame processing latency: < 20ms per frame at 1080p/30fps
- Idle CPU (buffer recording, no effects): < 5%
- Active CPU (segmentation + blur): < 15%
- Memory baseline without loop buffer: < 100MB
