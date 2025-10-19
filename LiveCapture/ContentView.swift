//
//  ContentView.swift
//  LiveCapture
//

/// iOS 主取景界面与功能入口，仅在 iOS 平台编译。
#if os(iOS)
import SwiftUI
import UIKit
/// iOS 主取景界面，负责相机预览、模板匹配以及提示反馈。
struct ContentView: View {
    /// 业务逻辑容器。
    @StateObject private var viewModel = ContentViewModel()
    /// 默认隐藏调试栏，由按钮控制。
    @State private var showDebugInfo = false
    /// 记录双指缩放起始时的倍率，便于根据手势比例计算目标倍率。
    @State private var pinchInitialFactor: CGFloat = 1.0
    /// 标记当前是否正在执行双指缩放，避免重复初始化起始倍率。
    @State private var pinchActive = false
    /// 控制拍照动效的状态
    @State private var captureAnimationScale: CGFloat = 1.0
    @State private var captureFlashOpacity: Double = 0.0
    @Environment(\.dismiss) private var dismiss // 用于关闭当前视图

    /// 主视图内容，包含顶部控制区、取景区和底部控制栏。
    var body: some View {
        GeometryReader { geo in
            let safeInsets = geo.safeAreaInsets // 考虑刘海屏等安全区域

            ZStack {
                // 底层黑色背景，扩展到安全区域之外确保覆盖整屏
                Color.black
                    .ignoresSafeArea()
                    .zIndex(0)

                // 底层为相机预览（固定在黑色底之上）
                CameraPreviewSection()
                    .frame(width: geo.size.width, height: geo.size.height) // 适配全屏
                    .scaleEffect(captureAnimationScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: captureAnimationScale)
                    .ignoresSafeArea() //
                    .zIndex(0)
                
                // 拍照闪光效果
                if captureFlashOpacity > 0 {
                    Color.white
                        .opacity(captureFlashOpacity)
                        .ignoresSafeArea()
                        .zIndex(0.5)
                        .allowsHitTesting(false)
                }

                // 顶层 UI（所有控制项都叠加在预览之上）
                VStack(spacing: 0) {
                    topSection

                    // 用户引导文字
                    userGuidanceView
                        .padding(.top, 12)
                    
                    // 调试面板
                    debugPanel
                        .zIndex(10)

                    Spacer()

                    bottomSection(bottomInset: max(safeInsets.bottom, 16))
                        .padding(.bottom, safeInsets.bottom > 0 ? 0 : 16)
                }
                .zIndex(1)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toast(
            isShowing: $viewModel.showSaveToast,
            message: "照片已保存到相册",
            style: .success,
            duration: 2.0
        )
        .onAppear { 
            viewModel.onAppear()
            viewModel.onCaptureTriggered = { [self] in
                triggerCaptureAnimation()
            }
        }
        .onDisappear { viewModel.onDisappear() }
    }

    /// 顶部区域，包含控制栏与可选调试面板。
    private var topSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            topControlBar
        }
        .padding(.horizontal, 20)
    }
    
    /// 用户引导文字视图
    @ViewBuilder
    private var userGuidanceView: some View {
        let guidance = viewModel.userGuidanceText
        if !guidance.isEmpty {
            HStack {
                Spacer()
                HStack(spacing: 10) {
					// 状态图标
					Image(systemName: statusIcon(for: guidance))
						.font(.system(size: 16, weight: .semibold))
						.foregroundColor(.white)
						.frame(width: 24, height: 24)
					
					Text(guidance)
						.font(.system(size: 15, weight: .semibold, design: .rounded))
						.foregroundColor(.white)
				}
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
					ZStack {
						Capsule()
							.fill(.ultraThinMaterial)
							.overlay(
								Capsule()
									.fill(statusColor(for: guidance).opacity(0.3))
							)
						
						Capsule()
							.strokeBorder(
								LinearGradient(
									colors: [
										Color.white.opacity(0.4),
										Color.white.opacity(0.2)
									],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								),
								lineWidth: 1.5
							)
					}
                )
                .shadow(color: statusColor(for: guidance).opacity(0.4), radius: 12, y: 4)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.8)),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                Spacer()
            }
            .padding(.horizontal, 20)
            .animation(DesignSystem.Animation.bouncy, value: guidance)
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

    /// 构建相机预览与覆盖层的组合视图。
    private func CameraPreviewSection() -> some View {
        GeometryReader { previewGeo in
            let compositionRect = Self.compositionRect(in: previewGeo.size) // 3:4 构图区域
            let canvasRect = CGRect(origin: .zero, size: previewGeo.size) // 整个画布区域

            ZStack {
                CameraPreviewView(session: viewModel.session)
                    .frame(width: compositionRect.width, height: compositionRect.height)
                    .position(x: compositionRect.midX, y: compositionRect.midY)
                    .clipped()

                ContentOverlayView(
                    compositionRect: compositionRect,
                    canvasRect: canvasRect,
                    cropRectInView: viewModel.cropRectInView, // 裁剪框（可选）
                    boxCenterInView: viewModel.boxCenterInView, // 跟踪框中心（可选）
                    isAligned: viewModel.isAligned, // 对齐状态
                    distanceToCenter: viewModel.distanceToCenter // 距离中心的距离（用于颜色渐变）
                )
            }
            .onAppear {
                viewModel.registerCompositionRect(compositionRect)
            }
            .onChange(of: previewGeo.size) { _, newSize in
                viewModel.registerCompositionRect(Self.compositionRect(in: newSize))
            }
        }
        .gesture(pinchZoomGesture)
    }

    /// 底部控制区，包含变焦环与功能按钮。
    private func bottomSection(bottomInset: CGFloat) -> some View {
        VStack(spacing: 18) {
            zoomRing
            HStack(spacing: 25) {
                captureButton
            }
            HStack {
                secondaryCircleButton(systemName: "photo.on.rectangle") {
                    viewModel.openSystemPhotoLibrary()
                }
                Spacer()
                secondaryCircleButton(systemName: "arrow.triangle.2.circlepath.camera") {
                    viewModel.toggleCameraPosition()
                }
            }
        }
        .padding(.horizontal, 24)
    }

    /// 变焦环控件，当支持连续变焦或多个预设时显示。
    @ViewBuilder
    private var zoomRing: some View {
        let span = viewModel.zoomRange.upperBound - viewModel.zoomRange.lowerBound
        if span > CGFloat(0.05) || viewModel.zoomPresets.count > 1 {
            ZoomRingView(
                config: .init(
                    presets: viewModel.zoomPresets,
                    range: viewModel.zoomRange,
                    state: viewModel.zoomState,
                    onPresetTap: { preset in
                        viewModel.selectZoomPreset(preset)
                    },
                    onDragChanged: { factor in
                        viewModel.updateZoomInteractively(to: factor)
                    },
                    onDragEnded: { factor in
                        viewModel.finalizeZoomInteractively(at: factor, smooth: true)
                    }
                )
            )
            .frame(height: 120)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    /// 顶部控制栏，包含返回、重置、调试显示和菜单操作。
    private var topControlBar: some View {
        ZStack {
			// 左右两端的按钮使用 HStack 布局，确保左侧按钮左对齐、右侧菜单右对齐
			HStack {
				topCircleButton(systemName: "arrow.clockwise") { 
					HapticManager.shared.medium()
					viewModel.resetDetectionState()
				}

				Spacer()
				
				Menu {
                    // 调试模式
					Button {
						HapticManager.shared.selection()
						showDebugInfo.toggle()
					} label: {
						Label(showDebugInfo ? "隐藏调试信息" : "显示调试信息", systemImage: showDebugInfo ? "eye.slash" : "eye")
					}
                    
                    Divider()
                    
                    // 相机设置部分
                    Menu {
                        Button {
							HapticManager.shared.selection()
                            viewModel.toggleCameraPosition()
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
                            viewModel.toggleAutoCapture()
                        } label: {
                            Label(
                                viewModel.isAutoCaptureEnabled ? "关闭自动拍照" : "开启自动拍照",
                                systemImage: viewModel.isAutoCaptureEnabled ? "bolt.fill" : "bolt.slash"
                            )
                        }
                        
                        // 延迟设置
                        Menu {
                            ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { delay in
                                Button {
									HapticManager.shared.soft()
                                    viewModel.setCaptureDelay(delay)
                                } label: {
                                    HStack {
                                        Text("\(String(format: "%.1f", delay))秒")
                                        if abs(viewModel.captureDelay - delay) < 0.01 {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("拍照延迟: \(String(format: "%.1f", viewModel.captureDelay))秒", systemImage: "timer")
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
					topCircleLabel(systemName: "ellipsis")
				}
			}
            // 中心显示进度条，使用 ZStack 居中叠放，给进度条左右留出间距以避免与两侧按钮重叠
            statusProgressView
                .padding(.horizontal, 64)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    /// 顶部居中的进度提示视图。
    private var statusProgressView: some View {
        VStack(spacing: 0) {
            ProgressView(value: viewModel.pipelineProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.Colors.success))
                .frame(height: 6)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.15))
                .cornerRadius(3)
        }
        .frame(maxWidth: 100, alignment: .center)
        .frame(height: 44)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassmorphism(cornerRadius: 22)
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }

    /// 主拍照按钮样式。
    private var captureButton: some View {
        Button(action: { 
			HapticManager.shared.capture()
			viewModel.capturePhoto() 
		}) {
            ZStack {
				// 外层大圆
                Circle()
                    .strokeBorder(
						LinearGradient(
							colors: [
								Color.white,
								Color.white.opacity(0.8)
							],
							startPoint: .top,
							endPoint: .bottom
						),
						lineWidth: 6
					)
                    .frame(width: 84, height: 84)
					.shadow(color: .white.opacity(0.4), radius: 10, y: 0)
				
				// 内层圆
                Circle()
					.fill(
						RadialGradient(
							colors: [
								Color.white.opacity(0.9),
								Color.white.opacity(0.3)
							],
							center: .center,
							startRadius: 10,
							endRadius: 35
						)
					)
					.frame(width: 70, height: 70)
					.shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            }
        }
		.scaleEffect(captureAnimationScale > 1.5 ? 0.95 : 1.0)
		.animation(DesignSystem.Animation.quick, value: captureAnimationScale)
    }

    /// 构建次要圆形按钮，适用于辅助操作。
    private func secondaryCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: {
			HapticManager.shared.light()
			action()
		}) {
            ZStack {
				Circle()
					.fill(.ultraThinMaterial)
					.overlay(
						Circle()
							.fill(Color.white.opacity(0.1))
					)
					.frame(width: 56, height: 56)
				
				Circle()
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
					.frame(width: 56, height: 56)
				
                Image(systemName: systemName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
			.shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        }
    }

    /// 生成顶部控制栏使用的圆形按钮。
    private func topCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            topCircleLabel(systemName: systemName)
        }
    }

    /// 顶部圆形按钮的内部标签样式。
    private func topCircleLabel(systemName: String) -> some View {
        ZStack {
			Circle()
				.fill(.ultraThinMaterial)
				.overlay(
					Circle()
						.fill(Color.white.opacity(0.1))
				)
				.frame(width: 44, height: 44)
			
			Circle()
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
				.frame(width: 44, height: 44)
			
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
		.shadow(color: .black.opacity(0.3), radius: 8, y: 3)
    }

    @ViewBuilder
    /// 展示调试信息与图像预览的面板。
    private var debugPanel: some View {
        if showDebugInfo {
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
                        
						Button {
							HapticManager.shared.light()
                            withAnimation(DesignSystem.Animation.smooth) {
                                showDebugInfo = false
                            }
                        } label: {
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
							value: viewModel.debugMessage,
							iconColor: DesignSystem.Colors.info
						)
                        debugInfoRow(
                            icon: viewModel.motionIsStable ? "gyroscope" : "exclamationmark.triangle.fill",
                            title: "稳定性",
                            value: viewModel.motionIsStable ? "稳定" : "不稳定",
                            valueColor: viewModel.motionIsStable ? DesignSystem.Colors.success : DesignSystem.Colors.warning,
							iconColor: viewModel.motionIsStable ? DesignSystem.Colors.success : DesignSystem.Colors.warning
                        )
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // 跟踪和检测信息
                    Group {
                        if let center = viewModel.boxCenterInView {
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
                        
                        if let distance = viewModel.distanceToCenter {
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
                            icon: viewModel.detectionReady ? "checkmark.circle.fill" : "circle.dotted",
                            title: "检测状态",
                            value: viewModel.detectionReady ? "已就绪" : "未就绪",
                            valueColor: viewModel.detectionReady ? DesignSystem.Colors.success : .gray,
							iconColor: viewModel.detectionReady ? DesignSystem.Colors.success : .gray
                        )
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // 相机参数
                    Group {
                        debugInfoRow(
                            icon: "camera.aperture",
                            title: "变焦",
                            value: "\(viewModel.zoomDisplayText) / \(viewModel.focalLengthText)",
							iconColor: DesignSystem.Colors.secondary
                        )
                        
                        debugInfoRow(
                            icon: viewModel.isAligned ? "target" : "circle.dashed",
                            title: "对准状态",
                            value: viewModel.isAligned ? "已对准" : "未对准",
                            valueColor: viewModel.isAligned ? DesignSystem.Colors.success : .white,
							iconColor: viewModel.isAligned ? DesignSystem.Colors.success : .gray
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
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
        }
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
    
    /// 触发拍照动画
    private func triggerCaptureAnimation() {
        // 闪光效果
        withAnimation(.easeOut(duration: 0.1)) {
            captureFlashOpacity = 0.8
        }
        withAnimation(.easeIn(duration: 0.2).delay(0.1)) {
            captureFlashOpacity = 0.0
        }
        
        // 缩放效果 - 模拟2x变焦
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            captureAnimationScale = 2.0
        }
        
        // 恢复原始大小
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                captureAnimationScale = 1.0
            }
        }
    }

    /// 根据容器尺寸计算 3:4 构图区域。
    private static func compositionRect(in size: CGSize) -> CGRect {
        let width = size.width
        let targetHeight = width * 4.0 / 3.0
        let height = min(size.height, targetHeight)
        let originY = (size.height - height) * 0.5
        return CGRect(x: 0, y: originY, width: width, height: height)
    }

    /// 双指缩放手势，并实时驱动相机变焦。
    private var pinchZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                if !pinchActive {
                    pinchInitialFactor = viewModel.zoomState.currentFactor
                    pinchActive = true
                }
                let target = clampedZoomFactor(for: pinchInitialFactor * scale)
                viewModel.updateZoomInteractively(to: target)
            }
            .onEnded { scale in
                let target = clampedZoomFactor(for: pinchInitialFactor * scale)
                viewModel.finalizeZoomInteractively(at: target, smooth: true)
                pinchActive = false
            }
    }

    /// 将目标倍率限制在相机支持的范围内。
    private func clampedZoomFactor(for factor: CGFloat) -> CGFloat {
        min(max(factor, viewModel.zoomRange.lowerBound), viewModel.zoomRange.upperBound)
    }
}
#endif