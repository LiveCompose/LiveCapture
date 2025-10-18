//
//  ContentViewModel.swift
//  LiveCapture
//

import Foundation
import Combine
import AVFoundation
import Vision
import CoreImage
import ImageIO
import CoreMotion

#if os(iOS)
import SwiftUI

/// 负责将取景界面所需的业务逻辑与状态封装为可观察对象。
final class ContentViewModel: ObservableObject {
	// MARK: - Dependencies

	private(set) var camera = CameraManager()
	private let motion = MotionStabilityMonitor()
	private let aestheticDetector = AestheticCropDetector()
	private let boxCenterManager = BoxCenterManager()

	// MARK: - Published state exposed to the view

	// MARK: - Published State
	
	@Published private(set) var cropRectInView: CGRect?
	@Published private(set) var initialCropRectInView: CGRect?
	@Published private(set) var compositionRectInView: CGRect = .zero
	@Published private(set) var isAligned: Bool = false
	@Published private(set) var showSaveToast: Bool = false
	@Published private(set) var debugMessage: String = "等待相机启动..."
	@Published private(set) var pipelineStage: PipelineStage = .idle
	@Published private(set) var distanceToCenter: CGFloat?
	@Published private(set) var detectionReady: Bool = false
	@Published private(set) var motionIsStable: Bool = false
	@Published private(set) var zoomState: CameraManager.ZoomState
	@Published private(set) var zoomPresets: [CameraManager.ZoomPreset]
	@Published private(set) var zoomRange: ClosedRange<CGFloat>
	
	// MARK: - Computed Properties
	
	var baseBoxCenterInView: CGPoint? { boxCenterManager.baseCenterInView }
	var boxCenterInView: CGPoint? { boxCenterManager.currentCenterInView }
	
	var adjustedCropRectInView: CGRect? {
		guard let initialRect = initialCropRectInView,
			  let baseCenter = baseBoxCenterInView,
			  let currentCenter = boxCenterInView else {
			return nil
		}
		let dx = currentCenter.x - baseCenter.x
		let dy = currentCenter.y - baseCenter.y
		return initialRect.offsetBy(dx: dx, dy: dy)
	}

	// MARK: - Private State

	private static let ciContext = CIContext()
	private let alignmentTolerance: CGFloat = 15.0 // 对齐容差 (points)
	private var detectionInProgress: Bool = false
	private var cancellables: Set<AnyCancellable> = []
	private var autoCaptureWorkItem: DispatchWorkItem?

	// MARK: - Pipeline stage description

	enum PipelineStage: Equatable {
		case idle
		case startingCamera
		case waitingForStability
		case detectingRegion
		case templateReady
		case aligning
		case capturingPhoto
		case savingPhoto
		case error

		var progress: Double {
			switch self {
			case .idle: return 0.05
			case .startingCamera: return 0.15
			case .waitingForStability: return 0.3
			case .detectingRegion: return 0.55
			case .templateReady: return 0.7
			case .aligning: return 0.85
			case .capturingPhoto: return 0.95
			case .savingPhoto: return 1.0
			case .error: return 0.2
			}
		}
	}

	// MARK: - Lifecycle

	init() {
		zoomState = camera.zoomState
		zoomPresets = camera.zoomPresets
		zoomRange = camera.zoomRange
		bindMotion()
		bindCamera()
	}

	deinit {
		autoCaptureWorkItem?.cancel()
	}

	// MARK: - Public API

	var session: AVCaptureSession { camera.session }
	var pipelineProgress: Double { pipelineStage.progress }

	/// 处理视图出现事件，启动相机与传感器。
	func onAppear() {
		setStage(.startingCamera, message: "正在启动相机...")
		camera.checkAndConfigure { [weak self] result in
			guard let self else { return }
			switch result {
			case .success:
				self.camera.startSession()
				DispatchQueue.main.async {
					self.setStage(.waitingForStability, message: "相机启动成功，等待稳定...")
				}
			case .failure:
				DispatchQueue.main.async {
					self.setStage(.error, message: "相机启动失败")
				}
			}
		}
		motion.start()
		setupCallbacks()
	}

	/// 处理视图消失事件，停止后台任务。
	func onDisappear() {
		autoCaptureWorkItem?.cancel()
		motion.stop()
		camera.stopSession()
	}

	/// 注册最新的构图区域尺寸，触发中心点刷新。
	func registerCompositionRect(_ rect: CGRect) {
		guard compositionRectInView != rect else { return }
		compositionRectInView = rect
		boxCenterManager.updateCompositionRect(rect)
	}

	/// 请求相机捕获一张照片。
	func capturePhoto() {
		camera.capturePhoto()
	}

	/// 应用指定的变焦预设。
	func selectZoomPreset(_ preset: CameraManager.ZoomPreset) {
		camera.selectZoomPreset(preset)
	}

	/// 在拖动过程中实时更新变焦倍率。
	func updateZoomInteractively(to factor: CGFloat) {
		camera.updateInteractiveZoom(to: factor)
	}

	/// 拖动结束后锁定最终变焦倍率。
	func finalizeZoomInteractively(at factor: CGFloat, smooth: Bool) {
		camera.finalizeInteractiveZoom(at: factor, smooth: smooth)
	}

	var zoomDisplayText: String {
		let factor = zoomState.displayedFactor
		if abs(Double(factor.rounded()) - Double(factor)) < 0.001 {
			return "\(Int(factor.rounded()))×"
		}
		return String(format: "%.2f×", factor)
	}

	var focalLengthText: String {
		"\(zoomState.focalLength)mm"
	}

	/// 切换前后镜头并重置状态提示。
	func toggleCameraPosition() {
		camera.toggleCameraPosition()
		setStage(.waitingForStability, message: "切换镜头，等待稳定")
	}

	/// 跳转到系统相册以浏览已拍摄内容。
	func openSystemPhotoLibrary() {
		#if canImport(UIKit)
		if let url = URL(string: "photos-redirect://") {
			DispatchQueue.main.async {
				UIApplication.shared.open(url, options: [:], completionHandler: nil)
			}
		}
		#endif
	}

	/// 重置检测状态
	func resetDetectionState() {
		detectionReady = false
		isAligned = false
		cropRectInView = nil
		initialCropRectInView = nil
		boxCenterManager.reset()
		autoCaptureWorkItem?.cancel()
		motion.resetReferenceAttitude()
		detectionInProgress = false
		setStage(.waitingForStability, message: "已重置检测，等待稳定...")
	}

	// MARK: - Bindings

	/// 订阅运动监视器的稳定性与偏移更新。
	private func bindMotion() {
		motion.$deviceMotion
			.receive(on: DispatchQueue.main)
			.sink { [weak self] motion in
				guard let self else { return }
				self.boxCenterManager.updateCenter(with: motion)
				
				// 更新距离信息
				self.distanceToCenter = self.boxCenterManager.distanceToCenter()
				
				// 更新裁切框位置以跟随追踪点
				if let adjusted = self.adjustedCropRectInView {
					self.cropRectInView = adjusted
				}
				
				// 如果检测已就绪，使用基于距离的对齐检测
				if self.detectionReady {
					self.checkAlignmentByDistance()
				}
			}
			.store(in: &cancellables)

		motion.$isStable
			.receive(on: DispatchQueue.main)
			.sink { [weak self] stable in
				guard let self else { return }
				self.motionIsStable = stable
				if !stable {
					self.setStage(.waitingForStability, message: "等待设备稳定...")
				}
			}
			.store(in: &cancellables)
	}

	/// 订阅相机管理器的状态变更。
	private func bindCamera() {
		camera.$lastPhotoSaved
			.receive(on: DispatchQueue.main)
			.sink { [weak self] saved in
				guard let self else { return }
				guard saved else { return }
				self.showSaveToast = true
				self.setStage(.savingPhoto, message: "照片已保存到相册")
				DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
					self.showSaveToast = false
				}
			}
			.store(in: &cancellables)

		camera.$zoomState
			.receive(on: DispatchQueue.main)
			.sink { [weak self] state in
				guard let self else { return }
				self.zoomState = state
				self.boxCenterManager.updateZoomFactor(state.currentFactor)
			}
			.store(in: &cancellables)

		camera.$zoomPresets
			.receive(on: DispatchQueue.main)
			.sink { [weak self] presets in
				self?.zoomPresets = presets
			}
			.store(in: &cancellables)

		camera.$zoomRange
			.receive(on: DispatchQueue.main)
			.sink { [weak self] range in
				self?.zoomRange = range
			}
			.store(in: &cancellables)
	}

	// MARK: - Camera Processing

	/// 设置相机帧回调
	private func setupCallbacks() {
		camera.onSampleBuffer = { [weak self] sample in
			guard let self else { return }
			self.handleSampleBuffer(sample)
		}
	}

		/// 处理单帧采样数据
	private func handleSampleBuffer(_ sample: CMSampleBuffer) {
		guard let rawPixel = CMSampleBufferGetImageBuffer(sample) else { return }
		let orientation = pixelOrientation(for: rawPixel)

		guard motion.isStable else {
			DispatchQueue.main.async {
				self.setStage(.waitingForStability, message: "等待设备稳定...")
			}
			return
		}

		guard let compositionPixel = makeCompositionPixelBuffer(from: rawPixel, orientation: orientation) else {
			DispatchQueue.main.async {
				self.setStage(.error, message: "无法处理画面")
			}
			return
		}

		// 只在未检测时执行一次检测，之后依靠距离对齐
		if !detectionReady && !detectionInProgress {
			DispatchQueue.main.async {
				self.setStage(.detectingRegion, message: "设备已稳定，开始识别目标区域...")
				self.detectionInProgress = true
			}
			detectCropRegion(using: compositionPixel, orientation: orientation)
		}
	}

	/// 执行美学裁切检测
	private func detectCropRegion(using pixel: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
		// 计算当前构图区域的宽高比
		let aspectRatio: CGFloat = compositionRectInView != .zero 
			? compositionRectInView.width / compositionRectInView.height 
			: 3.0 / 4.0
		
		aestheticDetector.detectBestCrop(
			in: pixel,
			orientation: orientation,
			targetAspectRatio: aspectRatio
		) { [weak self] crop in
			guard let self, let crop else {
				DispatchQueue.main.async {
					self?.setStage(.waitingForStability, message: "目标识别失败，等待重试...")
					self?.resetDetectionState()
				}
				return
			}

			DispatchQueue.main.async {
				if let rectInView = self.rectInCompositionSpace(from: crop.rect, orientation: orientation) {
					self.initialCropRectInView = rectInView
					self.cropRectInView = rectInView
					
					let center = CGPoint(x: rectInView.midX, y: rectInView.midY)
					self.boxCenterManager.setBaseCenter(
						center,
						with: self.motion.deviceMotion?.attitude,
					)
					self.motion.lockReferenceAttitude()
					
					self.detectionReady = true
					self.setStage(.templateReady, message: "目标已锁定: \(crop.detectionType)，移动设备对齐中心圆")
					self.isAligned = false
				} else {
					self.initialCropRectInView = nil
					self.cropRectInView = nil
					self.boxCenterManager.reset()
				}
				
				self.detectionInProgress = false
			}
		}
	}

	/// 安排自动拍照任务,确保对准后短延迟触发。
	private func scheduleAutoCapture() {
		autoCaptureWorkItem?.cancel()
		let work = DispatchWorkItem { [weak self] in
			guard let self else { return }
			if self.isAligned {
				self.setStage(.capturingPhoto, message: "正在拍照")
				self.capturePhoto()
			}
		}
		autoCaptureWorkItem = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
	}

	/// 取消已排队的自动拍照任务。
	private func cancelAutoCapture() {
		autoCaptureWorkItem?.cancel()
		autoCaptureWorkItem = nil
	}
	
	// MARK: - Alignment Detection
	
	/// 检查追踪点是否与中心对齐
	private func checkAlignmentByDistance() {
		let alignedNow = boxCenterManager.isAlignedWithCenter(tolerance: alignmentTolerance)
		
		if alignedNow && !isAligned {
			setStage(.aligning, message: "对准成功")
			scheduleAutoCapture()
		} else if alignedNow {
			setStage(.aligning, message: "保持对准")
		} else if !alignedNow && isAligned {
			cancelAutoCapture()
		}
		
		isAligned = alignedNow
	}

	/// 切换管线阶段并可选更新调试信息。
	private func setStage(_ stage: PipelineStage, message: String? = nil) {
		let applyChange = {
			self.pipelineStage = stage
			if let message {
				self.debugMessage = message
			}
		}
		if Thread.isMainThread {
			applyChange()
		} else {
			DispatchQueue.main.async(execute: applyChange)
		}
	}

	// MARK: - Geometry Helpers

	/// 将输入像素缓冲旋正并裁剪为构图画幅
	private func makeCompositionPixelBuffer(from pixelBuffer: CVPixelBuffer,
											orientation: CGImagePropertyOrientation) -> CVPixelBuffer? {
		let orientedImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
		let extent = orientedImage.extent
		let desiredAspect: CGFloat = 3.0 / 4.0
		var cropRect = extent
		let currentAspect = extent.width / extent.height

		if currentAspect > desiredAspect {
			let newWidth = extent.height * desiredAspect
			cropRect.origin.x = extent.midX - newWidth * 0.5
			cropRect.size.width = newWidth
		} else if currentAspect < desiredAspect {
			let newHeight = extent.width / desiredAspect
			cropRect.origin.y = extent.midY - newHeight * 0.5
			cropRect.size.height = newHeight
		}

		let croppedImage = orientedImage.cropped(to: cropRect)

		var outputBuffer: CVPixelBuffer?
		let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
		let attributes: [String: Any] = [
			kCVPixelBufferCGImageCompatibilityKey as String: true,
			kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
		]

		let status = CVPixelBufferCreate(kCFAllocatorDefault,
										 Int(cropRect.width),
										 Int(cropRect.height),
										 pixelFormat,
										 attributes as CFDictionary,
										 &outputBuffer)
		guard status == kCVReturnSuccess, let buffer = outputBuffer else { return nil }

		ContentViewModel.ciContext.render(croppedImage, to: buffer)
		return buffer
	}

	/// 根据像素尺寸推断原始图像的方向。
	private func pixelOrientation(for pixelBuffer: CVPixelBuffer) -> CGImagePropertyOrientation {
		let width = CVPixelBufferGetWidth(pixelBuffer)
		let height = CVPixelBufferGetHeight(pixelBuffer)
		return width > height ? .right : .up
	}

	/// 将归一化矩形转换到当前方向的坐标系。
	private func rotateNormalizedRect(_ rect: CGRect,
									  for orientation: CGImagePropertyOrientation) -> CGRect {
		switch orientation {
		case .up, .upMirrored:
			return rect
		case .right, .rightMirrored:
			return CGRect(x: 1.0 - rect.origin.y - rect.size.height,
						  y: rect.origin.x,
						  width: rect.size.height,
						  height: rect.size.width)
		case .down, .downMirrored:
			return CGRect(x: 1.0 - rect.origin.x - rect.size.width,
						  y: 1.0 - rect.origin.y - rect.size.height,
						  width: rect.size.width,
						  height: rect.size.height)
		case .left, .leftMirrored:
			return CGRect(x: rect.origin.y,
						  y: 1.0 - rect.origin.x - rect.size.width,
						  width: rect.size.height,
						  height: rect.size.width)
		@unknown default:
			return rect
		}
	}

	/// 将归一化矩形映射到取景区域坐标。
	private func rectInCompositionSpace(from rect: CGRect,
										orientation: CGImagePropertyOrientation) -> CGRect? {
		guard compositionRectInView != .zero else { return nil }
		let composition = compositionRectInView
		let rotated = rotateNormalizedRect(rect, for: orientation)
		let x = composition.minX + rotated.origin.x * composition.width
		let y = composition.minY + (1.0 - rotated.origin.y - rotated.size.height) * composition.height
		let width = rotated.size.width * composition.width
		let height = rotated.size.height * composition.height
		let mapped = CGRect(x: x, y: y, width: width, height: height)
		guard mapped.intersects(composition) else { return nil }
		return mapped.intersection(composition)
	}
}

#endif
