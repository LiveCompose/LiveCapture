//
//  MainView.swift
//  LiveCapture
//
//  应用主页视图
//
//  ## 文件作用
//  提供应用的启动页面和模式选择界面
//  负责展示应用信息、使用提示和导航到拍摄界面
//
//  ## 主要组件
//  - AppMode: 枚举，定义应用的不同使用模式
//  - MainView: 主页视图，包含模式选择和导航逻辑
//  - ModeCard: 私有视图组件，展示单个模式的卡片
//
//  ## 主要功能
//  - 展示应用图标、标题和介绍
//  - 提供智能拍摄模式的入口
//  - 显示使用提示和功能说明
//  - 带有流畅的进入动画效果
//
//  ## 导航
//  - 通过 NavigationStack 管理页面跳转
//  - 点击模式卡片导航到 CaptureView
//

import SwiftUI

#if os(iOS)

/// 应用模式选项
enum AppMode: String, CaseIterable, Identifiable {
	case user
	var id: String { rawValue }
	var title: String { "智能拍摄" }
	var description: String { "捕捉完美瞬间" }
	var icon: String { "camera.aperture" }
	var gradient: LinearGradient {
		LinearGradient(
			colors: [
				Color(red: 0.4, green: 0.6, blue: 1.0),
				Color(red: 0.6, green: 0.4, blue: 1.0)
			],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}
}

/// 应用首页
struct MainView: View {
	@State private var selection: AppMode? = nil
	@State private var isAnimating = false
	
	var body: some View {
		NavigationStack {
			ZStack {
				// 背景渐变
				LinearGradient(
					colors: [
						Color.black,
						Color(red: 0.05, green: 0.05, blue: 0.15),
						Color.black
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()
				
				VStack(spacing: 32) {
					Spacer()
					
					// 标题区域
					VStack(spacing: 16) {
						ZStack {
							Circle()
								.fill(
									RadialGradient(
										colors: [
											Color.blue.opacity(0.3),
											Color.clear
										],
										center: .center,
										startRadius: 0,
										endRadius: 80
									)
								)
								.frame(width: 160, height: 160)
								.blur(radius: 30)
							
							Image(systemName: "viewfinder.circle.fill")
								.font(.system(size: 80, weight: .light))
								.foregroundStyle(
									LinearGradient(
										colors: [.white, .white.opacity(0.8)],
										startPoint: .top,
										endPoint: .bottom
									)
								)
						}
						.scaleEffect(isAnimating ? 1.0 : 0.8)
						.opacity(isAnimating ? 1.0 : 0.0)
						
						VStack(spacing: 8) {
							Text("LiveCapture")
								.font(.system(size: 42, weight: .bold, design: .rounded))
								.foregroundStyle(
									LinearGradient(
										colors: [.white, .white.opacity(0.8)],
										startPoint: .leading,
										endPoint: .trailing
									)
								)
							
							Text("智能构图助手")
								.font(.system(size: 17, weight: .medium))
								.foregroundColor(.white.opacity(0.6))
						}
						.opacity(isAnimating ? 1.0 : 0.0)
					}
					
					Spacer()
					
					// 模式选择卡片
					VStack(spacing: 16) {
						ForEach(AppMode.allCases) { mode in
							NavigationLink(value: mode) {
								ModeCard(mode: mode)
									.opacity(isAnimating ? 1.0 : 0.0)
							}
						}
					}
					.padding(.horizontal, 24)
					
					// 使用提示
					VStack(spacing: 12) {
						HStack(spacing: 8) {
							Image(systemName: "lightbulb.fill")
								.font(.system(size: 16, weight: .semibold))
								.foregroundColor(.yellow.opacity(0.9))
							
							Text("使用提示")
								.font(.system(size: 15, weight: .semibold))
								.foregroundColor(.white)
						}
						
						Text("点击取景界面右上角菜单可显示调试信息和调整设置")
							.font(.system(size: 13, weight: .regular))
							.foregroundColor(.white.opacity(0.6))
							.multilineTextAlignment(.center)
							.fixedSize(horizontal: false, vertical: true)
					}
					.padding(16)
					.frame(maxWidth: .infinity)
					.background(
						RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
							.fill(.ultraThinMaterial)
							.overlay(
								RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
									.fill(Color.white.opacity(0.05))
							)
					)
					.padding(.horizontal, 24)
					.opacity(isAnimating ? 1.0 : 0.0)
					.padding(.bottom, 32)
				}
			}
			.navigationBarHidden(true)
			.navigationDestination(for: AppMode.self) { _ in
				CaptureView()
			}
			.onAppear {
				withAnimation(DesignSystem.Animation.smooth.delay(0.2)) {
					isAnimating = true
				}
			}
		}
	}
}

/// 模式选择卡片
private struct ModeCard: View {
	let mode: AppMode
	@State private var isPressed = false
	
	var body: some View {
		HStack(spacing: 20) {
			// 图标
			ZStack {
				Circle()
					.fill(mode.gradient)
					.frame(width: 64, height: 64)
					.shadow(color: Color.blue.opacity(0.3), radius: 10, y: 5)
				
				Image(systemName: mode.icon)
					.font(.system(size: 28, weight: .medium))
					.foregroundColor(.white)
			}
			
			// 文字信息
			VStack(alignment: .leading, spacing: 6) {
				Text(mode.title)
					.font(.system(size: 20, weight: .bold, design: .rounded))
					.foregroundColor(.white)
				
				Text(mode.description)
					.font(.system(size: 14, weight: .medium))
					.foregroundColor(.white.opacity(0.7))
					.lineLimit(2)
			}
			
			Spacer()
			
			// 箭头图标
			Image(systemName: "arrow.right")
				.font(.system(size: 20, weight: .semibold))
				.foregroundColor(.white.opacity(0.6))
		}
		.padding(20)
		.frame(maxWidth: .infinity)
		.background(
			RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
				.fill(.ultraThinMaterial)
				.overlay(
					RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
						.fill(Color.white.opacity(0.05))
				)
		)
		.overlay(
			RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
				.strokeBorder(
					LinearGradient(
						colors: [
							Color.white.opacity(0.3),
							Color.white.opacity(0.1)
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					),
					lineWidth: 1
				)
		)
		.scaleEffect(isPressed ? 0.97 : 1.0)
		.animation(DesignSystem.Animation.quick, value: isPressed)
		.onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
			isPressed = pressing
		}, perform: {})
	}
}

#endif
