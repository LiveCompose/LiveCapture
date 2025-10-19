//
//  ContentOverlayView.swift
//  LiveCapture
//
//  内容覆盖层视图
//
//  ## 文件作用
//  在相机预览上绘制覆盖层元素
//  包括遮罩、构图辅助线、检测框、追踪点和对齐指示器
//  提供视觉引导帮助用户完成智能构图
//
//  ## 主要组件
//  ### ContentOverlayView
//  取景覆盖层视图
//
//  ## 输入参数
//  - compositionRect: CGRect - 构图区域（全局坐标）
//  - canvasRect: CGRect - 画布区域
//  - cropRectInView: CGRect? - 检测到的裁切框
//  - boxCenterInView: CGPoint? - 追踪点位置
//  - isAligned: Bool - 是否对齐中心
//  - distanceToCenter: CGFloat? - 到中心的距离
//
//  ## 状态
//  - pulseAnimation: Bool - 脉冲动画状态
//  - rotationAngle: Double - 旋转角度（用于动画）
//
//  ## 视觉元素
//
//  ### 1. 构图辅助线
//  - 九宫格三分线
//  - 白色半透明线条
//  - 帮助用户按照摄影构图法则
//
//  ### 2. 外部遮罩
//  - 构图区域外的半透明黑色遮罩
//  - 突出构图区域
//  - 引导用户关注有效拍摄范围
//
//  ### 3. 检测框
//  - 显示 AI 检测到的最佳裁切区域
//  - 白色虚线边框
//  - 半透明白色填充
//  - 圆角矩形设计
//
//  ### 4. 追踪点标记
//  - 显示当前追踪点位置
//  - 根据距离动态变色：
//    - 0-5pt: 绿色（对齐状态）
//    - 5-25pt: 绿色→白色渐变
//    - >25pt: 白色
//  - 多层圆环设计：
//    - 外圈：发光效果
//    - 中圈：主体圆环
//    - 内圈：十字准星
//  - 持续旋转动画
//
//  ### 5. 中心对齐指示器
//  - 中心十字准星
//  - 对齐时变绿色并放大
//  - 脉冲动画吸引注意
//  - 目标位置指示
//
//  ### 6. 引导箭头
//  - 未对齐时显示
//  - 指向中心方向
//  - 帮助用户理解移动方向
//  - 根据距离调整透明度
//
//  ## 动画效果
//  - 追踪点旋转：持续 360° 旋转
//  - 脉冲动画：对齐时的缩放效果
//  - 颜色渐变：平滑的距离-颜色映射
//  - 箭头淡入淡出
//
//  ## 辅助方法
//  - 坐标转换：将全局坐标转换为 Canvas 本地坐标
//  - 颜色计算：基于距离计算渐变颜色
//  - 几何计算：计算箭头方向和位置
//
//  ## 性能优化
//  - 使用 Path 高效绘制
//  - 条件渲染减少不必要的视图
//  - 动画使用硬件加速
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
	
	@State private var pulseAnimation = false
	@State private var rotationAngle: Double = 0

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
			// 构图辅助线
			Path { path in
				let thirdWidth = localComposition.width / 3 // 3 等分宽度
				let thirdHeight = localComposition.height / 3 // 3 等分高度

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
			.stroke(
				LinearGradient(
					colors: [
						Color.white.opacity(0.3),
						Color.white.opacity(0.5),
						Color.white.opacity(0.3)
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				),
				lineWidth: 1.2
			)
			.shadow(color: .black.opacity(0.5), radius: 2, y: 1)

			// 中心对焦点 - 增强版
			ZStack {
				// 外围脉动圆
				if isAligned {
					Circle()
						.stroke(focusColor.opacity(0.4), lineWidth: 2)
						.frame(width: 48, height: 48)
						.scaleEffect(pulseAnimation ? 1.3 : 1.0)
						.opacity(pulseAnimation ? 0.0 : 0.6)
						.animation(
							.easeOut(duration: 1.5)
								.repeatForever(autoreverses: false),
							value: pulseAnimation
						)
				}
				
				// 旋转外圈
				Circle()
					.trim(from: 0, to: 0.75)
					.stroke(
						focusColor,
						style: StrokeStyle(
							lineWidth: 3,
							lineCap: .round,
							lineJoin: .round
						)
					)
					.frame(width: 32, height: 32)
					.rotationEffect(.degrees(rotationAngle))
					.animation(
						.linear(duration: 2)
							.repeatForever(autoreverses: false),
						value: rotationAngle
					)
				
				// 内圈
				Circle()
					.strokeBorder(focusColor, lineWidth: 2)
					.frame(width: 24, height: 24)
					.shadow(color: focusColor.opacity(0.6), radius: 8, y: 0)
				
				// 中心点
				Circle()
					.fill(focusColor)
					.frame(width: 6, height: 6)
					.shadow(color: focusColor, radius: 4, y: 0)
				
				// 十字准心
				Path { path in
					// 水平线
					path.move(to: CGPoint(x: -12, y: 0))
					path.addLine(to: CGPoint(x: -4, y: 0))
					path.move(to: CGPoint(x: 4, y: 0))
					path.addLine(to: CGPoint(x: 12, y: 0))
					
					// 垂直线
					path.move(to: CGPoint(x: 0, y: -12))
					path.addLine(to: CGPoint(x: 0, y: -4))
					path.move(to: CGPoint(x: 0, y: 4))
					path.addLine(to: CGPoint(x: 0, y: 12))
				}
				.stroke(focusColor, lineWidth: 1.5)
			}
			.position(x: localComposition.midX, y: localComposition.midY)

			// 绘制跟踪框中心点 - 增强版
			if let pointGlobal = boxCenterInView {
				let pointLocal = CGPoint(x: pointGlobal.x - canvasRect.minX,
										 y: pointGlobal.y - canvasRect.minY)
				let clamped = clamp(point: pointLocal, to: localComposition)
				
				ZStack {
					// 外围光晕
					//Circle()
					//	.fill(
					//		RadialGradient(
					///			colors: [
					//				focusColor.opacity(0.6),
					//				focusColor.opacity(0.2),
					//				Color.clear
					//			],
					//			center: .center,
					//			startRadius: 0,
					//			endRadius: 20
					//		)
					//	)
					//	.frame(width: 40, height: 40)
					
					// 主圆点
					Circle()
						.fill(focusColor)
						.frame(width: 16, height: 16)
						.overlay(
							Circle()
								.strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
						)
						.shadow(color: focusColor.opacity(0.8), radius: 8, y: 0)
					
					// 内部闪光点
					Circle()
						.fill(Color.white)
						.frame(width: 6, height: 6)
						.offset(x: -2, y: -2)
						.blur(radius: 0.5)
				}
				.position(clamped)
				.animation(.spring(response: 0.3, dampingFraction: 0.7), value: clamped)
			}
			
			// 四角框线 - 取景框边角
			ForEach(0..<4, id: \.self) { corner in
				cornerBracket(at: corner, in: localComposition)
					.stroke(
						LinearGradient(
							colors: [
								Color.white.opacity(0.8),
								Color.white.opacity(0.4)
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						),
						lineWidth: 3
					)
					.shadow(color: .black.opacity(0.6), radius: 3, y: 1)
			}
		}
		.frame(width: canvasRect.width, height: canvasRect.height, alignment: .topLeading)
		.allowsHitTesting(false)
		.onAppear {
			pulseAnimation = true
			rotationAngle = 360
		}
	}

	/// 将点坐标限制在指定矩形范围内。
	private func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
		CGPoint(x: min(max(point.x, rect.minX), rect.maxX),
				y: min(max(point.y, rect.minY), rect.maxY))
	}
	
	/// 生成四角括号路径
	private func cornerBracket(at corner: Int, in rect: CGRect) -> Path {
		Path { path in
			let length: CGFloat = 20
			let offset: CGFloat = 8
			
			switch corner {
			case 0: // 左上角
				let start = CGPoint(x: rect.minX + offset, y: rect.minY + offset)
				path.move(to: CGPoint(x: start.x + length, y: start.y))
				path.addLine(to: start)
				path.addLine(to: CGPoint(x: start.x, y: start.y + length))
				
			case 1: // 右上角
				let start = CGPoint(x: rect.maxX - offset, y: rect.minY + offset)
				path.move(to: CGPoint(x: start.x - length, y: start.y))
				path.addLine(to: start)
				path.addLine(to: CGPoint(x: start.x, y: start.y + length))
				
			case 2: // 左下角
				let start = CGPoint(x: rect.minX + offset, y: rect.maxY - offset)
				path.move(to: CGPoint(x: start.x + length, y: start.y))
				path.addLine(to: start)
				path.addLine(to: CGPoint(x: start.x, y: start.y - length))
				
			case 3: // 右下角
				let start = CGPoint(x: rect.maxX - offset, y: rect.maxY - offset)
				path.move(to: CGPoint(x: start.x - length, y: start.y))
				path.addLine(to: start)
				path.addLine(to: CGPoint(x: start.x, y: start.y - length))
				
			default:
				break
			}
		}
	}
}

#endif