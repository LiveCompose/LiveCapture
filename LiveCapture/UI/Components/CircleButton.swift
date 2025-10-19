//
//  CircleButton.swift
//  LiveCapture
//
//  通用圆形按钮组件
//
//  ## 文件作用
//  提供可复用的圆形按钮样式组件
//  用于整个应用的一致性按钮设计
//
//  ## 组件列表
//
//  ### SecondaryCircleButton
//  次要功能圆形按钮（大尺寸，56pt）
//  
//  参数:
//  - systemName: String - SF Symbol 图标名称
//  - action: () -> Void - 点击回调
//  
//  用途:
//  - 底部辅助功能按钮
//  - 相册、切换摄像头等操作
//  
//  样式:
//  - 直径 56pt
//  - 半透明黑色背景
//  - 白色叠加层
//  - 22pt 中等粗细图标
//
//  ### TopCircleButton
//  顶部控制栏圆形按钮（小尺寸，38pt）
//  
//  参数:
//  - systemName: String - SF Symbol 图标名称
//  - action: () -> Void - 点击回调
//  
//  用途:
//  - 顶部控制栏按钮
//  - 重置、设置等功能
//  
//  样式:
//  - 直径 38pt
//  - 半透明黑色背景
//  - 白色叠加层
//  - 18pt 半粗图标
//
//  ## 设计特点
//  - 统一的视觉风格
//  - 半透明材质适配各种背景
//  - 清晰的视觉层次
//  - 适当的可触摸区域
//

import SwiftUI

#if os(iOS)

/// 次要功能圆形按钮 (大尺寸)
struct SecondaryCircleButton: View {
	let systemName: String
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			ZStack {
				Circle()
					.fill(Color.black.opacity(0.5))
					.overlay(
						Circle()
							.fill(Color.white.opacity(0.3))
					)
					.frame(width: 56, height: 56)
				
				Image(systemName: systemName)
					.font(.system(size: 22, weight: .medium))
					.foregroundStyle(.white)
			}
		}
	}
}

/// 顶部控制栏圆形按钮 (小尺寸)
struct TopCircleButton: View {
	let systemName: String
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			ZStack {
				Circle()
					.fill(Color.black.opacity(0.5))
					.overlay(
						Circle()
							.fill(Color.white.opacity(0.3))
					)
					.frame(width: 38, height: 38)
				
				Image(systemName: systemName)
					.font(.system(size: 18, weight: .semibold))
					.foregroundStyle(.white)
			}
		}
	}
}

#endif
