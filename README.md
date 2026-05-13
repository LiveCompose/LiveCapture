# 构妙 LiveCapture

基于强化学习的 AI 智能拍照辅助 APP 源码

## 技术栈

| 类别 | 技术 |
|------|------|
| 语言 | Swift 5.0 |
| UI 框架 | SwiftUI |
| 相机 | AVFoundation |
| AI  | Pytorch -> Core ML |
| 传感器 | CoreMotion  |
| 图像处理 | CoreImage |
| 响应式 | Combine |
| 最低系统 | iOS 17.6 |

## 项目链接

[LiveCompose](https://github.com/LiveCompose/LiveCompose)

## 项目结构

```
LiveCapture/
├── LiveCaptureApp.swift              # 应用入口
├── Core/
│   ├── Camera/                       # 相机管理 (AVCaptureSession, 变焦, 拍照)
│   ├── Detection/                    # AI 构图检测 + 陀螺仪主体追踪
│   └── Motion/                       # 稳定性监测
├── Features/
│   ├── Capture/Views/                # 拍摄主界面
│   ├── Capture/ViewModels/           # 拍摄状态机
│   ├── Capture/Components/           # 取景框、快门、工具栏、引导提示
│   └── Main/                         # 主页/模式选择
├── UI/
│   ├── Components/                   # CircleButton, ToastView, ZoomRingView 等
│   └── Design/                       # DesignSystem
├── Utilities/Helpers/               # HapticManager, UniformSmoother
├── Assets.xcassets/                  # 图标、启动图、强调色
├── docs/models.md                    # Core ML 模型接口文档
└── LiveCapture.xcodeproj
```

## License

MIT
