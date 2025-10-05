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

#if os(iOS)
import SwiftUI

/// 负责将取景界面所需的业务逻辑与状态封装为可观察对象。
final class ContentViewModel: ObservableObject {
	// MARK: - Published state exposed to the view

	@Published private(set) var cropRectInView: CGRect?
	@Published private(set) var baseBoxCenterInView: CGPoint?
	@Published private(set) var boxCenterInView: CGPoint?
	@Published private(set) var compositionRectInView: CGRect = .zero
	@Published private(set) var lastCroppedPixelBuffer: CVPixelBuffer?
	@Published private(set) var isAligned: Bool = false
	@Published private(set) var showSaveToast: Bool = false
	@Published private(set) var debugMessage: String = "等待相机启动..."
	@Published private(set) var pipelineStage: PipelineStage = .idle
	@Published private(set) var lastSimilarity: Float?
	@Published private(set) var templateReady: Bool = false
	@Published private(set) var motionIsStable: Bool = false

	// MARK: - Dependencies

	private(set) var camera = CameraManager()
	private let motion = MotionStabilityMonitor()
	private let adacrop = AdacropModel()
	private let templateMatcher = TemplateMatcher()

	// MARK: - Private state

	private static let ciContext = CIContext()
	private let similarityThresholdInternal: Float = 0.84
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

	// MARK: - Life cycle

	init() {
		bindMotion()
		bindCamera()
	}

	deinit {
		autoCaptureWorkItem?.cancel()
	}

	// MARK: - Exposed helpers

	var session: AVCaptureSession { camera.session }
	var similarityThreshold: Float { similarityThresholdInternal }
	var pipelineProgress: Double { pipelineStage.progress }

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

	func onDisappear() {
		autoCaptureWorkItem?.cancel()
		motion.stop()
		camera.stopSession()
	}

	func registerCompositionRect(_ rect: CGRect) {
		guard compositionRectInView != rect else { return }
		compositionRectInView = rect
		updateBoxCenter(withNormalizedOffset: motion.screenOffsetNormalized)
	}

	func capturePhoto() {
		camera.capturePhoto()
	}

	func toggleCameraPosition() {
		camera.toggleCameraPosition()
		setStage(.waitingForStability, message: "切换镜头，等待稳定")
	}

	func openSystemPhotoLibrary() {
		#if canImport(UIKit)
		if let url = URL(string: "photos-redirect://") {
			DispatchQueue.main.async {
				UIApplication.shared.open(url, options: [:], completionHandler: nil)
			}
		}
		#endif
	}

	func resetDetectionState() {
		templateReady = false
		isAligned = false
		lastSimilarity = nil
		cropRectInView = nil
		baseBoxCenterInView = nil
		boxCenterInView = nil
		lastCroppedPixelBuffer = nil
		autoCaptureWorkItem?.cancel()
		motion.resetReferenceAttitude()
		adacrop.resetSmoothing()
		templateMatcher.resetTemplate()
		detectionInProgress = false
		setStage(.waitingForStability, message: "已重置检测，等待稳定...")
	}

	#if canImport(UIKit)
	func templatePreviewImage() -> UIImage? {
		templateMatcher.templateUIImage()
	}

	func centerPreviewImage() -> UIImage? {
		guard let pixel = lastCroppedPixelBuffer else { return nil }
		return templateMatcher.centerUIImage(from: pixel)
	}
	#endif

	// MARK: - Bindings

	private func bindMotion() {
		motion.$screenOffsetNormalized
			.receive(on: DispatchQueue.main)
			.sink { [weak self] offset in
				self?.updateBoxCenter(withNormalizedOffset: offset)
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
	}

	// MARK: - Camera processing pipeline

	private func setupCallbacks() {
		camera.onSampleBuffer = { [weak self] sample in
			guard let self else { return }
			self.handleSampleBuffer(sample)
		}
	}

	private func handleSampleBuffer(_ sample: CMSampleBuffer) {
		guard let rawPixel = CMSampleBufferGetImageBuffer(sample) else { return }
		let orientation = pixelOrientation(for: rawPixel)

		guard motion.isStable else {
			DispatchQueue.main.async {
				self.setStage(.waitingForStability, message: "等待设备稳定...")
			}
			return
		}

		guard let compositionPixel = makeThreeByFourPixelBuffer(from: rawPixel, orientation: orientation) else {
			DispatchQueue.main.async {
				self.setStage(.error, message: "无法裁剪 3:4 画面")
			}
			return
		}

		if !templateReady && !detectionInProgress {
			DispatchQueue.main.async {
				self.setStage(.detectingRegion, message: "设备已稳定，开始识别目标区域...")
				self.lastCroppedPixelBuffer = compositionPixel
				self.detectionInProgress = true
			}
			detectCropOnce(using: compositionPixel, orientation: orientation)
		} else if templateReady {
			evaluateTemplateSimilarity(with: compositionPixel)
			DispatchQueue.main.async {
				self.lastCroppedPixelBuffer = compositionPixel
			}
		}
	}

	private func detectCropOnce(using pixel: CVPixelBuffer,
								orientation: CGImagePropertyOrientation) {
		adacrop.predictCropBox(pixelBuffer: pixel, orientation: orientation) { [weak self] crop in
			guard let self else { return }
			guard let crop else {
				DispatchQueue.main.async {
					self.setStage(.waitingForStability, message: "目标识别失败，等待重试...")
					self.cropRectInView = nil
					self.baseBoxCenterInView = nil
					self.boxCenterInView = nil
					self.templateReady = false
					self.motion.resetReferenceAttitude()
					self.adacrop.resetSmoothing()
					self.detectionInProgress = false
					self.templateMatcher.resetTemplate()
				}
				return
			}

			DispatchQueue.main.async {
				if let rectInView = self.rectInCompositionSpace(from: crop.rectInNormalizedImage,
																 orientation: orientation) {
					self.cropRectInView = rectInView
					let center = CGPoint(x: rectInView.midX, y: rectInView.midY)
					self.baseBoxCenterInView = center
					self.boxCenterInView = center
					self.motion.lockReferenceAttitude()
					self.updateBoxCenter(withNormalizedOffset: self.motion.screenOffsetNormalized)
				} else {
					self.cropRectInView = nil
					self.baseBoxCenterInView = nil
					self.boxCenterInView = nil
				}
			}

			self.templateMatcher.setTemplate(from: pixel, normalizedRegion: crop.rectInNormalizedImage) { [weak self] ok in
				guard let self else { return }
				DispatchQueue.main.async {
					if ok {
						self.templateReady = true
						self.setStage(.templateReady, message: "模板已生成：\(crop.detectionType)，开始相似度匹配")
						self.lastSimilarity = nil
						self.isAligned = false
					} else {
						self.templateReady = false
						self.setStage(.error, message: "模板生成失败，等待重试...")
						self.baseBoxCenterInView = nil
						self.boxCenterInView = nil
						self.motion.resetReferenceAttitude()
					}
					self.detectionInProgress = false
				}
			}
		}
	}

	private func evaluateTemplateSimilarity(with pixel: CVPixelBuffer) {
		guard let sim = templateMatcher.similarityWithCenter(of: pixel) else {
			DispatchQueue.main.async {
				self.setStage(.error, message: "相似度计算失败")
				self.isAligned = false
				self.lastSimilarity = nil
				self.cancelAutoCapture()
			}
			return
		}

		DispatchQueue.main.async {
			self.lastSimilarity = sim
			let alignedNow = sim >= self.similarityThresholdInternal
			if alignedNow && !self.isAligned {
				self.setStage(.aligning, message: "对准成功")
				self.scheduleAutoCapture()
			} else if alignedNow {
				self.setStage(.aligning, message: "保持对准")
			} 
			self.isAligned = alignedNow
		}
	}

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

	private func cancelAutoCapture() {
		autoCaptureWorkItem?.cancel()
		autoCaptureWorkItem = nil
	}

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

	// MARK: - Geometry helpers

	private func updateBoxCenter(withNormalizedOffset offset: CGPoint) {
		guard let base = baseBoxCenterInView, compositionRectInView != .zero else { return }
		let maxOffsetX = compositionRectInView.width * 0.4
		let maxOffsetY = compositionRectInView.height * 0.4
		let target = CGPoint(x: base.x + offset.x * maxOffsetX,
							 y: base.y + offset.y * maxOffsetY)
		let clamped = clamp(point: target, to: compositionRectInView)
		boxCenterInView = clamped
	}

	private func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
		CGPoint(x: min(max(point.x, rect.minX), rect.maxX),
				y: min(max(point.y, rect.minY), rect.maxY))
	}

	private func makeThreeByFourPixelBuffer(from pixelBuffer: CVPixelBuffer,
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

	private func pixelOrientation(for pixelBuffer: CVPixelBuffer) -> CGImagePropertyOrientation {
		let width = CVPixelBufferGetWidth(pixelBuffer)
		let height = CVPixelBufferGetHeight(pixelBuffer)
		return width > height ? .right : .up
	}

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
