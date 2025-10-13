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

	/// 绘制覆盖层内容，包括构图线、裁剪框与对齐指示。
	var body: some View {
		let focusColor: Color = isAligned ? .green : .white

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
				.strokeBorder(focusColor.opacity(1), lineWidth: 4)
				.frame(width: 28, height: 28)
				.position(x: localComposition.midX, y: localComposition.midY)

			// 绘制裁剪框
			if let rectGlobal = cropRectInView?.intersection(compositionRect),
			   !rectGlobal.isNull, !rectGlobal.isEmpty {
				let rect = CGRect(x: rectGlobal.minX - canvasRect.minX,
								  y: rectGlobal.minY - canvasRect.minY,
								  width: rectGlobal.width,
								  height: rectGlobal.height)
				let rounded = Path(roundedRect: rect, cornerRadius: 3)
				rounded
					.fill(Color.green.opacity(0.18))
					.overlay(rounded.stroke(Color.green.opacity(0.85), lineWidth: 2))
					.animation(.easeInOut(duration: 0.18), value: rect)
			}

			// 绘制跟踪框中心点
			if let pointGlobal = boxCenterInView {
				let pointLocal = CGPoint(x: pointGlobal.x - canvasRect.minX,
										 y: pointGlobal.y - canvasRect.minY)
				let clamped = clamp(point: pointLocal, to: localComposition)
				Circle()
					.fill(focusColor)
					.frame(width: 12, height: 12)
					.position(clamped)
					.animation(.linear(duration: 0.05), value: clamped)
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