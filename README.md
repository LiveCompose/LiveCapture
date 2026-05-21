# 构妙 LiveCapture

English | [简体中文](README_CN.md)

构妙 LiveCapture is an on-device AI composition assistant app powered by reinforcement learning. We analyze the live preview in real time, combine gyroscope tracking with aesthetic scoring, and actively guide users to move the phone for the best framing so every shutter captures the best moment.

[![Hugging Face](https://img.shields.io/badge/%F0%9F%A4%97%20Hugging%20Face-LiveCompose-yellow)](https://huggingface.co/LiveCompose)
[![GitHub](https://img.shields.io/badge/GitHub-LiveCompose-black?logo=github)](https://github.com/LiveCompose)
[![App Store](https://img.shields.io/badge/App_Store-%E6%9E%84%E5%A6%99_LiveCapture-blue)](https://apps.apple.com/cn/app/%E6%9E%84%E5%A6%99/id6754213088)
![Code Size](https://img.shields.io/badge/Code_Size-16k%2B_Lines-green)
![Model](https://img.shields.io/badge/Framework-CoreML-red)
![Platform](https://img.shields.io/badge/Platform-iOS-blueviolet)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

> Now available on the App Store: [构妙 LiveCapture](https://apps.apple.com/cn/app/%E6%9E%84%E5%A6%99/id6754213088)

## Project Architecture

### Overall Architecture

The project uses a **feature-based MVVM architecture** with no third-party dependencies, relying only on Apple system frameworks (SwiftUI, AVFoundation, CoreML, Vision, CoreMotion, Combine).

- **Entry**: `LiveCaptureApp.swift` — SwiftUI `@main` entry, `WindowGroup` embeds `MainTabView`
- **View layer**: Organized by feature modules (`Features/Capture/`, `Features/Home/`, `Features/Settings/`, etc.), each module contains `Views/`, `ViewModels/`, `Components/`
- **Core services**: `Core/` contains UI-agnostic services (Camera, Detection, Motion, Storage)
- **Shared UI components**: `UI/Components/` stores reusable views across modules
- **Design system**: `UI/Design/DesignSystem.swift` centralizes design tokens for colors, fonts, spacing, corner radius, shadows, animations

### Directory Structure

```
LiveCapture/
├── LiveCaptureApp.swift              # App entry
├── Assets.xcassets/                  # Colors, icons, branding assets, developer avatar
├── Core/
│   ├── Camera/                       # Camera subsystem (7 files)
│   │   ├── CameraManager.swift       # AVCaptureSession lifecycle management
│   │   ├── CameraManager+Session.swift   # Permissions, session config, front/back switch
│   │   ├── CameraManager+Models.swift    # Lens types, zoom presets, error enums
│   │   ├── CameraManager+Zoom.swift      # Zoom control (preset switch / continuous zoom)
│   │   ├── CameraManager+Photo.swift     # Photo capture + JPEG encoding (3:4 crop)
│   │   ├── CameraManager+VideoOutput.swift # Video frame output → detection pipeline
│   │   └── CameraPreviewView.swift       # UIViewRepresentable camera preview
│   ├── Detection/                    # AI composition detection subsystem (4 files)
│   │   ├── CropDetectionStrategy.swift   # Detection strategy protocol + DetectionMode enum
│   │   ├── CoreMLCropDetector.swift      # Two-stage CoreML detector (BBox + Actor)
│   │   ├── AestheticCropDetector.swift   # Vision-based detector (face/body/saliency)
│   │   └── BoxCenterManager.swift        # Composition center tracking + alignment
│   ├── Motion/
│   │   └── MotionStabilityMonitor.swift  # Gyroscope/accelerometer stability analysis
│   ├── Storage/                      # Photo persistence subsystem (3 files)
│   │   ├── PhotoRecord.swift             # Photo record data model (Codable)
│   │   ├── PhotoStorageService.swift     # File storage + JSON index + EXIF extraction
│   │   └── ThumbnailGenerator.swift      # Thumbnail generation (CGImageSource)
│   └── Models/                       # CoreML model bundles
│       ├── student/                  # Fast mode (lightweight)
│       │   ├── AdacropStudentActor.mlpackage
│       │   └── AdacropStudentBBox.mlpackage
│       └── teacher/                  # Pro mode (full precision)
│           ├── AdacropTeacherActor.mlpackage
│           └── AdacropTeacherBBox.mlpackage
├── Features/
│   ├── Main/                         # Home and navigation
│   │   ├── MainView.swift            # Backup home view (unused)
│   │   └── MainTabView.swift         # TabBar root view (4 tabs)
│   ├── Capture/                      # Core capture feature
│   │   ├── Views/CaptureView.swift       # Capture main screen
│   │   ├── ViewModels/CaptureViewModel.swift # Capture pipeline state machine
│   │   └── Components/
│   │       ├── CameraPreviewSection.swift    # Preview layer + overlays
│   │       ├── CaptureButton.swift           # Shutter button
│   │       ├── DebugPanel.swift              # Debug info panel
│   │       ├── TopControlBar.swift           # Top control bar + menu
│   │       └── UserGuidanceView.swift        # User guidance text bar
│   ├── Home/                         # Photo gallery feature
│   │   ├── Views/HomeView.swift          # Grid gallery (LazyVGrid)
│   │   ├── Views/PhotoDetailView.swift   # Full-screen browser + share card
│   │   ├── ViewModels/HomeViewModel.swift
│   │   └── Components/PhotoCard.swift    # Thumbnail card
│   ├── Settings/
│   │   └── Views/SettingsView.swift      # Settings (theme / capture / engine)
│   ├── ShareCard/
│   │   └── ShareCardGenerator.swift      # Share card image generator (1080×1440)
│   └── LiveCompose/
│       └── Views/LiveComposeView.swift   # About page / branding
├── UI/
│   ├── Design/DesignSystem.swift         # Design tokens and view modifiers
│   └── Components/
│       ├── CircleButton.swift            # Circular button component
│       ├── ContentOverlayView.swift      # Preview overlays (gridlines / tracking point)
│       ├── ToastView.swift               # Toast hints (deprecated)
│       └── ZoomRingView.swift            # Zoom preset ring
└── Utilities/
    └── Helpers/
        ├── HapticManager.swift           # Haptic feedback manager
        └── UniformSmoother.swift         # Rectangle smoothing filter (EWMA)
```

### Navigation and View Hierarchy

```
MainTabView (TabView, 4 Tabs)
├── Tab 1 "LiveCompose"  → LiveComposeView        # Branding / about page
├── Tab 2 "Gallery"      → GalleryView            # Photo grid → PhotoBrowserView → Share card sheet
├── Tab 3 "Capture"      → fullScreenCover → CaptureView  # Capture screen (full-screen cover)
└── Tab 4 "Settings"     → SettingsView           # Appearance / capture / engine settings
```

- The app UI currently uses Chinese tab labels: "构妙" (LiveCompose), "图库" (Gallery), "拍摄" (Capture), and "设置" (Settings).
- The capture tab uses `.fullScreenCover`; after selection it immediately returns to Tab 1.
- State persistence uses `@AppStorage`: `detectionMode`, `autoCaptureEnabled`, `captureDelay`, `colorScheme`.

### Core Data Flow: Intelligent Capture Pipeline

The capture pipeline is driven by a **9-stage state machine** in `CaptureViewModel`:

| Stage | Description |
|------|-------------|
| `idle` | Initial idle |
| `startingCamera` | Start camera and motion sensors |
| `waitingForStability` | Wait for device stability (gyroscope) |
| `detectingRegion` | Run AI composition detection on current frame |
| `templateReady` | Detection complete, lock reference pose and begin tracking |
| `readyToCapture` | Composition aligned, ready to trigger auto capture |
| `capturingPhoto` | Capture photo |
| `savingPhoto` | Process and persist photo |
| `error` | Error state |

```
Camera frame input (60fps)
    │
    ▼
MotionStabilityMonitor ── Accel + gyro ──→ isStable?
    │                                      │
    ▼                                      ▼ (stable)
CropDetectionStrategy ── Detect best composition region
    │                                      │
    ▼                                      │
BoxCenterManager.setBaseCenter() ── Record detection center
    │                                      │
    ▼                                      │
CMDeviceMotion pose changes ──→ Screen offset
    │                                      │
    ▼                                      │
BoxCenterManager.isAlignedWithCenter() ── Aligned?
    │                                      │
    ▼ (aligned + delay)                     │
CameraManager.capturePhoto() ── 3:4 crop + JPEG
    │                                      │
    ▼                                      │
PhotoStorageService.savePhoto() ── Write files + EXIF
    │                                      │
    ▼                                      │
Pipeline reset, wait for next capture
```

### Core Services

#### 1. Camera Subsystem (`CameraManager`)

Built on `AVCaptureSession` with the `.photo` preset and supports:

- **Multi-lens switching**: ultra-wide (13mm) / wide (24mm) / telephoto (77mm) / front (24mm TrueDepth)
- **Zoom control**: preset switching (0.5×/1×/2×) + continuous pinch zoom with smooth transitions
- **Video output**: `AVCaptureVideoDataOutput` frames feed the detection pipeline
- **Photo output**: `AVCapturePhotoOutput` captures photo then auto-crops to 3:4 and re-encodes as JPEG
- **Thread isolation**: all session operations are serialized on `sessionQueue`, video frames on `videoOutputQueue`

#### 2. AI Detection Engine

Uses the **strategy pattern** to enable dual-engine switching:

**CoreML Engine (`CoreMLCropDetector`)** — two-stage pipeline:

1. **BBox stage**: input 224×224 RGB → output normalized bounding box `[cx, cy, w, h]`
2. **Actor stage**: crop region → output 7 action probabilities (still / left / right / up / down / zoom in / zoom out) → refine the bounding box with best action

Model specs:

| Mode | BBox Model | Actor Model | Notes |
|------|-----------|------------|------|
| Fast | AdacropStudentBBox | AdacropStudentActor | Lightweight, suitable for real-time preview |
| Pro | AdacropTeacherBBox | AdacropTeacherActor | Full precision, higher image quality |

**Vision Engine (`AestheticCropDetector`)** — pure Vision framework, no extra models:

1. `VNDetectFaceRectanglesRequest` — face detection
2. `VNDetectHumanRectanglesRequest` — human detection
3. `VNGenerateAttentionBasedSaliencyImageRequest` — saliency detection
4. Weighted scoring: confidence 40% + face coverage 30% + rule-of-thirds 20% + edge safety 10%
5. Return highest-scoring `AestheticCrop`

#### 3. Motion Tracking (`MotionStabilityMonitor` + `BoxCenterManager`)

**`MotionStabilityMonitor`**: `CMMotionManager` at 60Hz, sliding-window standard deviation check:

- Accel + gyro + device motion sampled in sync
- 10 consecutive stable frames → `isStable = true`, 5 consecutive unstable frames → `isStable = false`
- Large motion detection → auto reset tracking

**`BoxCenterManager`**: physics-driven composition center tracking:

- Map AI-detected center to screen coordinates, compute offset vector to screen center
- During tracking, use real-time `CMAttitude` (pitch/roll, limited to ±30°) to compute tracking-point displacement
- **Adaptive gain**: farther from center increases gain for faster convergence, closer to center reduces gain to avoid overshoot
- **Velocity prediction compensation**: reduces perceived latency
- **Magnetic snap**: exponential curve pulls toward center when close
- **Alignment lock**: stay aligned for 1s to lock to exact center (15pt tolerance)

#### 4. Storage Subsystem (`PhotoStorageService`)

- **Storage location**: `Application Support/LiveCapture/photos/` + `thumbnails/`
- **Index file**: `records.json` (JSON-encoded `[PhotoRecord]`)
- **Thumbnails**: `CGImageSourceCreateThumbnailAtIndex`, max 300px, JPEG 0.8 compression
- **EXIF extraction**: ISO, shutter speed, aperture, image dimensions
- **Threads**: read/write on a serial `.utility` queue, publish changes via `CurrentValueSubject`

### State Management

| Class | Responsibility | Key published properties |
|----|------|-------------|
| `CaptureViewModel` | Capture pipeline orchestration | `pipelineStage`, `guidanceText`, `isDetectionReady`, `trackPoint`, `isAligned` |
| `CameraManager` | Camera hardware control | `isSessionRunning`, `zoomState`, `activeLensKind`, `isCapturing` |
| `MotionStabilityMonitor` | Motion analysis | `isStable`, `deviceMotion`, `largeMotionDetected` |
| `BoxCenterManager` | Tracking point computation | `trackPoint`, `isAligned`, `distanceToCenter` |
| `HomeViewModel` | Gallery state | `records`, `isLoading` |
| `PhotoStorageService` | Persistence | `recordsPublisher: CurrentValueSubject` |

### Design System

`DesignSystem.swift` centralizes global visual tokens:

- **Color semantics**: Primary (system blue), Secondary (violet), Accent (orange), success/warning/error/info
- **Dark mode**: text and background auto-adapt via `@Environment(\.colorScheme)`
- **Fonts**: Rounded system fonts 11-34pt, with monospaced variants
- **Spacing**: 2px - 64px scale definitions
- **Animation presets**: `quick`(0.2s), `smooth`(0.3s), `bouncy`(0.4s spring), `gentle`(0.5s ease)
- **ViewModifiers**: glassmorphism (`GlassmorphismModifier`), neumorphism (`NeumorphismModifier`), glow (`GlowModifier`), pulse (`PulseModifier`)

### Tech Stack

| Layer | Tech |
|------|------|
| UI Framework | SwiftUI (iOS 17.6+) |
| Camera | AVFoundation (`AVCaptureSession`) |
| AI Inference | CoreML (`.mlpackage` on-device models) |
| Visual Analysis | Vision (`VNDetectFaceRectangles`, `VNGenerateAttentionBasedSaliencyImage`) |
| Motion Sensing | CoreMotion (`CMMotionManager`, 60Hz) |
| Image Processing | CoreImage / ImageIO |
| Reactive | Combine (`@Published`, `CurrentValueSubject`) |
| Haptics | UIKit `UIFeedbackGenerator` |
| Data Persistence | FileManager + JSON (Codable) |
| No Third-Party Dependencies | — |

## Related Projects

| Platform | Link | Notes |
|------|------|------|
| GitHub Org | [github.com/LiveCompose](https://github.com/LiveCompose) | All open-source code |
| Hugging Face | [huggingface.co/LiveCompose](https://huggingface.co/LiveCompose) | Model weights and datasets |
| App Store | [构妙 LiveCapture](https://apps.apple.com/cn/app/%E6%9E%84%E5%A6%99/id6754213088) | iOS app |
