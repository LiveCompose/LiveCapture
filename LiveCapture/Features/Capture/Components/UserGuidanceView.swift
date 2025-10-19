//
//  UserGuidanceView.swift
//  LiveCapture
//
//  用户引导视图组件
//
//  ## 文件作用
//  在顶部中央显示动态的用户操作引导
//  根据不同的流程阶段提供文字和图标提示
//  使用不同颜色表示不同状态
//
//  ## 主要组件
//  ### UserGuidanceView
//  用户引导胶囊视图
//
//  ## 输入参数
//  - guidanceText: String - 引导文字内容
//
//  ## UI 设计
//  - 胶囊形状背景
//  - 半透明黑色底色
//  - 根据状态动态变化的边框颜色
//  - 左侧状态图标 + 右侧文字
//
//  ## 状态映射
//
//  ### statusIcon(for:) 方法
//  根据引导文字返回对应的 SF Symbol 图标
//  - "启动" → "power"
//  - "保持"/"稳定" → "hand.raised.fill"
//  - "识别"/"检测" → "viewfinder"
//  - "移动"/"对准" → "arrow.up.and.down.and.arrow.left.and.right"
//  - "即将"/"拍照" → "camera.fill"
//  - "保存"/"完成" → "checkmark.circle.fill"
//  - "错误" → "exclamationmark.triangle.fill"
//  - 默认 → "info.circle.fill"
//
//  ### statusColor(for:) 方法
//  根据引导文字返回对应的状态颜色
//  - "错误" → DesignSystem.Colors.error（红色）
//  - "保存"/"完成"/"即将" → DesignSystem.Colors.success（绿色）
//  - "保持"/"稳定" → DesignSystem.Colors.warning（黄色）
//  - "识别"/"检测" → DesignSystem.Colors.info（蓝色）
//  - 默认 → DesignSystem.Colors.primary
//
//  ## 视觉特点
//  - 条件显示：文字为空时不渲染
//  - 单行文字，超出截断
//  - 圆角设计，边框高亮
//  - 与状态相关的视觉反馈
//

import SwiftUI

#if os(iOS)

/// 用户引导视图
struct UserGuidanceView: View {
	let guidanceText: String
	
	var body: some View {
		if !guidanceText.isEmpty {
			HStack(spacing: 8) {
				// 状态图标
				Image(systemName: statusIcon(for: guidanceText))
					.font(.system(size: 16, weight: .semibold))
					.foregroundColor(statusColor(for: guidanceText))
				
				Text(guidanceText)
					.font(.system(size: 16, weight: .semibold, design: .rounded))
					.foregroundColor(.white)
					.lineLimit(1)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 8)
			.frame(height: 38)
			.background(
				Capsule()
					.fill(Color.black.opacity(0.5))
			)
			.overlay(
				Capsule()
					.strokeBorder(statusColor(for: guidanceText).opacity(0.6), lineWidth: 1.5)
			)
		}
	}
	
	/// 根据引导文字返回对应的图标
	private func statusIcon(for guidance: String) -> String {
		if guidance.contains("启动") {
			return "power"
		} else if guidance.contains("保持") || guidance.contains("稳定") {
			return "hand.raised.fill"
		} else if guidance.contains("识别") || guidance.contains("检测") {
			return "viewfinder"
		} else if guidance.contains("移动") || guidance.contains("对准") {
			return "arrow.up.and.down.and.arrow.left.and.right"
		} else if guidance.contains("即将") || guidance.contains("拍照") {
			return "camera.fill"
		} else if guidance.contains("保存") || guidance.contains("完成") {
			return "checkmark.circle.fill"
		} else if guidance.contains("错误") {
			return "exclamationmark.triangle.fill"
		} else {
			return "info.circle.fill"
		}
	}
	
	/// 根据引导文字返回对应的颜色
	private func statusColor(for guidance: String) -> Color {
		if guidance.contains("错误") {
			return DesignSystem.Colors.error
		} else if guidance.contains("保存") || guidance.contains("完成") || guidance.contains("即将") {
			return DesignSystem.Colors.success
		} else if guidance.contains("保持") || guidance.contains("稳定") {
			return DesignSystem.Colors.warning
		} else if guidance.contains("识别") || guidance.contains("检测") {
			return DesignSystem.Colors.info
		} else {
			return DesignSystem.Colors.primary
		}
	}
}

#endif
