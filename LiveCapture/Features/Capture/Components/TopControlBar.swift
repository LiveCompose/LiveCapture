//
//  TopControlBar.swift
//  LiveCapture
//
//  顶部控制栏组件
//
//  ## 文件作用
//  提供拍摄界面顶部的控制栏UI
//  集成用户引导、重置按钮和设置菜单
//  处理各种控制操作的回调
//
//  ## 主要组件
//  ### TopControlBar
//  顶部控制栏视图
//
//  ## 输入参数
//  - userGuidanceText: String - 用户引导文字
//  - showDebugInfo: Bool - 调试面板显示状态
//  - isAutoCaptureEnabled: Bool - 自动拍照开关状态
//  - captureDelay: Double - 拍照延迟时间（秒）
//
//  ## 回调闭包
//  - onReset: () -> Void - 重置检测状态
//  - onToggleDebug: () -> Void - 切换调试面板
//  - onToggleCamera: () -> Void - 切换摄像头
//  - onToggleAutoCapture: () -> Void - 切换自动拍照
//  - onSetCaptureDelay: (Double) -> Void - 设置拍照延迟
//
//  ## UI 布局
//  左侧:
//  - TopCircleButton: 重置按钮（arrow.clockwise 图标）
//
//  中间:
//  - UserGuidanceView: 用户引导提示（条件显示）
//
//  右侧:
//  - Menu: 设置菜单
//    - 调试模式开关
//    - 相机设置子菜单
//      - 切换镜头
//      - 锁定焦点（待实现）
//    - 拍摄设置子菜单
//      - 自动拍照开关
//      - 延迟设置（0.5/1.0/1.5/2.0秒）
//    - 帮助和关于
//
//  ## 交互反馈
//  - 使用 HapticManager 提供触觉反馈
//  - 不同操作使用不同反馈强度
//    - medium: 重置操作
//    - selection: 菜单选择
//    - light/soft: 辅助操作
//
//  ## 子组件
//  - TopCircleButton: 自定义圆形按钮（私有组件）
//    样式: 半透明背景，白色图标
//    功能: 点击回调和触觉反馈
//

import SwiftUI

#if os(iOS)

/// 顶部控制栏
struct TopControlBar: View {
	let userGuidanceText: String
	let showDebugInfo: Bool
	let isAutoCaptureEnabled: Bool
	let captureDelay: Double
	
	let onReset: () -> Void
	let onToggleDebug: () -> Void
	let onToggleCamera: () -> Void
	let onToggleAutoCapture: () -> Void
	let onSetCaptureDelay: (Double) -> Void
	
	var body: some View {
		HStack {
			// 左侧重置按钮
			TopCircleButton(systemName: "arrow.clockwise") {
				HapticManager.shared.medium()
				onReset()
			}
			
			Spacer()
			
			// 中间显示用户引导
			if !userGuidanceText.isEmpty {
				UserGuidanceView(guidanceText: userGuidanceText)
			}
			
			Spacer()
			
			// 右侧菜单按钮
			Menu {
				// 调试模式
				Button {
					HapticManager.shared.selection()
					onToggleDebug()
				} label: {
					Label(showDebugInfo ? "隐藏调试信息" : "显示调试信息", 
						  systemImage: showDebugInfo ? "eye.slash" : "eye")
				}
				
				Divider()
				
				// 相机设置部分
				Menu {
					Button {
						HapticManager.shared.selection()
						onToggleCamera()
					} label: {
						Label("切换镜头", systemImage: "arrow.triangle.2.circlepath.camera")
					}
					
					Button {
						// 预留：镜头锁定功能
					} label: {
						Label("锁定焦点（待实现）", systemImage: "lock.circle")
					}
					.disabled(true)
					
				} label: {
					Label("相机设置", systemImage: "camera")
				}
				
				// 拍摄设置
				Menu {
					Button {
						HapticManager.shared.selection()
						onToggleAutoCapture()
					} label: {
						Label(
							isAutoCaptureEnabled ? "关闭自动拍照" : "开启自动拍照",
							systemImage: isAutoCaptureEnabled ? "bolt.fill" : "bolt.slash"
						)
					}
					
					// 延迟设置
					Menu {
						ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { delay in
							Button {
								HapticManager.shared.soft()
								onSetCaptureDelay(delay)
							} label: {
								HStack {
									Text("\(String(format: "%.1f", delay))秒")
									if abs(captureDelay - delay) < 0.01 {
										Image(systemName: "checkmark")
									}
								}
							}
						}
					} label: {
						Label("拍照延迟: \(String(format: "%.1f", captureDelay))秒", systemImage: "timer")
					}
					
				} label: {
					Label("拍摄设置", systemImage: "camera.aperture")
				}
				
				Divider()
				
				// 帮助和关于
				Button {
					HapticManager.shared.light()
					// 预留：显示帮助
				} label: {
					Label("使用帮助", systemImage: "questionmark.circle")
				}
				
				Button {
					HapticManager.shared.light()
					// 预留：关于页面
				} label: {
					Label("关于", systemImage: "info.circle")
				}
				
			} label: {
				ZStack {
					Circle()
						.fill(Color.black.opacity(0.5))
						.overlay(
							Circle()
								.fill(Color.white.opacity(0.3))
						)
						.frame(width: 38, height: 38)
					
					Image(systemName: "ellipsis")
						.font(.system(size: 18, weight: .semibold))
						.foregroundStyle(.white)
				}
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 8)
	}
}

#endif
