//
//  ContentOverlayView.swift
//  LiveCapture
//

import SwiftUI

#if os(iOS)

/// 负责绘制取景覆盖层（遮罩、构图辅助线与跟踪标记）。
struct ContentOverlayView: View {
	let compositionRect: CGRect
	let canvasRect: CGRect
	let cropRectInView: CGRect?
	let boxCenterInView: CGPoint?
	let isAligned: Bool
	let distanceToCenter: CGFloat? // 新增：传入距离用于颜色渐变

	/// 绘制覆盖层内容，包括构图线、裁剪框与对齐指示。
	var body: some View {
		// 🔥 根据距离计算渐变颜色
		let focusColor: Color = {
			guard let distance = distanceToCenter else {
				return .white
			}
			// 距离范围: 0-25 points
			// 0-5: 完全绿色 (对齐)
			// 5-25: 从绿色渐变到白色
			let normalized = min(max((distance - 5.0) / 20.0, 0.0), 1.0)
			let greenAmount = 1.0 - normalized
			return Color(
				red: normalized,
				green: 1.0,
				blue: normalized
			).opacity(0.7 + greenAmount * 0.3) // 绿色时更不透明
		}()

		// 将外部传入的全局坐标转换为 Canvas 本地坐标
		let localComposition = CGRect(x: compositionRect.minX - canvasRect.minX,
									  y: compositionRect.minY - canvasRect.minY,
									  width: compositionRect.width,
									  height: compositionRect.height)

		ZStack(alignment: .topLeading) {
			Path { path in
				let thirdWidth = localComposition.width / 3 // 3 等分宽度
				let thirdHeight = localComposition.height / 3 // 3 等分高度
				// 绘制遮罩区域

				for i in 1..<3 {
					let x = localComposition.minX + CGFloat(i) * thirdWidth
					path.move(to: CGPoint(x: x, y: localComposition.minY))
					path.addLine(to: CGPoint(x: x, y: localComposition.maxY))
				}
				for i in 1..<3 {
					let y = localComposition.minY + CGFloat(i) * thirdHeight
					path.move(to: CGPoint(x: localComposition.minX, y: y))
					path.addLine(to: CGPoint(x: localComposition.maxX, y: y))
				}
			}
			.stroke(Color.white.opacity(0.75), lineWidth: 1)

			// 绘制对焦点
			Circle()
				.strokeBorder(focusColor.opacity(1), lineWidth: 5)
				.frame(width: 24, height: 24)
				.position(x: localComposition.midX, y: localComposition.midY)

			// 绘制跟踪框中心点
			if let pointGlobal = boxCenterInView {
				let pointLocal = CGPoint(x: pointGlobal.x - canvasRect.minX,
										 y: pointGlobal.y - canvasRect.minY)
				let clamped = clamp(point: pointLocal, to: localComposition)
				Circle()
					.fill(focusColor)
					.frame(width: 12, height: 12)
					.position(clamped)
					.animation(.linear(duration: 1.0), value: clamped)
			}
		}
		.frame(width: canvasRect.width, height: canvasRect.height, alignment: .topLeading) // 参数解释：设置覆盖层的大小和位置
		.allowsHitTesting(false) // 禁止交互，确保触摸事件传递到底层视图
	}

	/// 将点坐标限制在指定矩形范围内。
	private func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
		CGPoint(x: min(max(point.x, rect.minX), rect.maxX),
				y: min(max(point.y, rect.minY), rect.maxY))
	}
}

#endif