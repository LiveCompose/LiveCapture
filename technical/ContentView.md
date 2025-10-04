# ContentView

## 函数接口说明

### `body`
- 用途：构建主界面，组合取景预览、构图遮罩及控制按钮。
- 参数：无。
- 返回：`some View`，SwiftUI 视图树。

### `setupCallbacks()`
- 用途：注册摄像头回调，对每帧数据执行稳定性判断、Adacrop 推理和模板匹配。
- 参数：无。
- 返回：无。

### `detectCropOnce(using:orientation:)`
- 用途：调用 Adacrop 模型生成裁切框，并在成功后初始化模板匹配与陀螺仪参考。
- 参数：
  - `pixel`：裁剪到 3:4 的像素缓冲。
  - `orientation`：当前像素朝向。
- 返回：无（异步流程中更新状态）。

### `evaluateTemplateSimilarity(with:)`
- 用途：对当前帧执行模板匹配，根据相似度结果更新 UI 状态并触发拍照。
- 参数：`pixel` 为 3:4 像素缓冲。
- 返回：无。

### `rotateNormalizedRect(_:for:)`
- 用途：将 Vision 归一化坐标转换为预览坐标系，适配不同图像朝向。
- 参数：
  - `rect`：原始归一化矩形。
  - `orientation`：图像朝向。
- 返回：`CGRect`，转换后的矩形。

### `updateCompositionRectIfNeeded(_:)`
- 用途：记录 3:4 构图窗口的屏幕区域，并触发跟踪点位置更新。
- 参数：`rect` 为新的构图窗口。
- 返回：无。

### `updateBoxCenter(withNormalizedOffset:)`
- 用途：将陀螺仪归一化偏移映射成屏幕坐标，并限制在构图窗口内。
- 参数：`offset` 为归一化偏移量。
- 返回：无。

### `clamp(point:to:)`
- 用途：约束点坐标到指定矩形范围。
- 参数：
  - `point`：待约束的点。
  - `rect`：允许范围。
- 返回：`CGPoint`，裁剪后的点。

### `makeThreeByFourPixelBuffer(from:orientation:)`
- 用途：将原始像素按朝向旋正，并居中裁剪为 3:4 图像。
- 参数：
  - `pixelBuffer`：原始像素缓冲。
  - `orientation`：像素朝向。
- 返回：`CVPixelBuffer?`，成功时返回新的 3:4 像素缓冲。

### `pixelOrientation(for:)`
- 用途：根据像素宽高推断当前采集方向。
- 参数：`pixelBuffer` 为输入帧。
- 返回：`CGImagePropertyOrientation`。

### `resetDetectionState()`
- 用途：重置模板匹配与 Adacrop 状态，为下一次识别做准备。
- 参数：无。
- 返回：无。

### `rectInCompositionSpace(from:orientation:)`
- 用途：将归一化裁切框映射到当前构图窗口的屏幕坐标。
- 参数：
  - `rect`：归一化矩形。
  - `orientation`：图像朝向。
- 返回：`CGRect?`，映射后的矩形，若不相交则为 `nil`。

### `compositionRect(in:)`
- 用途：根据屏幕尺寸计算竖屏 3:4 构图窗口位置。
- 参数：`size` 为屏幕尺寸。
- 返回：`CGRect`，构图窗口。
