# CameraManager

## 函数接口说明

### `init()`
- 用途：配置会话预设、视频输出格式与回调队列。
- 参数：无。
- 返回：无。

### `checkAndConfigure(completion:)`
- 用途：检查相机授权并在获得权限后异步配置会话。
- 参数：`completion`，返回配置成功或失败原因的回调。
- 返回：无。

### `configureSessionAsync(completion:)`
- 用途：在串行队列中调用 `configureSession()`，避免阻塞主线程。
- 参数：`completion`，配置结果回调。
- 返回：无。

### `configureSession()`
- 用途：向 `AVCaptureSession` 添加视频输入、照片输出与视频数据输出，并应用稳定设置。
- 参数：无。
- 返回：无（抛出 `CameraError` 以指示失败原因）。

### `startSession()`
- 用途：异步启动捕获会话并在主线程更新状态。
- 参数：无。
- 返回：无。

### `stopSession()`
- 用途：异步停止捕获会话并在主线程更新状态。
- 参数：无。
- 返回：无。

### `capturePhoto()`
- 用途：创建照片捕获设置并触发拍照，包含高分辨率与防抖配置。
- 参数：无。
- 返回：无。

### `savePhotoDataToLibrary(_:)`
- 用途：请求照片库写入权限并保存 JPEG 数据到相册。
- 参数：`data` 为待存储的 JPEG 数据。
- 返回：无。

### `photoOutput(_:didFinishProcessingPhoto:error:)`
- 用途：处理拍照回调，生成 3:4 裁剪 JPEG 后保存；失败时回退到原始数据。
- 参数：
  - `output`：照片输出对象。
  - `photo`：捕获的照片样本。
  - `error`：处理错误。
- 返回：无。

### `captureOutput(_:didOutput:from:)`
- 用途：处理视频帧输出，缓存最新像素并触发实时回调。
- 参数：
  - `output`：视频数据输出。
  - `sampleBuffer`：当前帧。
  - `connection`：捕获连接。
- 返回：无。

### `processPhotoData(photo:originalData:)`
- 用途：将原始像素裁剪为 3:4 并编码为 JPEG，失败时返回 `nil`。
- 参数：
  - `photo`：AVCapturePhoto 实例。
  - `originalData`：原始 JPEG 数据备份。
- 返回：`Data?`，裁剪后的 JPEG 数据。

### `cropPixelBufferToThreeByFour(_:orientation:)`
- 用途：按给定朝向旋正像素，并居中裁剪为 3:4 像素缓冲。
- 参数：
  - `pixelBuffer`：原始像素。
  - `orientation`：图像朝向。
- 返回：`CVPixelBuffer?`，裁剪结果。

### `jpegData(from:)`
- 用途：将像素缓冲以 sRGB 空间编码为 JPEG 数据。
- 参数：`pixelBuffer` 为输入。
- 返回：`Data?`，编码成功的 JPEG。

### `photoOrientation(from:)`
- 用途：从照片元数据推断 CGImage 朝向，缺省时默认竖屏。
- 参数：`photo` 为捕获的照片。
- 返回：`CGImagePropertyOrientation`。
