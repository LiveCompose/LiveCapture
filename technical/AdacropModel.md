# AdacropModel

## 函数接口说明

### `init()`
- 用途：初始化裁切模型相关资源与滤波器队列。
- 参数：无。
- 返回：无。

### `resetSmoothing()`
- 用途：清空平滑器状态并丢弃上一次的原始检测框。
- 参数：无。
- 返回：无。

### `predictCropBox(pixelBuffer:orientation:completion:)`
- 用途：对输入帧执行人脸/人体/显著性检测，计算最优 3:4 构图框并输出平滑后的结果。
- 参数：
  - `pixelBuffer`：待分析的摄像头帧。
  - `orientation`：像素在 Vision 坐标系中的朝向。
  - `completion`：异步回调，返回 `CropBox?`。
- 返回：无（结果在回调中返回）。

### `makeVisionContext(pixelBuffer:orientation:)`
- 用途：运行 Vision 请求，生成包含人脸、人体、显著性候选的上下文数据。
- 参数：
  - `pixelBuffer`：输入像素缓冲。
  - `orientation`：图像朝向。
- 返回：`VisionContext`，封装了检测结果及原始显著性观察。

### `selectBestCandidate(in:)`
- 用途：遍历候选裁切框，计算综合评分并挑选最高得分方案。
- 参数：`context` 表示 Vision 检测上下文。
- 返回：`EvaluatedCandidate?`，为最佳裁切框及评分，若无候选则返回 `nil`。

### `generateCandidates(for:)`
- 用途：根据人脸、人体、显著性、历史记录与默认设置生成一系列 3:4 候选框。
- 参数：`context` 表示 Vision 检测上下文。
- 返回：`[Candidate]`，候选裁切框列表。

### `subjectScore(for:context:)`
- 用途：衡量候选框覆盖主要主体（人脸/人体/显著区域）的程度。
- 参数：
  - `rect`：候选框。
  - `context`：Vision 检测上下文。
- 返回：`CGFloat`，主体匹配度评分（0–1）。

### `saliencyScore(for:context:)`
- 用途：根据显著性结果估计候选框视觉吸引力得分。
- 参数与返回：同上。

### `breathingScore(of:)`
- 用途：评估候选框四周的留白空间，避免裁得过紧。
- 参数：`rect` 为候选框。
- 返回：`CGFloat`，留白得分（0–1）。

### `continuityScore(for:)`
- 用途：比较当前候选框与上一次结果的差异，鼓励连续帧平滑过渡。
- 参数：`rect` 为候选框。
- 返回：`CGFloat`，连续性得分（0–1）。

### `weightedCoverage(of:with:)`
- 用途：计算候选框与带置信度权重的检测框之间的覆盖率。
- 参数：
  - `rect`：候选框。
  - `items`：`WeightedRect` 集合。
- 返回：`CGFloat`，裁切覆盖率（0–1）。

### `expandNormalized(_:margin:)`
- 用途：在归一化坐标系中对矩形按比例扩张，并限制在单位方形内。
- 参数：
  - `rect`：基准矩形。
  - `margin`：按宽高比例扩张的边距。
- 返回：`CGRect`，扩张后的矩形。

### `unionRect(_:)`
- 用途：合并多个矩形得到并集框。
- 参数：`rects` 为矩形数组。
- 返回：`CGRect?`，若数组为空则返回 `nil`。

### `expandToAspect3x4(covering:)`
- 用途：扩展矩形以覆盖原区域并强制保持 3:4 比例，必要时做平移/缩放以适配单位空间。
- 参数：`rect` 为基准矩形。
- 返回：`CGRect`，3:4 比例矩形。

### `clampToUnit(_:inside:)`
- 用途：将矩形限制在给定单位区域内。
- 参数：
  - `r`：需限制的矩形。
  - `unit`：目标区域。
- 返回：`CGRect`，裁剪后的矩形。

### `moveRect(_:centerToward:maxShift:)`
- 用途：将矩形中心向目标点平移，平移量受限并保持在单位区域内。
- 参数：
  - `r`：原始矩形。
  - `target`：目标中心点。
  - `maxShift`：允许的最大平移距离。
- 返回：`CGRect`，平移后的矩形。

### `scaleRect(_:scale:)`
- 用途：按指定比例缩放矩形并保持中心位置，结果限制在单位区域内。
- 参数：
  - `r`：原始矩形。
  - `scale`：缩放比例。
- 返回：`CGRect`，缩放后的矩形。

### `thirdsFit(of:)`
- 用途：测量矩形中心距离九宫格交点的距离，用于三分法评分。
- 参数：`r` 为候选矩形。
- 返回：`CGFloat`，三分对齐得分（0–1）。

### `centerRect3x4()`
- 用途：返回默认的居中 3:4 裁切框。
- 参数：无。
- 返回：`CGRect`，预设裁切框。
