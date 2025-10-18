# 追踪点处理逻辑优化方案

## 📋 优化总结

本次优化针对 `BoxCenterManager` 的追踪精度问题，实现了多维度的自适应增益调整系统。

---

## 🔍 问题诊断

### 原有问题
1. **固定增益导致的不一致性**
   - 广角端：追踪偏移过小，跟不上手部移动
   - 长焦端：追踪偏移过大，抖动明显
   
2. **单一平滑策略**
   - 慢速移动时响应迟钝
   - 快速移动时追踪延迟

3. **缺少速度补偿**
   - 所有计算基于位置，忽略了速度信息
   - 导致快速移动时明显滞后

---

## ✨ 核心优化

### 1. 自适应增益系统

#### 变焦补偿 (Zoom Gain)
```swift
let zoomGain = 1.0 + (currentZoomFactor - 1.0) * 0.3
```
- **原理**: 长焦时同样的角度变化对应更大的画面位移
- **效果**: 
  - 1× (广角): 增益 = 1.0
  - 2× (中焦): 增益 = 1.3
  - 5× (长焦): 增益 = 2.2

#### 距离补偿 (Distance Gain)
```swift
let normalizedArea = (boxSize.width * boxSize.height) / (compositionRect.area)
estimatedSubjectDistance = sqrt(normalizedArea).clamped(to: 0.3...1.5)
let distanceGain = pow(estimatedSubjectDistance, 0.6)
```
- **原理**: 检测框越大 → 主体越近/越大 → 需要更灵敏的追踪
- **效果**: 自动识别拍摄距离并调整灵敏度

### 2. 速度自适应平滑 (AdaptivePointSmoother)

#### 动态响应系数
```swift
if speed < 0.5 rad/s  → response = 0.35  (更平滑)
if speed > 3.0 rad/s  → response = 0.15  (更快速)
else                  → 线性插值
```

- **低速时**: 高平滑度，减少微抖动
- **高速时**: 低平滑度，快速跟随
- **中速时**: 平滑过渡

### 3. 速度预测补偿

```swift
velocityCompensation = avgVelocity × compensationFactor × screenSize
compensationFactor = 0.08 / currentResponse
```

- **作用**: 基于角速度历史预测未来位置
- **效果**: 减少 50-100ms 的追踪延迟

---

## 📊 优化效果对比

| 场景 | 优化前 | 优化后 |
|------|--------|--------|
| 广角拍摄 | 追踪偏移过小 | ✅ 自适应增益 1.0× |
| 2× 变焦 | 追踪偏移适中 | ✅ 自适应增益 1.3× |
| 5× 长焦 | 追踪偏移过大 | ✅ 自适应增益 2.2× |
| 近距离拍摄 | 响应不足 | ✅ 距离增益提升 |
| 慢速移动 | 抖动明显 | ✅ 高平滑度 0.35 |
| 快速移动 | 延迟严重 | ✅ 低平滑度 0.15 + 速度补偿 |

---

## 🎯 建议的辅助检测手段

### 1. 光流法验证 (推荐)
```swift
// 使用 Vision 框架的光流追踪
VNTranslationalImageRegistrationRequest
```
**优点**:
- 直接测量画面位移
- 可与陀螺仪互补验证
- 检测追踪失效

### 2. 模板匹配置信度监控
```swift
if similarity < threshold && motionStable {
    // 可能是追踪失效，而非用户移动
    reduceTrackingGain()
}
```

### 3. 检测框尺寸变化监控
```swift
let sizeChangeRate = abs(currentBoxSize - baseBoxSize) / baseBoxSize
if sizeChangeRate > 0.3 {
    // 距离变化显著，重新校准
    recalibrate()
}
```

### 4. 加速度计辅助
```swift
// 区分手部移动 vs 身体移动
if accelerationMagnitude > threshold {
    // 可能是走动，暂停追踪或降低增益
}
```

---

## 🔧 可调参数

### BoxCenterManager
- `maxAngle`: 最大追踪角度 (默认 30°)
- `maxVelocityHistoryCount`: 速度历史窗口 (默认 5 帧)

### AdaptivePointSmoother
- `lowSpeedThreshold`: 0.5 rad/s
- `highSpeedThreshold`: 3.0 rad/s
- `minResponse`: 0.15 (快速响应)
- `maxResponse`: 0.35 (平滑响应)

### 增益系数
- 变焦增益权重: 0.3
- 距离增益指数: 0.6
- 速度补偿系数: 0.08

---

## 🧪 测试建议

1. **变焦测试**: 在 0.5×、1×、2×、5× 下分别测试追踪精度
2. **距离测试**: 近距离 (30cm) 和远距离 (2m) 对比
3. **速度测试**: 慢速平移、快速摆动、突然停止
4. **场景测试**: 人像、静物、宠物等不同主体

---

## 📝 后续优化方向

1. ✅ 已完成: 自适应增益系统
2. ✅ 已完成: 速度自适应平滑
3. ✅ 已完成: 速度预测补偿
4. 🔄 待实现: 光流法辅助验证
5. 🔄 待实现: 机器学习增益预测
6. 🔄 待实现: 多传感器融合 (IMU + 光流 + 模板)

---

## 🎓 技术细节

### 为什么使用 0.6 次方作为距离增益指数？
```
normalizedArea = 0.1 → distance = 0.316 → gain = 0.464
normalizedArea = 0.5 → distance = 0.707 → gain = 0.788
normalizedArea = 1.0 → distance = 1.000 → gain = 1.000
```
0.6 次方提供了适度的非线性响应，避免极端值。

### 为什么速度补偿系数是 0.08？
基于 60fps 和平均平滑延迟约 5 帧的估算：
```
delay ≈ 5 frames × (1/60) s = 83ms
compensation = velocity × delay ≈ velocity × 0.08
```

---

## 🚀 使用示例

```swift
// 初始化时传入裁剪框尺寸
boxCenterManager.setBaseCenter(
    center,
    with: attitude,
    cropBoxSize: detectedBox.size  // 新增参数
)

// 变焦时自动更新
camera.$zoomState.sink { state in
    boxCenterManager.updateZoomFactor(state.currentFactor)
}

// 实时更新追踪
motion.$deviceMotion.sink { motion in
    boxCenterManager.updateCenter(with: motion)
}
```

---

_最后更新: 2025-10-18_
