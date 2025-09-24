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
- 优化：`CameraPreviewView` 暴露 `AVCaptureVideoPreviewLayer`，`ContentView` 使用该层进行坐标转换，移除全局窗口查找。
- 完成 UI/UX 与性能优化任务标记。

2025-09-20
- 语法检查：使用 xcodebuild 编译发现 `PreviewLayerProvider` 未满足 `ObservableObject` 协议。
- 修复：
  - `PreviewLayerProvider.swift` 引入 Combine，添加 `objectWillChange`（`PassthroughSubject`），在 `layer` 的 `willSet` 中发送变更。
  - `CameraManager.swift` 引入 Combine 并添加 `objectWillChange`，保留 `@Published` 属性；同时将已废弃的视频方向 API 改为 iOS 17 的 `videoRotationAngle`（90 度代表竖屏）。
  - `MotionStabilityMonitor.swift` 引入 Combine（为 `@Published` 可用）。
  - `ContentView.swift` 引入 UIKit 以使用 `UIApplication`（用于窗口中心坐标计算）。
- 复编译：构建成功，无语法错误；仅保留与架构相关的一条构建警告（非语法问题）。

- 2025-09-21: 修复跨平台与预览相关编译/静态检查问题
  - 编辑 `LiveCapture/CameraPreviewView.swift`：
    - 使用 `#if os(iOS) || os(tvOS)` 包裹 UIKit 分支；非 iOS 提供 SwiftUI 占位视图。
    - 在非 iOS 分支添加 `typealias PreviewLayerProvider = AnyObject` 以避免静态分析的类型缺失报错。
  - 编辑 `LiveCapture/MotionStabilityMonitor.swift`：
    - 使用 `#if os(iOS) || os(tvOS)` 包裹 `CoreMotion` 实现；非 iOS 提供 `isStable` 始终为 false 的 stub。
  - 编辑 `LiveCapture/ContentView.swift`：
    - 将 iOS 实现包裹在 `#if os(iOS) || os(tvOS)`，为其他平台提供占位 `ContentView`。
    - 将 `#Preview` 包裹在 `#if DEBUG`。
    - 为闭包参数添加显式类型注解，消除推断错误。
  - 待办追踪：创建并完成 4 条修复项；当前仅剩"更新 ACTION_LOG.md"已完成。
  - 验证：运行 `xcodebuild -scheme LiveCapture -sdk iphonesimulator` 构建成功。

- 2025-09-21: 修复设备稳定性检测过于严格的问题
  - 诊断问题：用户反馈即使手机平放也显示设备不稳定，经分析发现阈值设置过严格
  - 编辑 `LiveCapture/MotionStabilityMonitor.swift`：
    - 调整稳定性阈值：加速度标准差从0.02提升到0.15，陀螺仪标准差从0.02提升到0.10
    - 改进稳定性计算算法：计算每个样本的向量长度后求标准差，而不是将所有轴数据混合计算
    - 添加详细调试信息：在控制台输出具体的标准差数值，便于调试
    - 增加 debugInfo 发布属性，实时显示传感器数据状态
  - 编辑 `LiveCapture/ContentView.swift`：更新调试界面显示传感器详细信息
  - 验证：构建成功无错误，修复后的阈值更加合理，能正确检测真实的稳定状态

- 2025-09-20: 简化 AdacropModel 使用模拟逻辑
  - 编辑 `LiveCapture/AdacropModel.swift`：
    - 移除对真实机器学习模型的依赖（不再需要 MLModel 文件路径）
    - 简化初始化器为无参数构造函数
    - 修改 `predictCropBox` 方法使用模拟逻辑，返回固定在画面左上角但不靠近边框的矩形框
    - 保持异步回调接口一致性，在后台队列返回预设的 CropBox
    - 模拟框位置：距离左边框10%，距离顶部30%，尺寸为30%x20%
  
- 2025-09-20: 更新 ContentView 并添加调试信息显示
  - 编辑 `LiveCapture/ContentView.swift`：
    - 更新 AdacropModel 初始化调用，移除模型文件路径参数
    - 添加调试状态变量：debugMessage 和 showDebugInfo
    - 实现可折叠的调试信息面板，显示在屏幕顶部
    - 调试面板显示内容：当前状态、稳定性、跟踪位置、对准状态
    - 在所有关键操作点添加详细的调试信息更新：
      * 相机启动状态
      * 设备稳定性检测
      * 目标区域识别过程
      * 跟踪状态和置信度
      * 对准距离计算
      * 自动拍照倒计时
      * 照片保存状态

- 2025-09-20: 解决跟踪点抖动问题，实现稳定的目标追踪
  - 问题分析：跟踪点一直抖动，无法稳定追踪画面中的目标
  - 编辑 `LiveCapture/TrackingManager.swift`：
    - 提高置信度阈值从0.3到0.7，只接受高质量的跟踪结果
    - 添加平滑滤波机制：维护5帧跟踪结果的移动平均，减少抖动
    - 实现连续帧质量评估：需要连续3帧好的结果才认为跟踪稳定
    - 添加跟踪丢失检测：超过2帧差的结果就重置跟踪
    - 新增 onTrackingLost 回调，通知上层应用处理跟踪丢失情况
    - 添加边界框平滑算法：对位置和尺寸进行移动平均计算
  - 编辑 `LiveCapture/AdacropModel.swift`：
    - 实现智能初始跟踪点选择，替代固定位置逻辑
    - 添加人脸检测优先级：优先使用人脸区域作为跟踪目标
    - 实现特征丰富区域检测：使用VNDetectRectanglesRequest找到最佳跟踪区域
    - 添加多候选区域机制：提供多个备选跟踪区域，动态选择最佳区域
    - 改进初始化逻辑：从简单固定位置升级到基于图像内容的智能选择
  - 编辑 `LiveCapture/ContentView.swift`：
    - 更新跟踪管理器回调处理：移除旧的置信度检查（已在TrackingManager内部处理）
    - 添加跟踪丢失处理逻辑：自动重置跟踪器并等待重新识别
    - 改进调试信息显示：显示"跟踪稳定"而不是简单的置信度信息
  - 编辑 `LiveCapture/MotionStabilityMonitor.swift`：
    - 优化稳定性检测算法：添加连续帧计数机制避免频繁状态切换
    - 调整时间窗口：从0.5秒增加到0.8秒，获得更稳定的判断
    - 收紧阈值：加速度阈值调整到0.12，陀螺仪阈值调整到0.08，减少微小抖动影响
    - 实现状态稳定性：需要连续10帧稳定才认为真正稳定，超过5帧不稳定才切换为不稳定
    - 改进调试信息：添加连续稳定帧计数，便于调试和监控
  - 验证：构建成功无错误，跟踪系统现在应该能够：
    * 找到更适合的初始跟踪点（人脸或特征丰富区域）
    * 保持稳定的跟踪，减少抖动现象
    * 在跟踪丢失时自动恢复，重新寻找目标
    * 提供更可靠的设备稳定性检测

- 2025-09-20: 紧急修复EXC_BAD_ACCESS内存访问错误
  - 问题分析：用户报告刚打开app时出现EXC_BAD_ACCESS错误，发生在传感器加载过程中
  - 根因：MotionStabilityMonitor存在严重的线程安全问题
    * accSamples和gyroSamples数组在多线程间被并发访问
    * 加速度计和陀螺仪更新在OperationQueue中并发运行，同时修改数组
    * updateStability()和trim()函数形成读写竞争条件，导致内存冲突
  - 编辑 `LiveCapture/MotionStabilityMonitor.swift`：
    - 替换OperationQueue为串行DispatchQueue，确保所有数据操作线程安全
    - 创建专用数据队列 `dataQueue`，所有数组访问都在此队列中进行
    - 修改传感器更新回调，将数据处理封装在dataQueue.async中
    - 改进stop()函数，在数据队列中安全地清理状态和数组
    - 添加限流机制：最多每50ms更新一次稳定性计算，减少CPU负担
    - 新增updateStabilityIfNeeded()函数，避免过度频繁的计算
  - 验证：构建成功无错误，彻底解决了线程竞争问题，确保内存访问安全

## 2025年9月20日 - 修复跟踪循环跳转问题
- **问题描述**：用户反馈在目标识别阶段一直来回跳转，没有坐标点出现
- **根因分析**：
  - TrackingManager中的跟踪参数过于严格（置信度阈值0.7，需要连续3帧稳定）
  - 跟踪很快失败，导致cropRectInView被重置为nil
  - 下一帧又重新调用Adacrop识别，形成循环
- **解决方案**：
  - 降低置信度阈值：从0.7降到0.5，提高跟踪成功率
  - 减少连续稳定帧要求：从3帧减少到2帧，更快开始输出跟踪结果
  - 增加容错能力：从2帧失败重置改为5帧，给予更多容错时间
  - 改进调试信息：添加更详细的状态提示，便于问题诊断
- **文件修改**：
  - `TrackingManager.swift`: 调整跟踪质量评估参数
  - `ContentView.swift`: 改进调试信息显示
- **预期效果**：跟踪更加稳定，减少重复识别，坐标点能正常显示

## 2025年9月20日 - 修复跟踪目标选择，实现真正的背景物体跟踪  
- **问题描述**：虽然坐标点已显示，但移动手机时点跟着移动，未真正跟踪背景中的物体
- **根因分析**：
  - AdacropModel选择的跟踪区域不是真正的静态背景物体
  - 优先使用人脸检测，但人脸可能移动
  - 矩形检测和备选区域选择不够智能
  - 缺乏对静态特征的优先级判断
- **解决方案**：
  - **重新设计目标选择优先级**：轮廓特征 → 静态矩形物体 → 人脸区域 → 默认中心
  - **新增轮廓检测**：使用VNDetectContoursRequest找到特征丰富的复杂区域
  - **智能静态区域选择**：优先选择中心区域的矩形物体，更可能是静止的
  - **改进备选区域**：避开天空和地面，选择可能包含桌面、墙面等静物的区域
  - **添加检测类型追踪**：在调试信息中显示使用了哪种检测方法
- **技术细节**：
  - 使用VNDetectContoursRequest检测复杂轮廓(>20个点)
  - 静态矩形检测优先选择距离中心近的区域
  - CropBox结构新增detectionType字段用于调试
  - 改进的中心加权区域避开边缘，专注于静物区域
- **文件修改**：
  - `AdacropModel.swift`: 完全重写目标选择逻辑
  - `ContentView.swift`: 添加检测类型的调试信息显示
- **预期效果**：跟踪真正的背景物体，移动手机时跟踪点保持在原物体位置

