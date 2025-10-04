# CompositionOverlayView

## 函数接口说明

### `body`
- 用途：绘制 3:4 构图遮罩、三分线、中心指示及裁切框/跟踪点。
- 参数：无。
- 返回：`some View`，SwiftUI 视图内容。

### `clampedPoint(_:in:)`
- 用途：将可选坐标限制在给定构图矩形内，保证绘制安全。
- 参数：
  - `point`：待约束的点，可为 `nil`。
  - `rect`：允许范围。
- 返回：`CGPoint?`，若输入存在则返回裁剪后的点。
