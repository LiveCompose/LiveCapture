# 构妙 LiveCapture

[English](README.md) | 简体中文

构妙 LiveCapture 是一款基于强化学习的 AI 端侧智能构图辅助 APP，我们致力于通过实时分析取景画面，结合陀螺仪追踪与美学评分驱动，主动引导用户移动手机以获得最佳构图，让每一次快门都定格最美的瞬间。

[![Hugging Face](https://img.shields.io/badge/%F0%9F%A4%97%20Hugging%20Face-LiveCompose-yellow)](https://huggingface.co/LiveCompose)
[![GitHub](https://img.shields.io/badge/GitHub-LiveCompose-black?logo=github)](https://github.com/LiveCompose)
[![App Store](https://img.shields.io/badge/App_Store-%E6%9E%84%E5%A6%99_LiveCapture-blue)](https://apps.apple.com/cn/app/%E6%9E%84%E5%A6%99/id6754213088)
![Code Size](https://img.shields.io/badge/Code_Size-16k%2B_Lines-green)
![Model](https://img.shields.io/badge/Framework-CoreML-red)
![Platform](https://img.shields.io/badge/Platform-iOS-blueviolet)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

> 已上线 App Store：[构妙 LiveCapture](https://apps.apple.com/cn/app/%E6%9E%84%E5%A6%99/id6754213088)

## 项目架构

### 总体架构

项目采用 **基于功能模块的 MVVM 架构**，无任何第三方依赖，全部使用 Apple 系统框架（SwiftUI、AVFoundation、CoreML、Vision、CoreMotion、Combine）。

- **入口**：`LiveCaptureApp.swift` — SwiftUI `@main` 入口，`WindowGroup` 内嵌 `MainTabView`
- **视图层**：按功能模块划分（`Features/Capture/`、`Features/Home/`、`Features/Settings/` 等），每个模块内分 `Views/`、`ViewModels/`、`Components/`
- **核心服务层**：`Core/` 目录包含与 UI 框架无关的服务（Camera、Detection、Motion、Storage）
- **共享 UI 组件**：`UI/Components/` 存放跨模块复用的视图组件
- **设计系统**：`UI/Design/DesignSystem.swift` 集中管理颜色、字体、间距、圆角、阴影、动画等设计 Token

### 目录结构

```
LiveCapture/
├── LiveCaptureApp.swift              # App 入口
├── Assets.xcassets/                  # 颜色、图标、品牌素材、开发者头像
├── Core/
│   ├── Camera/                       # 相机子系统（7 文件）
│   │   ├── CameraManager.swift       # AVCaptureSession 生命周期管理
│   │   ├── CameraManager+Session.swift   # 权限、会话配置、前后摄切换
│   │   ├── CameraManager+Models.swift    # 镜头类型、变焦预设、错误枚举
│   │   ├── CameraManager+Zoom.swift      # 变焦控制（预设切换 / 连续变焦）
│   │   ├── CameraManager+Photo.swift     # 拍照与 JPEG 编码（3:4 裁切）
│   │   ├── CameraManager+VideoOutput.swift # 视频帧输出 → 检测流水线
│   │   └── CameraPreviewView.swift       # UIViewRepresentable 相机预览
│   ├── Detection/                    # AI 构图检测子系统（4 文件）
│   │   ├── CropDetectionStrategy.swift   # 检测策略协议 + DetectionMode 枚举
│   │   ├── CoreMLCropDetector.swift      # 两阶段 CoreML 检测器（BBox + Actor）
│   │   ├── AestheticCropDetector.swift   # Vision 框架检测器（人脸/人体/显著性）
│   │   └── BoxCenterManager.swift        # 构图中心追踪与对齐判断
│   ├── Motion/
│   │   └── MotionStabilityMonitor.swift  # 陀螺仪/加速度计稳定性分析
│   ├── Storage/                      # 照片持久化子系统（3 文件）
│   │   ├── PhotoRecord.swift             # 照片记录数据模型（Codable）
│   │   ├── PhotoStorageService.swift     # 文件存储 + JSON 索引 + EXIF 提取
│   │   └── ThumbnailGenerator.swift      # 缩略图生成（CGImageSource）
│   └── Models/                       # CoreML 模型包
│       ├── student/                  # 快速模式（轻量）
│       │   ├── AdacropStudentActor.mlpackage
│       │   └── AdacropStudentBBox.mlpackage
│       └── teacher/                  # 专业模式（完整精度）
│           ├── AdacropTeacherActor.mlpackage
│           └── AdacropTeacherBBox.mlpackage
├── Features/
│   ├── Main/                         # 主页与导航
│   │   ├── MainView.swift            # 备用首页（当前未启用）
│   │   └── MainTabView.swift         # TabBar 导航根视图（4 Tab）
│   ├── Capture/                      # 核心拍摄功能
│   │   ├── Views/CaptureView.swift       # 拍摄主界面
│   │   ├── ViewModels/CaptureViewModel.swift # 拍摄流水线状态机
│   │   └── Components/
│   │       ├── CameraPreviewSection.swift    # 预览层 + 覆盖层
│   │       ├── CaptureButton.swift           # 快门按钮
│   │       ├── DebugPanel.swift              # 调试信息面板
│   │       ├── TopControlBar.swift           # 顶部控制栏 + 菜单
│   │       └── UserGuidanceView.swift        # 用户引导文字条
│   ├── Home/                         # 照片图库功能
│   │   ├── Views/HomeView.swift          # 网格图库（LazyVGrid）
│   │   ├── Views/PhotoDetailView.swift   # 全屏图片浏览器 + 分享卡
│   │   ├── ViewModels/HomeViewModel.swift
│   │   └── Components/PhotoCard.swift    # 缩略图卡片
│   ├── Settings/
│   │   └── Views/SettingsView.swift      # 设置页（主题 / 拍摄 / 引擎）
│   ├── ShareCard/
│   │   └── ShareCardGenerator.swift      # 分享卡片图片生成（1080×1440）
│   └── LiveCompose/
│       └── Views/LiveComposeView.swift   # 关于页 / 品牌展示
├── UI/
│   ├── Design/DesignSystem.swift         # 设计 Token 与视图修饰器
│   └── Components/
│       ├── CircleButton.swift            # 圆形按钮组件
│       ├── ContentOverlayView.swift      # 取景覆盖层（网格线 / 追踪点）
│       ├── ToastView.swift               # Toast 提示（已弃用）
│       └── ZoomRingView.swift            # 变焦预设环
└── Utilities/
    └── Helpers/
        ├── HapticManager.swift           # 触觉反馈管理器
        └── UniformSmoother.swift         # 矩形平滑滤波器（EWMA）
```

### 导航与视图层级

```
MainTabView (TabView, 4 Tab)
├── Tab 1 "构妙"  → LiveComposeView        # 品牌展示 / 关于页
├── Tab 2 "图库"  → GalleryView            # 照片网格 → PhotoBrowserView → 分享卡 Sheet
├── Tab 3 "拍摄"  → fullScreenCover → CaptureView  # 拍摄界面（全屏覆盖）
└── Tab 4 "设置"  → SettingsView           # 外观 / 拍摄 / 引擎设置
```

- 当前应用 UI 的 Tab 标签为“构妙”(LiveCompose)、“图库”(Gallery)、“拍摄”(Capture) 和 “设置”(Settings)。
- 拍摄 Tab 使用 `.fullScreenCover` 触发，选择后立即回弹到 Tab 1
- 状态持久化使用 `@AppStorage`：`detectionMode`、`autoCaptureEnabled`、`captureDelay`、`colorScheme`

### 核心数据流：智能拍摄流水线

拍摄流水线由 `CaptureViewModel` 以 **9 阶段状态机** 驱动：

| 阶段 | 说明 |
|------|------|
| `idle` | 初始待机 |
| `startingCamera` | 启动相机与运动传感器 |
| `waitingForStability` | 等待设备姿态稳定（陀螺仪判定） |
| `detectingRegion` | 对当前帧执行 AI 构图检测 |
| `templateReady` | 检测完成，锁定参考姿态，开始追踪 |
| `readyToCapture` | 构图对齐，准备触发自动拍摄 |
| `capturingPhoto` | 执行拍照 |
| `savingPhoto` | 照片处理与持久化 |
| `error` | 异常状态 |

```
相机帧输入 (60fps)
    │
    ▼
MotionStabilityMonitor ── 加速度计 + 陀螺仪 ──→ isStable?
    │                                              │
    ▼                                              ▼ (稳定)
CropDetectionStrategy ── 检测最佳构图区域           │
    │                                              │
    ▼                                              │
BoxCenterManager.setBaseCenter() ── 记录检测中心    │
    │                                              │
    ▼                                              │
CMDeviceMotion 姿态变化 ──→ 屏幕坐标偏移             │
    │                                              │
    ▼                                              │
BoxCenterManager.isAlignedWithCenter() ── 对齐?     │
    │                                              │
    ▼ (对齐 + 延迟)                                 │
CameraManager.capturePhoto() ── 3:4 裁切 + JPEG     │
    │                                              │
    ▼                                              │
PhotoStorageService.savePhoto() ── 写文件 + EXIF     │
    │                                              │
    ▼                                              │
流水线重置，等待下一轮拍摄
```

### 核心服务详解

#### 1. 相机子系统 (`CameraManager`)

基于 `AVCaptureSession` 封装，`.photo` 预设，支持：

- **多镜头切换**：超广角 (13mm) / 广角 (24mm) / 长焦 (77mm) / 前置 (24mm TrueDepth)
- **变焦控制**：预设切换（0.5×/1×/2×）+ 连续捏合变焦，含平滑过渡
- **视频输出**：`AVCaptureVideoDataOutput` 采集帧回调给检测流水线
- **拍照输出**：`AVCapturePhotoOutput` 拍照后自动 3:4 裁切并重编码为 JPEG
- **线程隔离**：所有会话操作串行在 `sessionQueue`，视频帧在 `videoOutputQueue`

#### 2. AI 检测引擎

采用 **策略模式** 实现双引擎可切换：

**CoreML 引擎 (`CoreMLCropDetector`)** — 两阶段管道：

1. **BBox 阶段**：输入 224×224 RGB → 输出归一化边界框 `[cx, cy, w, h]`
2. **Actor 阶段**：裁切画面区域 → 输出 7 种动作概率（不动 / 左 / 右 / 上 / 下 / 缩小 / 放大）→ 最优动作精修边界框

模型规格：

| 模式 | BBox 模型 | Actor 模型 | 说明 |
|------|-----------|------------|------|
| 快速 (Fast) | AdacropStudentBBox | AdacropStudentActor | 轻量，适合实时预览 |
| 专业 (Pro) | AdacropTeacherBBox | AdacropTeacherActor | 完整精度，更高画质 |

**Vision 引擎 (`AestheticCropDetector`)** — 纯 Vision 框架，无需额外模型：

1. `VNDetectFaceRectanglesRequest` — 人脸检测
2. `VNDetectHumanRectanglesRequest` — 人体检测
3. `VNGenerateAttentionBasedSaliencyImageRequest` — 显著性区域检测
4. 候选区域加权评分：置信度 40% + 人脸覆盖 30% + 三分法构图 20% + 边缘安全区 10%
5. 返回最高分 `AestheticCrop`

#### 3. 运动追踪 (`MotionStabilityMonitor` + `BoxCenterManager`)

**`MotionStabilityMonitor`**：`CMMotionManager` 60Hz 采样，滑动窗口标准差判定：

- 加速度计 + 陀螺仪 + 设备姿态同步采集
- 连续 10 帧稳定 → `isStable = true`，连续 5 帧不稳定 → `isStable = false`
- 大幅运动检测 → 自动触发追踪重置

**`BoxCenterManager`**：物理驱动构图中心追踪：

- 检测时将 AI 给出的构图中心映射到屏幕坐标系，计算与画面中心的偏移向量
- 追踪时根据 `CMAttitude`（pitch/roll，限制 ±30°）的实时变化计算追踪点位移
- **自适应增益**：距中心越远增益越大（快速靠近），越近增益越小（防止过冲）
- **速度预测补偿**：降低延迟感
- **磁性吸附**：接近中心时指数曲线吸向中心点
- **对齐锁定**：持续对齐 1 秒后锁定到精确中心（容差 15pt）

#### 4. 存储子系统 (`PhotoStorageService`)

- **存储位置**：`Application Support/LiveCapture/photos/` + `thumbnails/`
- **索引文件**：`records.json`（JSON 编码 `[PhotoRecord]`）
- **缩略图**：`CGImageSourceCreateThumbnailAtIndex`，最大 300px，JPEG 0.8 压缩
- **EXIF 提取**：ISO、快门速度、光圈、图片尺寸
- **线程**：读写操作在串行 `.utility` 队列执行，通过 `CurrentValueSubject` 发布变更

### 状态管理

| 类 | 职责 | 关键发布属性 |
|----|------|-------------|
| `CaptureViewModel` | 拍摄流水线编排 | `pipelineStage`, `guidanceText`, `isDetectionReady`, `trackPoint`, `isAligned` |
| `CameraManager` | 相机硬件控制 | `isSessionRunning`, `zoomState`, `activeLensKind`, `isCapturing` |
| `MotionStabilityMonitor` | 运动分析 | `isStable`, `deviceMotion`, `largeMotionDetected` |
| `BoxCenterManager` | 追踪点计算 | `trackPoint`, `isAligned`, `distanceToCenter` |
| `HomeViewModel` | 图库状态 | `records`, `isLoading` |
| `PhotoStorageService` | 持久化 | `recordsPublisher: CurrentValueSubject` |

### 设计系统

`DesignSystem.swift` 集中管理全局视觉 Token：

- **颜色语义**：Primary（系统蓝）、Secondary（紫罗兰）、Accent（橙色）、success/warning/error/info
- **深色模式**：文字色、背景色自动适配 `@Environment(\.colorScheme)`
- **字体**：Rounded 系统字体 11-34pt，含等宽变体
- **间距**：2px - 64px 分级定义
- **动画预设**：`quick`(0.2s)、`smooth`(0.3s)、`bouncy`(0.4s spring)、`gentle`(0.5s ease)
- **ViewModifier**：毛玻璃 (`GlassmorphismModifier`)、新拟态 (`NeumorphismModifier`)、发光 (`GlowModifier`)、脉冲 (`PulseModifier`)

### 技术栈

| 层面 | 技术 |
|------|------|
| UI 框架 | SwiftUI (iOS 17.6+) |
| 相机 | AVFoundation (`AVCaptureSession`) |
| AI 推理 | CoreML (`.mlpackage` 端侧模型) |
| 视觉分析 | Vision (`VNDetectFaceRectangles`, `VNGenerateAttentionBasedSaliencyImage`) |
| 运动感知 | CoreMotion (`CMMotionManager`, 60Hz) |
| 图片处理 | CoreImage / ImageIO |
| 响应式 | Combine (`@Published`, `CurrentValueSubject`) |
| 触觉 | UIKit `UIFeedbackGenerator` |
| 数据持久化 | FileManager + JSON (Codable) |
| 无第三方依赖 | — |

## 关联项目

| 平台 | 地址 | 说明 |
|------|------|------|
| GitHub 组织 | [github.com/LiveCompose](https://github.com/LiveCompose) | 全部开源代码 |
| Hugging Face | [huggingface.co/LiveCompose](https://huggingface.co/LiveCompose) | 模型权重与数据集 |
| App Store | [构妙 LiveCapture](https://apps.apple.com/cn/app/%E6%9E%84%E5%A6%99/id6754213088) | iOS 应用 |
