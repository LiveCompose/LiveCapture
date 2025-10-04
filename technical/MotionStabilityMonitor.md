# MotionStabilityMonitor

## 函数接口说明（iOS）

### `start()`
- 用途：启动加速度计、陀螺仪与姿态更新，并在串行队列中收集样本。
- 参数：无。
- 返回：无。

### `stop()`
- 用途：停止所有传感器更新并重置内部状态与公开属性。
- 参数：无。
- 返回：无。

### `lockReferenceAttitude()`
- 用途：记录当前俯仰/横滚角作为 2D 偏移的零点，并重置平滑器。
- 参数：无。
- 返回：无。

### `resetReferenceAttitude()`
- 用途：清除参考姿态，偏移归零，为下一次对齐做准备。
- 参数：无。
- 返回：无。

### `updateScreenOffset(with:)`
- 用途：将最新姿态转换成屏幕归一化偏移并应用平滑。
- 参数：`data` 为 `CMDeviceMotion` 样本。
- 返回：无。

### `appendAccSample(_:)`
- 用途：记录新的加速度样本并裁剪时间窗口。
- 参数：`v` 为 `CMAcceleration`。
- 返回：无。

### `appendGyroSample(_:)`
- 用途：记录新的角速度样本并裁剪时间窗口。
- 参数：`v` 为 `CMRotationRate`。
- 返回：无。

### `trim(_:now:)`
- 用途：移除时间窗口之前的旧样本，保持滑动窗口长度。
- 参数：
  - `arr`：样本数组（`inout`）。
  - `now`：当前时间戳。
- 返回：无。

### `updateStabilityIfNeeded()`
- 用途：限流调用 `updateStability()`，避免过高频率计算。
- 参数：无。
- 返回：无。

### `updateStability()`
- 用途：基于当前样本计算加速度与陀螺仪标准差，更新稳定性状态与调试信息。
- 参数：无。
- 返回：无。

## 函数接口说明（非 iOS 平台）

### `start()`
- 用途：占位实现，保持接口一致。
- 参数：无。
- 返回：无。

### `stop()`
- 用途：标记监控停止并重置 `isStable`。
- 参数：无。
- 返回：无。
