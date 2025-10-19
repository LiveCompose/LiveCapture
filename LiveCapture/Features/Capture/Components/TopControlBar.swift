//
//  TopControlBar.swift
//  LiveCapture
//
//  顶部控制栏组件

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
