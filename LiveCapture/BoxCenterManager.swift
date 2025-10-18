//
//  BoxCenterManager.swift
//  LiveCapture
//

import Foundation
import Combine
import CoreGraphics
import CoreMotion
import simd

#if os(iOS)

/// 管理检测框中心点的状态与更新逻辑。
final class BoxCenterManager: ObservableObject {
	// MARK: - Published state

	/// 初始检测框在视图中的中心点。
	@Published private(set) var baseCenterInView: CGPoint?

	/// 根据设备位移调整后,当前检测框在视图中的中心点。
	@Published private(set) var currentCenterInView: CGPoint?

	// MARK: - Private state

	private var compositionRect: CGRect = .zero
	private var referenceAttitude: CMAttitude?
	private let maxAngle: Double = .pi / 6 // 30 degrees
	private var offsetSmoother = AdaptivePointSmoother(baseResponse: 0.25)
	
	// 新增: 自适应增益控制
	private var currentZoomFactor: CGFloat = 1.0
	private var estimatedSubjectDistance: CGFloat = 1.0 // 归一化距离估计
	
	// 新增: 速度相关状态
	private var lastAngularVelocity: CGPoint = .zero
	private var velocityHistory: [CGPoint] = []
	private let maxVelocityHistoryCount = 5
	
	// 新增: 检测框尺寸用于距离估计
	private var baseCropBoxSize: CGFloat = 0.0

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

	/// 设置并锁定初始的基准中心点,并记录当前姿态为参考。
	/// - Parameters:
	///   - center: 从图像中识别出的初始中心点。
	///   - attitude: 当前的设备姿态。
	///   - cropBoxSize: 检测到的裁剪框尺寸,用于估计拍摄距离。
	func setBaseCenter(_ center: CGPoint?, with attitude: CMAttitude?, cropBoxSize: CGSize? = nil) {
		baseCenterInView = center
		currentCenterInView = center
		referenceAttitude = attitude
		offsetSmoother.reset(to: CGPoint.zero)
		
		// 估计主体距离: 裁剪框越大,说明主体越近或越大
		if let size = cropBoxSize, compositionRect != .zero {
			let normalizedArea = (size.width * size.height) / (compositionRect.width * compositionRect.height)
			// 面积越大,距离越近,偏移增益应该更大
			estimatedSubjectDistance = sqrt(normalizedArea).clamped(to: 0.3...1.5)
			baseCropBoxSize = sqrt(size.width * size.height)
		} else {
			estimatedSubjectDistance = 1.0
			baseCropBoxSize = 0.0
		}
		
		velocityHistory.removeAll()
		lastAngularVelocity = .zero
	}

	/// 重置所有中心点状态。
	func reset() {
		baseCenterInView = nil
		currentCenterInView = nil
		referenceAttitude = nil
		offsetSmoother.reset()
		currentZoomFactor = 1.0
		estimatedSubjectDistance = 1.0
		velocityHistory.removeAll()
		lastAngularVelocity = .zero
		baseCropBoxSize = 0.0
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

		let offset = CGPoint(x: clampedRoll / maxAngle, y: clampedPitch / maxAngle)
		
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
	/// - Parameter offset: `MotionStabilityMonitor` 提供的归一化偏移。
	private func updateCenter(withNormalizedOffset offset: CGPoint) {
		guard let base = baseCenterInView, compositionRect != .zero else { return }
		
		// 🔥 自适应增益计算
		// 1. 基础增益: 根据构图区域大小
		let baseGainX = compositionRect.width * 0.4
		let baseGainY = compositionRect.height * 0.4
		
		// 2. 变焦补偿: 长焦时需要更大的追踪范围
		// 变焦倍率越大,同样的角度变化对应更大的画面位移
		let zoomGain = 1.0 + (currentZoomFactor - 1.0) * 0.3
		
		// 3. 距离补偿: 主体越近,追踪灵敏度应该越高
		let distanceGain = pow(estimatedSubjectDistance, 0.6)
		
		// 4. 综合增益
		let adaptiveGainX = baseGainX * zoomGain * distanceGain
		let adaptiveGainY = baseGainY * zoomGain * distanceGain
		
		// 5. 速度预测补偿(可选,用于减少延迟)
		let velocityCompensation = calculateVelocityCompensation()
		
		let target = CGPoint(
			x: base.x + offset.x * adaptiveGainX + velocityCompensation.x,
			y: base.y + offset.y * adaptiveGainY + velocityCompensation.y
		)
		
		currentCenterInView = clamp(point: target, to: compositionRect)
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
		
		// 速度补偿系数: 根据平滑器的响应时间估算延迟
		let compensationFactor: CGFloat = 0.08 * (1.0 / offsetSmoother.currentResponse)
		
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
	
	// 速度相关参数
	private let lowSpeedThreshold: Double = 0.5      // 低速阈值(rad/s)
	private let highSpeedThreshold: Double = 3.0     // 高速阈值(rad/s)
	private let minResponse: Double = 0.15           // 最小响应(快速追踪)
	private let maxResponse: Double = 0.35           // 最大响应(平滑追踪)

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