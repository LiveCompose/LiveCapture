//
//  BoxCenterManager.swift
//  LiveCapture
//

import Foundation
import Combine
import CoreGraphics
import CoreMotion
import simd

/// 管理检测框中心点的状态与更新逻辑。
final class BoxCenterManager: ObservableObject {
	// MARK: - Published state

	/// 初始检测框在视图中的中心点。
	@Published private(set) var baseCenterInView: CGPoint?

	/// 根据设备位移调整后，当前检测框在视图中的中心点。
	@Published private(set) var currentCenterInView: CGPoint?

	// MARK: - Private state

	private var compositionRect: CGRect = .zero
	private var referenceAttitude: CMAttitude?
	private let maxAngle: Double = .pi / 6 // 30 degrees
	private var offsetSmoother = UniformPointSmoother(response: 0.25)

	// MARK: - Public methods

	/// 更新构图区域的尺寸，用于后续的中心点偏移计算与限制。
	/// - Parameter rect: 最新的构图区域。
	func updateCompositionRect(_ rect: CGRect) {
		compositionRect = rect
	}

	/// 设置并锁定初始的基准中心点，并记录当前姿态为参考。
	/// - Parameters:
	///   - center: 从图像中识别出的初始中心点。
	///   - attitude: 当前的设备姿态。
	func setBaseCenter(_ center: CGPoint?, with attitude: CMAttitude?) {
		baseCenterInView = center
		currentCenterInView = center
		referenceAttitude = attitude
		offsetSmoother.reset(to: CGPoint.zero)
	}

	/// 重置所有中心点状态。
	func reset() {
		baseCenterInView = nil
		currentCenterInView = nil
		referenceAttitude = nil
		offsetSmoother.reset()
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
		let smoothed = offsetSmoother.filter(offset)

		updateCenter(withNormalizedOffset: smoothed)
	}

	/// 根据归一化的屏幕偏移量更新当前中心点。
	/// - Parameter offset: `MotionStabilityMonitor` 提供的归一化偏移。
	private func updateCenter(withNormalizedOffset offset: CGPoint) {
		guard let base = baseCenterInView, compositionRect != .zero else { return }
		let maxOffsetX = compositionRect.width * 0.4
		let maxOffsetY = compositionRect.height * 0.4
		let target = CGPoint(x: base.x + offset.x * maxOffsetX,
							 y: base.y + offset.y * maxOffsetY)
		currentCenterInView = clamp(point: target, to: compositionRect)
	}

	// MARK: - Private helpers

	/// 将一个点限制在给定的矩形区域内。
	private func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
		CGPoint(x: min(max(point.x, rect.minX), rect.maxX),
				y: min(max(point.y, rect.minY), rect.maxY))
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
