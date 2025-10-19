//
//  BoxCenterManager.swift
//  LiveCapture
//
//  检测框中心点追踪管理器
//
//  ## 文件作用
//  管理智能构图的追踪点位置计算和更新
//  使用设备陀螺仪数据实现物理正确的旋转追踪模型
//  支持磁性吸附效果
//  支持前后摄像头
//
//  ## 追踪模型原理
//  基于物理的旋转模型，解决了传统"假设初始点在中心"的局限：
//  1. 记录初始检测框中心点的实际位置（可在屏幕任意位置）
//  2. 计算该点相对于屏幕中心的距离和方向
//  3. 根据设备旋转和距离计算位移（离中心越远位移越大）
//  4. 自适应调整：考虑变焦倍率和运动速度
//  5. 磁性吸附：接近中心时产生吸引力稳定构图
//
//  ## 主要类型
//
//  ### BoxCenterManager 类
//  检测框中心点管理器
//
//  ## Published 属性
//  - baseCenterInView: CGPoint? - 初始检测框在视图中的中心点
//  - currentCenterInView: CGPoint? - 应用磁性吸附后的当前中心点
//
//  ## 主要方法
//
//  ### 配置方法
//  - updateCompositionRect(_:): 更新构图区域尺寸
//    参数: rect - CGRect 构图区域
//
//  - updateZoomFactor(_:): 更新变焦倍率用于增益调整
//    参数: factor - CGFloat 变焦倍率 (0.5~5.0)
//
//  - setFrontCamera(_:): 设置是否为前置摄像头
//    参数: isFront - Bool 前置摄像头标志
//    功能: 保留用于未来可能的特殊处理
//
//  ### 追踪控制
//  - setBaseCenter(_:with:): 设置并锁定初始基准中心点
//    参数:
//      - center: CGPoint? 初始中心点位置
//      - attitude: CMAttitude? 当前设备姿态
//    功能:
//      - 记录基准位置
//      - 保存参考姿态
//      - 重置平滑器和速度历史
//
//  - reset(): 重置所有追踪状态
//    清空所有中心点、姿态和历史数据
//
//  - updateCenter(with:): 根据设备运动更新中心点
//    参数: motion - CMDeviceMotion? 最新运动数据
//    功能:
//      - 计算相对参考姿态的旋转角度
//      - 应用自适应平滑滤波
//      - 调用内部更新逻辑
//
//  ### 对齐检测
//  - isAlignedWithCenter(tolerance:): 检查是否对齐中心
//    参数: tolerance - CGFloat 对齐容差 (默认 5.0 points)
//    返回: Bool 是否在容差范围内
//    特性: 对齐持续超过 1s 后自动锁定到中心
//    注意: 使用未吸附的原始位置检测
//
//  - distanceToCenter(): 获取到中心的距离
//    返回: CGFloat? 距离值（points）
//
//  ### 内部实现
//  - updateCenter(withNormalizedOffset:): 根据归一化偏移更新位置
//    实现物理旋转模型的核心逻辑：
//      1. 计算基准点到屏幕中心的向量
//      2. 根据距离计算自适应增益
//      3. 应用变焦补偿
//      4. 速度预测减少延迟
//      5. 磁性吸附平滑对齐
//
//  - applyMagneticSnap(to:): 应用磁性吸附效果
//    参数: point - CGPoint 原始追踪点
//    返回: CGPoint 吸附后的点
//    特性:
//      - 距离 < 5pt: 完全吸附到中心
//      - 距离 5-25pt: 渐进非线性吸附
//      - 距离 > 25pt: 不吸附
//
//  - calculateVelocityCompensation(): 基于速度预测补偿延迟
//  - updateVelocityHistory(_:): 维护速度历史窗口
//  - clamp(point:to:): 限制点在矩形区域内
//
//  ## 辅助类型
//
//  ### AdaptivePointSmoother 结构体
//  自适应二维点平滑器
//  - 根据运动速度动态调整响应性
//  - 低速时更平滑（减少抖动）
//  - 高速时更快响应（减少延迟）
//  
//  方法:
//  - updateResponse(forSpeed:): 根据速度更新响应系数
//  - filter(_:): 应用指数平滑滤波
//  - reset(to:): 重置状态
//
//  ### UniformPointSmoother 结构体
//  统一响应点平滑器
//  - 固定响应系数的低通滤波
//  - 用于需要一致平滑度的场景
//
//  ## 性能优化
//  - 速度历史窗口限制为 5 帧
//  - 使用 SIMD 加速向量运算
//  - 平滑器参数经过调优平衡响应和稳定
//
//  ## 物理参数
//  - maxAngle: π/6 (30°) - 最大映射角度
//  - magneticThreshold: 25pt - 磁性吸附开始距离
//  - magneticStrength: 0.90 - 吸附强度系数
//  - snapThreshold: 5pt - 完全吸附距离
//

import Foundation
import Combine
import CoreGraphics
import CoreMotion
import simd

#if os(iOS)

/// 管理检测框中心点的状态与更新逻辑。
///
/// ## 追踪模型说明
/// 本管理器使用基于物理的旋转模型来计算追踪点位置：
///
/// 1. **基准点记录**：当用户按下追踪按钮时，记录当前检测框的中心点位置（可能在屏幕任意位置）
/// 2. **相对距离计算**：计算基准点相对于屏幕中心的距离和方向
/// 3. **距离相关增益**：离屏幕中心越远的点，相机旋转时产生的位移越大（物理正确）
/// 4. **自适应调整**：根据变焦倍率、主体距离、运动速度动态调整追踪灵敏度
/// 5. **磁性吸附**：当追踪点接近屏幕中心时，产生吸引力以稳定构图
///
/// 这个模型解决了之前"假设初始点在中心"的问题，现在无论初始点在哪里都能正确追踪。
final class BoxCenterManager: ObservableObject {
	// MARK: - Published state

	/// 初始检测框在视图中的中心点。
	@Published private(set) var baseCenterInView: CGPoint?

	/// 根据设备位移调整后,当前检测框在视图中的中心点(应用磁性吸附后)。
	@Published private(set) var currentCenterInView: CGPoint?

	// MARK: - Private state
	
	/// 未应用磁性吸附的实际追踪位置（用于准确的对齐检测）
	private var rawTrackingPosition: CGPoint?

	private var compositionRect: CGRect = .zero
	private var referenceAttitude: CMAttitude?
	private let maxAngle: Double = .pi / 6 // 30 degrees
	private var offsetSmoother = AdaptivePointSmoother(baseResponse: 0.20) // 🔥 平衡平滑度和响应速度
	
	// 新增: 自适应增益控制
	private var currentZoomFactor: CGFloat = 1.0
	
	// 🔥 前置摄像头支持
	private var isFrontCamera: Bool = false
	
	// 新增: 速度相关状态
	private var lastAngularVelocity: CGPoint = .zero
	private var velocityHistory: [CGPoint] = []
	private let maxVelocityHistoryCount = 5
	
	// 🔥 新增: 磁性吸附参数
	private let magneticThreshold: CGFloat = 25.0     // 吸附开始的距离阈值(points) - 25 开始吸附
	private let magneticStrength: CGFloat = 0.90      // 吸附强度系数 [0,1] - 强力吸附
	private let snapThreshold: CGFloat = 5.0          // 完全吸附的距离阈值(points) - 与拍照容差一致
	
	// 🔥 新增: 对齐持续时间追踪
	private var alignedStartTime: Date?               // 对齐开始的时间
	private let lockDuration: TimeInterval = 1.0      // 锁定前需要保持对齐的时长(秒)
	private var isLockedToCenter: Bool = false        // 是否已锁定到中心

	// MARK: - Public methods

	/// 更新构图区域的尺寸,用于后续的中心点偏移计算与限制。
	/// - Parameter rect: 最新的构图区域。
	func updateCompositionRect(_ rect: CGRect) {
		compositionRect = rect
	}
	
	/// 更新当前的变焦倍率,用于自适应增益调整。
	/// - Parameter factor: 当前变焦倍率(例如 1.0, 2.0, 5.0)。
	func updateZoomFactor(_ factor: CGFloat) {
		currentZoomFactor = max(0.5, factor)
	}
	
	/// 设置当前是否为前置摄像头（用于陀螺仪读数翻转）。
	/// - Parameter isFront: 是否为前置摄像头。
	func setFrontCamera(_ isFront: Bool) {
		isFrontCamera = isFront
	}

	/// 设置并锁定初始的基准中心点,并记录当前姿态为参考。
	/// - Parameters:
	///   - center: 从图像中识别出的初始中心点。
	///   - attitude: 当前的设备姿态。
	func setBaseCenter(_ center: CGPoint?, with attitude: CMAttitude?) {
		baseCenterInView = center
		currentCenterInView = center
		referenceAttitude = attitude
		offsetSmoother.reset(to: CGPoint.zero)
		
		velocityHistory.removeAll()
		lastAngularVelocity = .zero
	}

	/// 重置所有中心点状态。
	func reset() {
		baseCenterInView = nil
		currentCenterInView = nil
		rawTrackingPosition = nil
		referenceAttitude = nil
		offsetSmoother.reset()
		currentZoomFactor = 1.0
		velocityHistory.removeAll()
		lastAngularVelocity = .zero
		alignedStartTime = nil
		isLockedToCenter = false
	}

	/// 根据最新的设备姿态计算并更新中心点。
	/// - Parameter motion: 最新的 `CMDeviceMotion` 数据。
	func updateCenter(with motion: CMDeviceMotion?) {
		guard let motion, let referenceAttitude else { return }

		let currentAttitude = motion.attitude
		currentAttitude.multiply(byInverseOf: referenceAttitude)

		let deltaPitch = currentAttitude.pitch
		let deltaRoll = currentAttitude.roll

		let clampedPitch = max(-maxAngle, min(maxAngle, deltaPitch))
		let clampedRoll = max(-maxAngle, min(maxAngle, deltaRoll))

		// 🔥 前置摄像头时不翻转读数（预览层翻转不影响追踪逻辑）
		let rollForOffset = clampedRoll
		let pitchForOffset = isFrontCamera ? -clampedPitch : clampedPitch
		let offset = CGPoint(x: rollForOffset / maxAngle, y: pitchForOffset / maxAngle)
		
		// 计算角速度用于动态平滑
		let rotationRate = motion.rotationRate
		let angularVelocity = CGPoint(x: CGFloat(rotationRate.y), y: CGFloat(rotationRate.x))
		updateVelocityHistory(angularVelocity)
		
		// 根据速度调整平滑器响应性
		let speed = sqrt(angularVelocity.x * angularVelocity.x + angularVelocity.y * angularVelocity.y)
		offsetSmoother.updateResponse(forSpeed: speed)
		
		let smoothed = offsetSmoother.filter(offset)
		updateCenter(withNormalizedOffset: smoothed)
		
		lastAngularVelocity = angularVelocity
	}

	/// 根据归一化的屏幕偏移量更新当前中心点。
	/// - Parameter offset: 归一化的角度偏移量 [-1, 1]，基于 maxAngle 归一化。
	private func updateCenter(withNormalizedOffset offset: CGPoint) {
		guard let base = baseCenterInView, compositionRect != .zero else { return }
		
		let screenCenter = CGPoint(x: compositionRect.midX, y: compositionRect.midY)
		
		// 🔥 如果已锁定到中心，直接设置为中心点
		if isLockedToCenter {
			rawTrackingPosition = screenCenter
			currentCenterInView = screenCenter
			return
		}
		
		// 🔥 基于物理的旋转模型
		// 相机旋转时，画面中的点会围绕画面中心旋转
		// 离中心越远的点，相同角度产生的位移越大
		
		// 1. 计算基准点相对于屏幕中心的向量
		let baseVector = CGPoint(
			x: base.x - screenCenter.x,
			y: base.y - screenCenter.y
		)
		
		// 2. 计算基准点到中心的距离（归一化到屏幕尺寸）
		let screenRadius = sqrt(pow(compositionRect.width / 2, 2) + pow(compositionRect.height / 2, 2))
		let distanceToCenter = sqrt(baseVector.x * baseVector.x + baseVector.y * baseVector.y)
		let normalizedDistance = distanceToCenter / screenRadius
		
		// 3. 自适应增益计算
		// 基础增益: 根据构图区域大小和位置
		let baseGainX = compositionRect.width * 0.55
		let baseGainY = compositionRect.height * 0.55
		
		// 距离增益: 离中心越远，旋转产生的位移越大（物理正确）
		// 使用线性关系，但添加最小增益保证中心附近也有响应
		let distanceGain = 0.6 + normalizedDistance * 0.8 // [0.6, 1.4]
		
		// 变焦补偿: 长焦时视角变窄，同样角度对应更大的画面位移
		let zoomGain = 1.0 + (currentZoomFactor - 1.0) * 0.35
		
		// 综合增益（移除主体距离增益）
		let adaptiveGainX = baseGainX * distanceGain * zoomGain
		let adaptiveGainY = baseGainY * distanceGain * zoomGain
		
		// 4. 计算偏移量
		let displacement = CGPoint(
			x: offset.x * adaptiveGainX,
			y: offset.y * adaptiveGainY
		)
		
		// 5. 速度预测补偿（减少延迟）
		let velocityCompensation = calculateVelocityCompensation()
		
		// 6. 应用偏移到基准点
		let rawTarget = CGPoint(
			x: base.x + displacement.x + velocityCompensation.x,
			y: base.y + displacement.y + velocityCompensation.y
		)
		
		// 7. 保存未吸附的原始位置（用于准确的对齐检测）
		rawTrackingPosition = clamp(point: rawTarget, to: compositionRect)
		
		// 8. 应用磁性吸附效果（当接近中心时）
		let snappedTarget = applyMagneticSnap(to: rawTarget)
		
		// 9. 限制在构图区域内并更新显示位置
		currentCenterInView = clamp(point: snappedTarget, to: compositionRect)
	}
	
	/// 应用磁性吸附效果,当追踪点接近中心时产生吸引力。
	/// - Parameter point: 原始追踪点位置。
	/// - Returns: 应用吸附后的点位置。
	private func applyMagneticSnap(to point: CGPoint) -> CGPoint {
		guard compositionRect != .zero else { return point }
		
		let centerPoint = CGPoint(x: compositionRect.midX, y: compositionRect.midY)
		let dx = point.x - centerPoint.x
		let dy = point.y - centerPoint.y
		let distance = sqrt(dx * dx + dy * dy)
		
		// 如果距离小于完全吸附阈值,直接吸附到中心
		if distance < snapThreshold {
			return centerPoint
		}
		
		// 如果距离在磁性范围内,应用渐进非线性吸附
		if distance < magneticThreshold {
			// 计算归一化距离: 0 = 最近(snapThreshold), 1 = 最远(magneticThreshold)
			let normalized = ((distance - snapThreshold) / (magneticThreshold - snapThreshold)).clamped(to: 0.0...1.0)
			
			// 🔥 使用指数衰减曲线: 越接近中心,吸附力越强 (加速吸附)
			// pow(1-x, 0.5) 创建一个凹函数,让最后阶段加速
			let easeFactor = 1.0 - pow(normalized, 0.5)
			let attractionStrength = easeFactor * magneticStrength
			
			let attractedX = point.x - dx * attractionStrength
			let attractedY = point.y - dy * attractionStrength
			
			return CGPoint(x: attractedX, y: attractedY)
		}
		
		// 距离太远,不应用吸附
		return point
	}
	
	/// 计算基于速度的预测补偿,减少追踪延迟。
	private func calculateVelocityCompensation() -> CGPoint {
		guard velocityHistory.count >= 3 else { return .zero }
		
		// 计算平均角速度
		let avgVelocity = velocityHistory.reduce(CGPoint.zero) { 
			CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
		}
		let count = CGFloat(velocityHistory.count)
		let normalizedVelocity = CGPoint(x: avgVelocity.x / count, y: avgVelocity.y / count)
		
		// 速度补偿系数: 根据平滑器的响应时间估算延迟 (降低系数减少抖动)
		let compensationFactor: CGFloat = 0.04 * (1.0 / offsetSmoother.currentResponse)
		
		return CGPoint(
			x: normalizedVelocity.x * compensationFactor * compositionRect.width,
			y: normalizedVelocity.y * compensationFactor * compositionRect.height
		)
	}
	
	/// 更新速度历史记录。
	private func updateVelocityHistory(_ velocity: CGPoint) {
		velocityHistory.append(velocity)
		if velocityHistory.count > maxVelocityHistoryCount {
			velocityHistory.removeFirst()
		}
	}

	// MARK: - Private helpers

	/// 将一个点限制在给定的矩形区域内。
	private func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
		CGPoint(x: min(max(point.x, rect.minX), rect.maxX),
				y: min(max(point.y, rect.minY), rect.maxY))
	}
	
	// MARK: - Public alignment check
	
	/// 检查当前追踪点是否与屏幕中心对齐。
	/// - Parameter tolerance: 对齐容差(points),默认为 5.0。
	/// - Returns: 如果追踪点在容差范围内,返回 true。
	/// - Note: 使用未吸附的原始位置进行检测，避免磁性吸附导致的提前触发。
	///        当对齐持续超过 1s 后，会自动锁定追踪点到中心。
	func isAlignedWithCenter(tolerance: CGFloat = 5.0) -> Bool {
		// 使用原始位置而不是吸附后的位置
		guard let rawPosition = rawTrackingPosition, compositionRect != .zero else {
			alignedStartTime = nil
			return false
		}
		
		let centerPoint = CGPoint(x: compositionRect.midX, y: compositionRect.midY)
		let dx = rawPosition.x - centerPoint.x
		let dy = rawPosition.y - centerPoint.y
		let distance = sqrt(dx * dx + dy * dy)
		
		let isAligned = distance <= tolerance
		
		// 🔥 追踪对齐持续时间
		if isAligned {
			if alignedStartTime == nil {
				// 刚开始对齐
				alignedStartTime = Date()
			} else if let startTime = alignedStartTime {
				// 检查是否持续对齐超过锁定时长
				let duration = Date().timeIntervalSince(startTime)
				if duration >= lockDuration && !isLockedToCenter {
					isLockedToCenter = true
				}
			}
		} else {
			// 失去对齐，重置状态
			alignedStartTime = nil
			isLockedToCenter = false
		}
		
		return isAligned
	}
	
	/// 获取当前追踪点与中心的距离。
	/// - Returns: 距离值(points),如果追踪点不存在则返回 nil。
	/// - Note: 使用未吸附的原始位置进行计算，反映真实距离。
	func distanceToCenter() -> CGFloat? {
		// 使用原始位置而不是吸附后的位置
		guard let rawPosition = rawTrackingPosition, compositionRect != .zero else {
			return nil
		}
		
		let centerPoint = CGPoint(x: compositionRect.midX, y: compositionRect.midY)
		let dx = rawPosition.x - centerPoint.x
		let dy = rawPosition.y - centerPoint.y
		
		return sqrt(dx * dx + dy * dy)
	}
}

// MARK: - 扩展: CGFloat辅助方法

extension CGFloat {
	/// 将值限制在指定范围内。
	func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
		Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
	}
}

/// 🔥 自适应二维点平滑器 - 根据运动速度动态调整响应性。
struct AdaptivePointSmoother {
	private let baseResponse: Double
	private(set) var currentResponse: Double
	private var previous: SIMD2<Double>?
	
	// 🔥 优化速度相关参数,提供更好的平滑度
	private let lowSpeedThreshold: Double = 0.15     // 低速阈值(rad/s) - 提高以减少对微小抖动的响应
	private let highSpeedThreshold: Double = 3.0     // 高速阈值(rad/s) - 降低快速响应阈值
	private let minResponse: Double = 0.12           // 最小响应(快速追踪) - 降低让磁吸更快
	private let maxResponse: Double = 0.22           // 最大响应(平滑追踪) - 平衡平滑度和响应性

	/// 使用指定的基础响应系数初始化平滑器。
	init(baseResponse: Double) {
		self.baseResponse = AdaptivePointSmoother.clamped(baseResponse)
		self.currentResponse = self.baseResponse
	}
	
	/// 根据运动速度更新响应系数。
	mutating func updateResponse(forSpeed speed: CGFloat) {
		let speedValue = Double(speed)
		
		if speedValue < lowSpeedThreshold {
			// 低速: 使用较大响应,更平滑
			currentResponse = maxResponse
		} else if speedValue > highSpeedThreshold {
			// 高速: 使用较小响应,更快响应
			currentResponse = minResponse
		} else {
			// 中速: 线性插值
			let t = (speedValue - lowSpeedThreshold) / (highSpeedThreshold - lowSpeedThreshold)
			currentResponse = maxResponse - t * (maxResponse - minResponse)
		}
	}

	/// 对输入点应用自适应指数平滑,返回滤波后的结果。
	mutating func filter(_ point: CGPoint) -> CGPoint {
		let current = SIMD2<Double>(Double(point.x), Double(point.y))
		guard let prev = previous else {
			previous = current
			return point
		}
		let t = SIMD2<Double>(repeating: currentResponse)
		let filtered = simd_mix(prev, current, t)
		previous = filtered
		return CGPoint(x: CGFloat(filtered.x), y: CGFloat(filtered.y))
	}

	/// 重置内部状态,可选地指定初始值。
	mutating func reset(to point: CGPoint? = nil) {
		if let point {
			previous = SIMD2<Double>(Double(point.x), Double(point.y))
		} else {
			previous = nil
		}
		currentResponse = baseResponse
	}

	/// 将响应值约束在 [0,1] 范围内。
	private static func clamped(_ value: Double) -> Double {
		min(1.0, max(0.0, value))
	}
}

/// 针对二维点的统一响应低通滤波器。
struct UniformPointSmoother {
	private let response: Double
	private var previous: SIMD2<Double>?

	/// 使用指定的响应系数初始化平滑器。
	init(response: Double) {
		self.response = UniformPointSmoother.clamped(response)
	}

	/// 对输入点应用指数平滑，返回滤波后的结果。
	mutating func filter(_ point: CGPoint) -> CGPoint {
		let current = SIMD2<Double>(Double(point.x), Double(point.y))
		guard let prev = previous else {
			previous = current
			return point
		}
		let t = SIMD2<Double>(repeating: response)
		let filtered = simd_mix(prev, current, t)
		previous = filtered
		return CGPoint(x: CGFloat(filtered.x), y: CGFloat(filtered.y))
	}

	/// 重置内部状态，可选地指定初始值。
	mutating func reset(to point: CGPoint? = nil) {
		if let point {
			previous = SIMD2<Double>(Double(point.x), Double(point.y))
		} else {
			previous = nil
		}
	}

	/// 将响应值约束在 [0,1] 范围内。
	private static func clamped(_ value: Double) -> Double {
		min(1.0, max(0.0, value))
	}
}
#endif