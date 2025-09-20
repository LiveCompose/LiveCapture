2025-09-20
- 初始化 TODO 列表（P1-P4 分解）；开始“下载并保存 API 文档到 docs/”。
- 已下载并保存 Apple 文档到 docs/（AVFoundation/CoreMotion/Vision/Photos/隐私权限）。
- 标记“下载文档”为完成；按用户要求取消“P4: NIMA 集成”。
- 实现 P1 预览：新增 `CameraManager.swift`、`CameraPreviewView.swift`，配置 `AVCaptureSession`、`AVCaptureVideoPreviewLayer`。
- 实现 P1 拍照：在 `CameraManager` 集成 `AVCapturePhotoOutput`，保存至相册（`PHPhotoLibrary`）。
- 更新 `ContentView.swift`：接入预览、中心准星与快门按钮、保存提示。
- 更新工程 Info.plist 使用权说明键：`NSCameraUsageDescription`、`NSPhotoLibraryAddUsageDescription`。
- 实现 P2：`MotionStabilityMonitor` 监测稳定窗口，标准差阈值判断。
- 实现 P2/2.2-2.3：`AdacropModel` 集成 CoreML+Vision，裁切框可视化 `OverlayView`。
- 实现 P3：`TrackingManager` 使用 `VNTrackObjectRequest` 跟踪并在 UI 绘制跟踪点。
- 实现 P4：自动对准阈值与去抖，触发 `capturePhoto()`；准星变色反馈。

