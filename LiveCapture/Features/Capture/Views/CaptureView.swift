//
//  CaptureView.swift
//  LiveCapture
//
//  主拍摄界面

import SwiftUI
import AVFoundation

#if os(iOS)

/// 主拍摄界面
struct CaptureView: View {
	@StateObject private var viewModel = CaptureViewModel()
	@State private var showDebugInfo = false
	@State private var pinchInitialFactor: CGFloat = 1.0
	@State private var pinchActive = false
	@State private var captureAnimationScale: CGFloat = 1.0
	@State private var captureFlashOpacity: Double = 0.0
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
					onCompositionRectUpdate: { rect in
						viewModel.registerCompositionRect(rect)
					}
				)
				.frame(width: geo.size.width, height: geo.size.height)
				.scaleEffect(captureAnimationScale)
				.animation(.spring(response: 0.3, dampingFraction: 0.6), value: captureAnimationScale)
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
		.toast(
			isShowing: $viewModel.showSaveToast,
			message: "照片已保存到相册",
			style: .success,
			duration: 2.0
		)
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
			onReset: {
				viewModel.resetDetectionState()
			},
			onToggleDebug: {
				withAnimation(DesignSystem.Animation.smooth) {
					showDebugInfo.toggle()
				}
			},
			onToggleCamera: {
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
			// 变焦环
			zoomRing
			
			// 拍照按钮
			HStack(spacing: 25) {
				CaptureButton(isScaled: captureAnimationScale > 1.5) {
					HapticManager.shared.capture()
					viewModel.capturePhoto()
				}
			}
			
			// 辅助按钮
			HStack {
				SecondaryCircleButton(systemName: "photo.on.rectangle") {
					HapticManager.shared.light()
					viewModel.openSystemPhotoLibrary()
				}
				Spacer()
				SecondaryCircleButton(systemName: "arrow.triangle.2.circlepath.camera") {
					HapticManager.shared.light()
					viewModel.toggleCameraPosition()
				}
			}
		}
		.padding(.horizontal, 24)
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
			.frame(height: 120)
			.transition(.opacity.combined(with: .move(edge: .bottom)))
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
}

#endif
