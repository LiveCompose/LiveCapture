//
//  CaptureView.swift
//  LiveCapture
//
//  主拍摄界面
//
//  ## 文件作用
//  提供智能拍摄的主界面 UI
//  整合相机预览、控制栏、调试面板和拍摄按钮
//  处理用户交互和动画效果
//
//  ## 主要组件
//  ### CaptureView
//  主拍摄视图（SwiftUI View）
//
//  ## 状态管理
//  - viewModel: CaptureViewModel - 业务逻辑视图模型
//  - showDebugInfo: Bool - 是否显示调试面板
//  - pinchInitialFactor: CGFloat - 捏合手势初始倍率
//  - pinchActive: Bool - 捏合手势是否激活
//  - captureAnimationScale: CGFloat - 拍照动画缩放
//  - captureFlashOpacity: Double - 闪光效果透明度
//  - cameraFlipRotation: Double - 摄像头翻转角度
//
//  ## UI 结构
//  - 黑色背景层
//  - 相机预览层（CameraPreviewSection）
//    - 3D 翻转动画支持
//    - 拍照缩放动画
//    - 捏合变焦手势
//  - 白色闪光效果层
//  - UI 控制层
//    - topSection: 顶部控制栏（含返回按钮和设置菜单）
//    - debugPanel: 调试面板（可展开）
//    - bottomSection: 底部控制区（含重置按钮和切换摄像头按钮）
//
//  ## UI Sections（界面分区）
//
//  ### topSection
//  顶部控制栏（TopControlBar）
//  - 返回按钮
//  - 用户引导提示
//  - 调试开关
//  - 设置菜单（切换摄像头、自动拍照等）
//
//  ### debugPanel
//  调试信息面板（DebugPanel）
//  - 运动稳定性状态
//  - 追踪点位置
//  - 距离信息
//  - 变焦状态
//  - 对齐状态
//  - 带展开/收起动画
//
//  ### bottomSection
//  底部控制区
//  - zoomRing: 变焦环（条件显示）
//  - captureButton: 主拍照按钮
//  - 辅助按钮：
//    - 重置按钮
//    - 切换摄像头按钮
//
//  ## 手势处理
//
//  ### pinchZoomGesture
//  捏合缩放手势（MagnificationGesture）
//  - onChanged: 实时更新变焦倍率
//  - onEnded: 完成变焦并锁定
//  - 自动限制在有效变焦范围内
//
//  ## 动画效果
//
//  ### triggerCaptureAnimation()
//  拍照动画
//  - 白色闪光效果（0.1s 淡入 + 0.2s 淡出）
//  - 画面缩放效果（放大到 2.0x 后恢复）
//  - 使用 spring 动画提供弹性效果
//
//  ### triggerCameraFlipAnimation()
//  摄像头切换动画
//  - Y 轴 3D 旋转 180°
//  - spring 动画提供平滑过渡
//
//  ## 辅助方法
//  - clampedZoomFactor(for:): 限制变焦倍率在有效范围
//
//  ## 生命周期
//  - onAppear:
//    - 调用 viewModel.onAppear() 启动服务
//    - 设置拍照触发回调
//  - onDisappear:
//    - 调用 viewModel.onDisappear() 停止服务
//
//  ## 导航
//  - navigationBarBackButtonHidden: 隐藏默认返回按钮
//  - 通过 dismiss 环境值返回主页
//
//  ## 响应式设计
//  - 使用 GeometryReader 适配屏幕尺寸
//  - 根据 safeAreaInsets 调整底部间距
//  - 支持不同屏幕方向
//

import SwiftUI
import AVFoundation

#if os(iOS)

/// 主拍摄界面
struct CaptureView: View {
	@StateObject private var viewModel: CaptureViewModel
	@State private var showDebugInfo = false

	init(detectionMode: DetectionMode = .vision) {
		_viewModel = StateObject(wrappedValue: CaptureViewModel(detectionMode: detectionMode))
	}
	@State private var pinchInitialFactor: CGFloat = 1.0
	@State private var pinchActive = false
	@State private var captureAnimationScale: CGFloat = 1.0
	@State private var captureFlashOpacity: Double = 0.0
	@State private var cameraFlipRotation: Double = 0.0
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		GeometryReader { geo in
			let safeInsets = geo.safeAreaInsets

			ZStack {
				// 黑色背景
				Color.black
					.ignoresSafeArea()
					.zIndex(0)

				// 相机预览
				CameraPreviewSection(
					session: viewModel.session,
					compositionRect: viewModel.compositionRectInView,
					canvasSize: geo.size,
					cropRectInView: viewModel.cropRectInView,
					boxCenterInView: viewModel.boxCenterInView,
					isAligned: viewModel.isAligned,
					distanceToCenter: viewModel.distanceToCenter,
					isFrontCamera: viewModel.isFrontCamera,
					onCompositionRectUpdate: { rect in
						viewModel.registerCompositionRect(rect)
					}
				)
				.frame(width: geo.size.width, height: geo.size.height)
				.scaleEffect(captureAnimationScale)
				.rotation3DEffect(
					.degrees(cameraFlipRotation),
					axis: (x: 0, y: 1, z: 0),
					perspective: 0.5
				)
				.animation(.spring(response: 0.3, dampingFraction: 0.6), value: captureAnimationScale)
				.animation(.spring(response: 0.5, dampingFraction: 0.75), value: cameraFlipRotation)
				.ignoresSafeArea()
				.zIndex(0)
				.gesture(pinchZoomGesture)

				// 拍照闪光效果
				if captureFlashOpacity > 0 {
					Color.white
						.opacity(captureFlashOpacity)
						.ignoresSafeArea()
						.zIndex(0.5)
						.allowsHitTesting(false)
				}

				// UI 层
				VStack(spacing: 0) {
					topSection

					if showDebugInfo {
						debugPanel
							.transition(.asymmetric(
								insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
								removal: .move(edge: .top).combined(with: .opacity)
							))
					}

					Spacer()

					bottomSection(bottomInset: max(safeInsets.bottom, 16))
						.padding(.bottom, safeInsets.bottom > 0 ? 0 : 16)
				}
				.zIndex(1)
			}
		}
		.navigationBarBackButtonHidden(true)
		.onAppear {
			viewModel.onAppear()
			viewModel.onCaptureTriggered = {
				triggerCaptureAnimation()
			}
		}
		.onDisappear {
			viewModel.onDisappear()
		}
	}

	// MARK: - UI Sections

	private var topSection: some View {
		TopControlBar(
			userGuidanceText: viewModel.userGuidanceText,
			showDebugInfo: showDebugInfo,
			isAutoCaptureEnabled: viewModel.isAutoCaptureEnabled,
			captureDelay: viewModel.captureDelay,
			onBack: {
				dismiss()
			},
			onToggleDebug: {
				withAnimation(DesignSystem.Animation.smooth) {
					showDebugInfo.toggle()
				}
			},
			onToggleCamera: {
				triggerCameraFlipAnimation()
				viewModel.toggleCameraPosition()
			},
			onToggleAutoCapture: {
				viewModel.toggleAutoCapture()
			},
			onSetCaptureDelay: { delay in
				viewModel.setCaptureDelay(delay)
			}
		)
		.padding(.horizontal, 20)
	}

	private var debugPanel: some View {
		DebugPanel(
			debugMessage: viewModel.debugMessage,
			motionIsStable: viewModel.motionIsStable,
			boxCenterInView: viewModel.boxCenterInView,
			distanceToCenter: viewModel.distanceToCenter,
			detectionReady: viewModel.detectionReady,
			zoomDisplayText: viewModel.zoomDisplayText,
			focalLengthText: viewModel.focalLengthText,
			isAligned: viewModel.isAligned,
			onClose: {
				HapticManager.shared.light()
				withAnimation(DesignSystem.Animation.smooth) {
					showDebugInfo = false
				}
			}
		)
	}

	private func bottomSection(bottomInset: CGFloat) -> some View {
		VStack(spacing: 18) {
			// 变焦环和流水线开关
			zoomRingWithPipelineToggle

			// 拍照按钮
			HStack(spacing: 25) {
				CaptureButton(isScaled: captureAnimationScale > 1.5) {
					HapticManager.shared.capture()
					viewModel.capturePhoto()
				}
			}

			// 辅助按钮
			HStack {
				SecondaryCircleButton(systemName: "arrow.clockwise") {
					HapticManager.shared.medium()
					viewModel.resetDetectionState()
				}
				Spacer()
				SecondaryCircleButton(systemName: "arrow.triangle.2.circlepath.camera") {
					HapticManager.shared.light()
					triggerCameraFlipAnimation()
					viewModel.toggleCameraPosition()
				}
			}
		}
		.padding(.horizontal, 24)
	}

	@ViewBuilder
	private var zoomRingWithPipelineToggle: some View {
		let span = viewModel.zoomRange.upperBound - viewModel.zoomRange.lowerBound
		let showZoomRing = span > CGFloat(0.05) || viewModel.zoomPresets.count > 1

		if showZoomRing {
			// 变焦环 + 流水线开关
			HStack(alignment: .center, spacing: 0) {
				// 左侧占位
				Spacer()
					.frame(width: 50)

				// 中间变焦环
				Spacer()
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
				Spacer()

				// 右侧流水线开关按钮
				pipelineToggleButton
					.frame(width: 50)
			}
			.frame(height: 120)
			.transition(.opacity.combined(with: .move(edge: .bottom)))
		} else {
			// 只显示流水线开关按钮
			HStack {
				Spacer()
				pipelineToggleButton
			}
			.frame(height: 50)
		}
	}

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
			//.frame(height: 120)
			.transition(.opacity.combined(with: .move(edge: .bottom)))
		}
	}

	private var pipelineToggleButton: some View {
		Button {
			HapticManager.shared.light()
			viewModel.toggleCompositionPipeline()
		} label: {
			ZStack {
				Circle()
					.fill(viewModel.isCompositionPipelineEnabled ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
					.frame(width: 44, height: 44)

				Image(systemName: viewModel.isCompositionPipelineEnabled
					? "wand.and.stars"
					: "wand.and.stars.inverse")
					.font(.system(size: 20, weight: .medium))
					.foregroundColor(viewModel.isCompositionPipelineEnabled
						? .green
						: .white)
			}
		}
	}

	// MARK: - Gestures

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

	private func clampedZoomFactor(for factor: CGFloat) -> CGFloat {
		min(max(factor, viewModel.zoomRange.lowerBound), viewModel.zoomRange.upperBound)
	}

	// MARK: - Animations

	private func triggerCaptureAnimation() {
		// 闪光效果
		withAnimation(.easeOut(duration: 0.1)) {
			captureFlashOpacity = 0.8
		}
		withAnimation(.easeIn(duration: 0.2).delay(0.1)) {
			captureFlashOpacity = 0.0
		}

		// 缩放效果
		withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
			captureAnimationScale = 2.0
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
				captureAnimationScale = 1.0
			}
		}
	}

	private func triggerCameraFlipAnimation() {
		// 3D 翻转动画
		withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
			cameraFlipRotation += 180
		}
	}
}

#endif
