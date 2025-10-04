# TemplateMatcher

## 函数接口说明

### `resetTemplate()`
- 用途：清空当前模板向量与调试快照。
- 参数：无。
- 返回：无。

### `setTemplate(from:normalizedRegion:)`
- 用途：同步接口，基于归一化矩形提取模板后保存向量。
- 参数：
  - `pixelBuffer`：来源像素缓冲。
  - `normalizedRegion`：Vision 归一化区域。
- 返回：无。

### `setTemplate(from:normalizedRegion:completion:)`
- 用途：异步提取模板并返回处理结果，完成回调在主线程触发。
- 参数同上，另含 `completion` 闭包返回布尔结果。
- 返回：无。

### `similarityWithCenter(of:)`
- 用途：对当前帧中心区域执行模板匹配并返回归一化相似度。
- 参数：`pixelBuffer` 为输入帧。
- 返回：`Float?`，相似度（0–1），模板缺失时为 `nil`。

### `templateCGImage()`
- 用途：获取最近一次模板截取的 `CGImage`，供调试使用。
- 参数：无。
- 返回：`CGImage?`。

### `centerCGImage(from:)`
- 用途：提取当前帧中心区域的 `CGImage`，用于调试。
- 参数：`pixelBuffer`。
- 返回：`CGImage?`。

### `templateUIImage()`
- 用途：在 UIKit 可用时返回模板的 `UIImage` 快照。
- 参数：无。
- 返回：`UIImage?`。

### `centerUIImage(from:)`
- 用途：在 UIKit 可用时返回中心区域的 `UIImage`。
- 参数：`pixelBuffer`。
- 返回：`UIImage?`。

### `compositionRect3x4InPixels(pixelBuffer:)`
- 用途：计算像素缓冲内部居中的 3:4 矩形，以匹配照片构图范围。
- 参数：`pixelBuffer`。
- 返回：`CGRect`。

### `centerSquare(in:pixelBuffer:scale:)`
- 用途：以归一化裁切框为基础，生成受 3:4 约束的方形模板区域。
- 参数：
  - `normalizedRegion`：Vision 归一化区域。
  - `pixelBuffer`：输入像素。
  - `scale`：模板尺寸比例。
- 返回：`CGRect`，像素坐标系下的方形。

### `centerSquareInFullFrame(pixelBuffer:)`
- 用途：基于整张图像（限定于 3:4 区域）生成模板匹配使用的中心方块。
- 参数：`pixelBuffer`。
- 返回：`CGRect`。

### `extractCGImage(from:cropping:)`
- 用途：从像素缓冲中裁出指定区域并缩放到固定尺寸的 `CGImage`。
- 参数：
  - `pixelBuffer`：来源像素。
  - `cropRect`：像素坐标系裁剪矩形。
- 返回：`CGImage?`。

### `imageToVector(_:)`
- 用途：将 `CGImage` 转换为灰度向量表示，便于后续相似度计算。
- 参数：`image`。
- 返回：`[Float]?`，灰度数组。

### `normalizeVector(_:)`
- 用途：对向量执行零均值、单位方差标准化。
- 参数：`v` 为输入向量。
- 返回：`[Float]`，标准化后的向量。

### `cosineSimilarity(_:_)`
- 用途：计算两个等长向量的余弦相似度。
- 参数：`a`、`b` 分别为输入向量。
- 返回：`Float`，范围 [-1, 1]。
