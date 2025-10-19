//
//  DebugPanel.swift
//  LiveCapture
//
//  调试信息面板组件
//
//  ## 文件作用
//  在拍摄界面顶部显示详细的调试信息
//  方便开发和测试时查看系统状态
//  提供分组化的信息展示
//
//  ## 主要组件
//  ### DebugPanel
//  调试信息面板视图
//
//  ## 输入参数
//  - debugMessage: String - 调试消息文本
//  - motionIsStable: Bool - 运动是否稳定
//  - boxCenterInView: CGPoint? - 追踪点位置
//  - distanceToCenter: CGFloat? - 到中心的距离
//  - detectionReady: Bool - 检测是否就绪
//  - zoomDisplayText: String - 变焦显示文本
//  - focalLengthText: String - 焦距显示文本
//  - isAligned: Bool - 是否对齐
//  - onClose: () -> Void - 关闭回调
//
//  ## UI 结构
//  标题栏:
//  - 图标徽章（chart.bar.fill）
//  - "调试信息" 标题
//  - Spacer
//  - 关闭按钮（xmark.circle.fill）
//
//  信息分组:
//  1. 状态信息
//     - 运动稳定性（绿/黄指示器）
//     - 检测就绪状态（绿/灰指示器）
//     - 对齐状态（绿/灰指示器）
//
//  2. 追踪信息
//     - 追踪点位置坐标
//     - 到中心的距离
//
//  3. 相机信息
//     - 变焦倍率
//     - 等效焦距
//
//  4. 调试消息
//     - 系统调试文本
//
//  ## UI 组件
//  - DebugInfoRow: 私有行组件
//    参数:
//      - label: String - 标签文本
//      - value: String - 值文本
//      - color: Color? - 可选高亮颜色
//    样式: 左对齐标签 + 右对齐值
//
//  - StatusIndicator: 私有状态指示器
//    参数:
//      - isActive: Bool - 激活状态
//      - activeColor: Color - 激活颜色
//      - inactiveColor: Color - 未激活颜色
//      - label: String - 标签文本
//    样式: 圆点指示器 + 标签
//
//  ## 视觉设计
//  - 半透明深色背景
//  - 毛玻璃效果（.ultraThinMaterial）
//  - 圆角卡片设计
//  - 渐变色边框
//  - 分组标题和分隔线
//
//  ## 交互
//  - 点击关闭按钮触发 onClose 回调
//  - 展开/收起动画由父组件控制
//
//  ## 辅助方法
//  - formatCoordinate(_:): 格式化坐标点
//    返回: "x: 123.4, y: 567.8"
//  
//  - formatDistance(_:): 格式化距离值
//    返回: "12.3 pt"
//

import SwiftUI

#if os(iOS)

/// 调试信息面板
struct DebugPanel: View {
	let debugMessage: String
	let motionIsStable: Bool
	let boxCenterInView: CGPoint?
	let distanceToCenter: CGFloat?
	let detectionReady: Bool
	let zoomDisplayText: String
	let focalLengthText: String
	let isAligned: Bool
	let onClose: () -> Void
	
	var body: some View {
		VStack(spacing: 0) {
			// 调试信息卡片
			VStack(alignment: .leading, spacing: 12) {
				// 标题栏
				HStack {
					ZStack {
						Circle()
							.fill(
								LinearGradient(
									colors: [
										DesignSystem.Colors.accent,
										DesignSystem.Colors.accent.opacity(0.7)
									],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								)
							)
							.frame(width: 32, height: 32)
						
						Image(systemName: "chart.bar.fill")
							.foregroundColor(.white)
							.font(.system(size: 14, weight: .bold))
					}
					
					Text("调试信息")
						.font(.system(size: 18, weight: .bold, design: .rounded))
						.foregroundColor(.white)
					
					Spacer()
					
					Button(action: onClose) {
						ZStack {
							Circle()
								.fill(Color.white.opacity(0.15))
								.frame(width: 32, height: 32)
							
							Image(systemName: "xmark")
								.foregroundColor(.white.opacity(0.8))
								.font(.system(size: 14, weight: .bold))
						}
					}
				}
				.padding(.bottom, 4)
				
				Divider()
					.background(
						LinearGradient(
							colors: [
								Color.white.opacity(0.3),
								Color.white.opacity(0.1)
							],
							startPoint: .leading,
							endPoint: .trailing
						)
					)
				
				// 主要状态信息
				Group {
					debugInfoRow(
						icon: "gearshape.2.fill",
						title: "状态",
						value: debugMessage,
						iconColor: DesignSystem.Colors.info
					)
					debugInfoRow(
						icon: motionIsStable ? "gyroscope" : "exclamationmark.triangle.fill",
						title: "稳定性",
						value: motionIsStable ? "稳定" : "不稳定",
						valueColor: motionIsStable ? DesignSystem.Colors.success : DesignSystem.Colors.warning,
						iconColor: motionIsStable ? DesignSystem.Colors.success : DesignSystem.Colors.warning
					)
				}
				
				Divider()
					.background(Color.white.opacity(0.1))
				
				// 跟踪和检测信息
				Group {
					if let center = boxCenterInView {
						debugInfoRow(
							icon: "scope",
							title: "跟踪位置",
							value: "(\(Int(center.x)), \(Int(center.y)))",
							iconColor: DesignSystem.Colors.primary
						)
					} else {
						debugInfoRow(
							icon: "scope",
							title: "跟踪位置",
							value: "无",
							valueColor: .gray,
							iconColor: .gray
						)
					}
					
					if let distance = distanceToCenter {
						debugInfoRow(
							icon: "arrow.left.and.right",
							title: "距离中心",
							value: "\(String(format: "%.1f", distance)) pts",
							valueColor: distance < 15 ? DesignSystem.Colors.success : .white,
							iconColor: distance < 15 ? DesignSystem.Colors.success : DesignSystem.Colors.primary
						)
					} else {
						debugInfoRow(
							icon: "arrow.left.and.right",
							title: "距离中心",
							value: "--",
							valueColor: .gray,
							iconColor: .gray
						)
					}
					
					debugInfoRow(
						icon: detectionReady ? "checkmark.circle.fill" : "circle.dotted",
						title: "检测状态",
						value: detectionReady ? "已就绪" : "未就绪",
						valueColor: detectionReady ? DesignSystem.Colors.success : .gray,
						iconColor: detectionReady ? DesignSystem.Colors.success : .gray
					)
				}
				
				Divider()
					.background(Color.white.opacity(0.1))
				
				// 相机参数
				Group {
					debugInfoRow(
						icon: "camera.aperture",
						title: "变焦",
						value: "\(zoomDisplayText) / \(focalLengthText)",
						iconColor: DesignSystem.Colors.secondary
					)
					
					debugInfoRow(
						icon: isAligned ? "target" : "circle.dashed",
						title: "对准状态",
						value: isAligned ? "已对准" : "未对准",
						valueColor: isAligned ? DesignSystem.Colors.success : .white,
						iconColor: isAligned ? DesignSystem.Colors.success : .gray
					)
				}
			}
			.padding(20)
			.background(
				RoundedRectangle(cornerRadius: 24)
					.fill(.ultraThinMaterial)
					.overlay(
						RoundedRectangle(cornerRadius: 24)
							.fill(Color.black.opacity(0.3))
					)
			)
			.overlay(
				RoundedRectangle(cornerRadius: 24)
					.strokeBorder(
						LinearGradient(
							colors: [
								DesignSystem.Colors.accent.opacity(0.5),
								DesignSystem.Colors.accent.opacity(0.2),
								Color.white.opacity(0.1)
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						),
						lineWidth: 2
					)
			)
			.shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 20, y: 8)
		}
		.padding(.horizontal, 20)
		.padding(.top, 12)
	}
	
	/// 调试信息行组件
	private func debugInfoRow(
		icon: String,
		title: String,
		value: String,
		valueColor: Color = .white,
		iconColor: Color = DesignSystem.Colors.accent
	) -> some View {
		HStack(spacing: 14) {
			// 图标容器
			ZStack {
				Circle()
					.fill(iconColor.opacity(0.2))
					.frame(width: 32, height: 32)
				
				Image(systemName: icon)
					.font(.system(size: 14, weight: .semibold))
					.foregroundColor(iconColor)
			}
			
			Text(title)
				.font(.system(size: 14, weight: .medium))
				.foregroundColor(.white.opacity(0.85))
				.frame(width: 85, alignment: .leading)
			
			Spacer()
			
			Text(value)
				.font(.system(size: 14, weight: .bold, design: .rounded))
				.foregroundColor(valueColor)
				.lineLimit(1)
				.padding(.horizontal, 12)
				.padding(.vertical, 6)
				.background(
					Capsule()
						.fill(valueColor.opacity(0.15))
				)
		}
		.padding(.vertical, 6)
	}
}

#endif
