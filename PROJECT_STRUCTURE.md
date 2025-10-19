# LiveCapture 项目结构说明

## 📁 项目架构

### Core/ - 核心功能模块
业务逻辑的核心实现,不依赖UI层

#### Core/Camera/
相机管理相关功能
- `CameraManager.swift` - 相机会话管理主类
- `CameraManager+Models.swift` - 数据模型定义
- `CameraManager+Session.swift` - 会话配置与生命周期
- `CameraManager+VideoOutput.swift` - 视频帧输出处理
- `CameraManager+Photo.swift` - 照片拍摄与保存
- `CameraManager+Zoom.swift` - 变焦控制
- `CameraPreviewView.swift` - 相机预览视图

#### Core/Detection/
检测与追踪功能
- `AestheticCropDetector.swift` - 美学裁切检测器
- `BoxCenterManager.swift` - 目标中心点追踪管理器

#### Core/Motion/
运动传感器相关
- `MotionStabilityMonitor.swift` - 设备稳定性监测

### Features/ - 功能模块
按功能划分的业务逻辑和UI

#### Features/Main/
应用主页
- `MainView.swift` - 应用入口主页

#### Features/Capture/
拍摄功能
- **ViewModels/** - 视图模型层
  - `CaptureViewModel.swift` - 拍摄功能业务逻辑
  
- **Views/** - 视图层
  - `CaptureView.swift` - 主拍摄界面
  
- **Components/** - UI组件
  - `DebugPanel.swift` - 调试信息面板
  - `UserGuidanceView.swift` - 用户引导提示
  - `CaptureButton.swift` - 主拍照按钮
  - `TopControlBar.swift` - 顶部控制栏
  - `CameraPreviewSection.swift` - 相机预览区域

### UI/ - 通用UI组件
可复用的UI元素和设计系统

#### UI/Components/
通用组件
- `CircleButton.swift` - 圆形按钮组件
- `ZoomRingView.swift` - 变焦环控件
- `ToastView.swift` - Toast提示组件
- `ContentOverlayView.swift` - 内容覆盖层

#### UI/Design/
设计系统
- `DesignSystem.swift` - 颜色、字体、动画等设计规范

### Utilities/ - 工具类
通用工具和辅助功能

#### Utilities/Helpers/
辅助工具
- `HapticManager.swift` - 触觉反馈管理
- `UniformSmoother.swift` - 平滑滤波器

#### Utilities/Extensions/
(预留扩展功能)

## 🔧 重构改进

### 1. 模块化设计
- **按功能分层**: Core(核心) → Features(功能) → UI(界面)
- **职责清晰**: 每个文件单一职责,易于维护和测试
- **依赖明确**: 高层依赖低层,避免循环依赖

### 2. 代码精简
- **提取组件**: ContentView 从 700+ 行精简至 200+ 行
- **分离关注点**: UI、业务逻辑、数据模型各自独立
- **复用性**: 通用组件可在多处使用

### 3. 命名规范
- **语义化命名**: 文件名准确描述其功能
- **一致性**: 遵循 Swift 命名约定
- **可读性**: 清晰的层级结构便于导航

### 4. 维护性提升
- **易扩展**: 新增功能只需在对应模块添加
- **易测试**: 模块化后方便单元测试
- **易协作**: 清晰结构降低团队协作成本

## 📝 文件移动记录

### 从根目录移至新位置:
- ✅ CameraManager 系列 → Core/Camera/
- ✅ AestheticCropDetector → Core/Detection/
- ✅ BoxCenterManager → Core/Detection/
- ✅ MotionStabilityMonitor → Core/Motion/
- ✅ ContentView → Features/Capture/Views/CaptureView.swift
- ✅ ContentViewModel → Features/Capture/ViewModels/CaptureViewModel.swift
- ✅ MainView → Features/Main/MainView.swift
- ✅ ZoomRingView, ToastView, ContentOverlayView → UI/Components/
- ✅ DesignSystem → UI/Design/
- ✅ HapticManager, UniformSmoother → Utilities/Helpers/

## ⚠️ 后续工作

1. **更新 Xcode 项目引用**: 需要在 Xcode 中更新文件引用路径
2. **检查编译**: 确保所有导入语句正确
3. **测试功能**: 验证重构后功能正常
4. **文档更新**: 更新相关技术文档

## 🎯 最佳实践

### 添加新功能时
1. 确定功能归属 (Core/Features/UI/Utilities)
2. 在对应目录创建文件
3. 遵循现有命名和组织模式
4. 保持单一职责原则

### 修改现有代码时
1. 只修改相关模块
2. 避免跨层级强耦合
3. 考虑复用性和可测试性
4. 更新相关文档
