//
//  ZoomRingView.swift
//  LiveCapture
//
//  Created by Codex on 2025/03/17.
//

import SwiftUI

#if os(iOS)

/// 半圆形变焦环控件，提供预设切换与连续变焦拖动。
struct ZoomRingView: View {
	/// 控件的外部配置项集合。
	struct Configuration {
		let presets: [CameraManager.ZoomPreset]
		let range: ClosedRange<CGFloat>
		let state: CameraManager.ZoomState
		let onPresetTap: (CameraManager.ZoomPreset) -> Void
		let onDragChanged: (CGFloat) -> Void
		let onDragEnded: (CGFloat) -> Void
	}

	private let config: Configuration
	@State private var isDragging = false

	/// 使用给定配置初始化控件。
	init(config: Configuration) {
		self.config = config
	}

	private var displayFactorText: String {
		let factor = config.state.displayedFactor
		if abs(Double(factor.rounded()) - Double(factor)) < 0.0009 {
			return "\(Int(factor.rounded()))×"
		}
		return String(format: "%.2f×", factor)
	}

	private var focalLengthText: String {
		"\(config.state.focalLength)mm"
	}

	/// 构建半圆控制的整体视图层次。
	var body: some View {
		GeometryReader { proxy in
			let metrics = Metrics(proxy: proxy, range: config.range)
			let indicatorPoint = metrics.point(for: config.state.displayedFactor)

			ZStack {
				presetButtons(using: metrics)
			}
			.contentShape(Rectangle())
		}
	}
}

private extension ZoomRingView {
	/// 渲染所有离散变焦预设按钮。
	func presetButtons(using metrics: Metrics) -> some View {
		ForEach(config.presets) { preset in
			let point = metrics.point(for: preset.zoomFactor)
			let isActive = abs(preset.zoomFactor - config.state.currentFactor) < 0.05
			let style = preset.style

			Button {
				config.onPresetTap(preset)
			} label: {
				Text(preset.label)
					.font(.system(size: style == .primary ? 16 : 14, weight: .semibold))
					.padding(.vertical, style == .primary ? 10 : 8)
					.padding(.horizontal, style == .primary ? 18 : 12)
					.background(
						Capsule()
							.fill(isActive ? Color.orange : Color.white.opacity(0.18))
					)
					.overlay(
						Capsule()
							.stroke(Color.white.opacity(isActive ? 0.0 : 0.4), lineWidth: 1)
					)
					.foregroundStyle(isActive ? Color.black : Color.white)
			}
			.position(point)
			.animation(.easeInOut(duration: 0.15), value: isActive)
		}
	}
}

private extension ZoomRingView {
	struct Metrics {
		let proxy: GeometryProxy
		let range: ClosedRange<CGFloat>
		let trackWidth: CGFloat = 44

		var center: CGPoint {
			CGPoint(x: proxy.size.width * 0.5,
					y: proxy.size.height - trackWidth * 0.4)
		}

		var radius: CGFloat {
			let maxRadius = min(proxy.size.width * 0.5, proxy.size.height * 0.95)
			return max(maxRadius - trackWidth * 0.2, trackWidth)
		}

		func progress(for factor: CGFloat) -> Double {
			let clamped = min(max(factor, range.lowerBound), range.upperBound)
			let span = range.upperBound - range.lowerBound
			guard span > .ulpOfOne else { return 0.0 }
			let normalized = (clamped - range.lowerBound) / span
			return Double(normalized)
		}

		func angle(for factor: CGFloat) -> Double {
			.pi * (1.0 - progress(for: factor))
		}

		func point(for factor: CGFloat) -> CGPoint {
			let angle = angle(for: factor)
			let r = radius - trackWidth * 0.5
			let x = center.x + CGFloat(cos(angle)) * r
			let y = center.y - CGFloat(sin(angle)) * r
			return CGPoint(x: x, y: y)
		}

		func factor(for location: CGPoint) -> CGFloat {
			let span = range.upperBound - range.lowerBound
			guard span > .ulpOfOne else { return range.lowerBound }
			let dx = location.x - center.x
			let dy = center.y - location.y
			let rawAngle = atan2(dy, dx)
			let clampedAngle = max(0.0, min(Double.pi, Double(rawAngle)))
			let progress = 1.0 - (clampedAngle / Double.pi)
			let value = Double(range.lowerBound) + progress * Double(span)
			return CGFloat(value)
		}
	}
}

#endif
