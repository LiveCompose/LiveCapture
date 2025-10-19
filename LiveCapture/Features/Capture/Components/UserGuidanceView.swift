//
//  UserGuidanceView.swift
//  LiveCapture
//
//  用户引导视图组件

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
