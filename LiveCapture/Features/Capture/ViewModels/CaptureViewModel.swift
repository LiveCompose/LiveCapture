//
//  CaptureViewModel.swift
//  LiveCapture
//
//  拍摄功能的视图模型
//
//  ## 文件作用
//  协调相机、运动传感器和 AI 检测模块
//  管理整个智能拍摄流程的状态机
//  为 CaptureView 提供所有业务逻辑和状态
//
//  ## 主要类
//  ### CaptureViewModel
//  拍摄功能视图模型（ObservableObject）
//
//  ## Dependencies（依赖项）
//  - camera: CameraManager - 相机管理器
//  - motion: MotionStabilityMonitor - 运动监控器
//  - aestheticDetector: AestheticCropDetector - 美学检测器
//  - boxCenterManager: BoxCenterManager - 追踪点管理器
//
//  ## Published 状态
//  - cropRectInView: CGRect? - 当前裁切框位置
//  - initialCropRectInView: CGRect? - 初始检测的裁切框
//  - compositionRectInView: CGRect - 构图区域
//  - isAligned: Bool - 是否对齐中心
//  - debugMessage: String - 调试信息
//  - pipelineStage: PipelineStage - 当前流程阶段
//  - distanceToCenter: CGFloat? - 到中心的距离
//  - detectionReady: Bool - 检测是否就绪
//  - motionIsStable: Bool - 设备是否稳定
//  - zoomState/zoomPresets/zoomRange - 变焦相关状态
//  - userGuidanceText: String - 用户引导文字
//  - isAutoCaptureEnabled: Bool - 是否启用自动拍照
//  - captureDelay: Double - 拍照延迟（秒）
//  - isSwitchingCamera: Bool - 是否正在切换摄像头
//
//  ## 计算属性
//  - baseBoxCenterInView: CGPoint? - 基准中心点
//  - boxCenterInView: CGPoint? - 当前中心点
//  - adjustedCropRectInView: CGRect? - 调整后的裁切框
//  - zoomDisplayText: String - 变焦显示文本
//  - focalLengthText: String - 焦距显示文本
//  - session: AVCaptureSession - 相机会话
//
//  ## 主要方法
//
//  ### 生命周期
//  - init(): 初始化依赖和绑定
//  - onAppear(): 视图出现时启动相机和传感器
//  - onDisappear(): 视图消失时停止所有服务
//
//  ### 相机控制
//  - capturePhoto(): 触发拍照
//  - toggleCameraPosition(): 切换前后摄像头
//    包含翻转动画和状态重置
//
//  ### 变焦控制
//  - selectZoomPreset(_:): 选择变焦预设
//  - updateZoomInteractively(to:): 交互式变焦
//  - finalizeZoomInteractively(at:smooth:): 完成交互式变焦
//
//  ### 状态管理
//  - registerCompositionRect(_:): 注册构图区域尺寸
//  - resetDetectionState(): 重置所有检测状态
//  - toggleAutoCapture(): 切换自动拍照开关
//  - setCaptureDelay(_:): 设置拍照延迟
//
//  ### 其他功能
//  - openSystemPhotoLibrary(): 打开系统相册
//
//  ## 私有方法
//
//  ### 绑定
//  - bindMotion(): 绑定运动传感器事件
//    - 订阅 deviceMotion 更新追踪点
//    - 订阅 isStable 控制检测流程
//    - 订阅 largeMotionDetected 自动重置
//
//  - bindCamera(): 绑定相机事件
//    - 订阅 lastPhotoSaved 显示保存结果
//    - 订阅 zoomState 更新变焦显示
//    - 订阅 zoomPresets/zoomRange
//
//  ### 处理流程
//  - setupCallbacks(): 设置相机帧回调
//  - handleSampleBuffer(_:): 处理视频帧
//    - 等待稳定
//    - 触发 AI 检测
//    - 传递给检测管线
//
//  - detectCropRegion(using:orientation:): 执行裁切区域检测
//    - 调用 AestheticCropDetector
//    - 转换坐标到视图空间
//    - 设置基准中心点
//    - 锁定参考姿态
//
//  ### 自动拍照
//  - scheduleAutoCapture(): 调度自动拍照任务
//    在对齐后延迟执行
//
//  - cancelAutoCapture(): 取消自动拍照任务
//
//  ### 对齐检测
//  - checkAlignmentByDistance(): 检查距离对齐
//    - 调用 BoxCenterManager 检测
//    - 对齐时触发自动拍照
//    - 失去对齐时取消拍照
//
//  ### 状态控制
//  - setStage(_:message:): 设置流程阶段
//    - 更新 pipelineStage
//    - 更新 debugMessage
//    - 更新 userGuidanceText
//    - 线程安全
//
//  ### 几何转换
//  - makeCompositionPixelBuffer(from:orientation:): 
//    创建 3:4 构图像素缓冲
//
//  - pixelOrientation(for:): 判断像素缓冲方向
//
//  - rotateNormalizedRect(_:for:): 旋转归一化矩形
//
//  - rectInCompositionSpace(from:orientation:): 
//    转换检测框到视图坐标系
//
//  ## 流程状态机（PipelineStage）
//  - idle: 空闲
//  - startingCamera: 启动相机
//  - waitingForStability: 等待稳定
//  - detectingRegion: 检测区域
//  - templateReady: 模板就绪（追踪中）
//  - readyToCapture: 准备拍照
//  - capturingPhoto: 正在拍照
//  - savingPhoto: 保存照片
//  - error: 错误
//
//  每个阶段有对应的：
//  - progress: Double - 进度值
//  - guidanceText: String - 引导文字
//
//  ## 线程处理
//  - 视频帧在 videoOutputQueue 处理
//  - AI 检测在专用队列异步执行
//  - UI 状态更新确保在主线程
//  - 使用 Combine 管理异步事件流
//
//  ## 性能优化
//  - detectionInProgress 标志避免重复检测
//  - 使用 static ciContext 共享 Core Image 上下文
//  - 帧处理前检查稳定性减少无效计算
//

import Foundation
import Combine
import AVFoundation
import CoreImage
import CoreMotion

#if os(iOS)
import SwiftUI

/// 拍摄功能的视图模型
final class CaptureViewModel: ObservableObject {
	// MARK: - Dependencies
	
	private(set) var camera = CameraManager()
	private let motion = MotionStabilityMonitor()
	private let aestheticDetector = AestheticCropDetector()
	private let boxCenterManager = BoxCenterManager()
	
	// MARK: - Published State
	
	@Published private(set) var cropRectInView: CGRect?
	@Published private(set) var initialCropRectInView: CGRect?
	@Published private(set) var compositionRectInView: CGRect = .zero
	@Published private(set) var isAligned: Bool = false
	@Published private(set) var debugMessage: String = "等待相机启动..."
	@Published private(set) var pipelineStage: PipelineStage = .idle
	@Published private(set) var distanceToCenter: CGFloat?
	@Published private(set) var detectionReady: Bool = false
	@Published private(set) var motionIsStable: Bool = false
	@Published private(set) var zoomState: CameraManager.ZoomState
	@Published private(set) var zoomPresets: [CameraManager.ZoomPreset]
	@Published private(set) var zoomRange: ClosedRange<CGFloat>
	@Published private(set) var userGuidanceText: String = ""
	@Published var isAutoCaptureEnabled: Bool = true
	@Published var captureDelay: Double = 1.0
	@Published var isSwitchingCamera: Bool = false
	
	var onCaptureTriggered: (() -> Void)?
	
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
	
	var session: AVCaptureSession { camera.session }
	
	// MARK: - Private State
	
	private static let ciContext = CIContext()
	private let alignmentTolerance: CGFloat = 15.0
	private var detectionInProgress: Bool = false
	private var cancellables: Set<AnyCancellable> = []
	private var autoCaptureWorkItem: DispatchWorkItem?
	
	// MARK: - Lifecycle
	
	init() {
		zoomState = camera.zoomState
		zoomPresets = camera.zoomPresets
		zoomRange = camera.zoomRange
		
		// 初始化前置摄像头状态
		boxCenterManager.setFrontCamera(camera.currentPosition == .front)
		
		bindMotion()
		bindCamera()
	}
	
	deinit {
		autoCaptureWorkItem?.cancel()
	}
	
	// MARK: - Public API
	
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
		boxCenterManager.updateCompositionRect(rect)
	}
	
	func capturePhoto() {
		camera.capturePhoto()
	}
	
	func selectZoomPreset(_ preset: CameraManager.ZoomPreset) {
		camera.selectZoomPreset(preset)
	}
	
	func updateZoomInteractively(to factor: CGFloat) {
		camera.updateInteractiveZoom(to: factor)
	}
	
	func finalizeZoomInteractively(at factor: CGFloat, smooth: Bool) {
		camera.finalizeInteractiveZoom(at: factor, smooth: smooth)
	}
	
	func toggleCameraPosition() {
		isSwitchingCamera = true
		resetDetectionState()
		camera.toggleCameraPosition()
		
		// 更新前置摄像头状态到 BoxCenterManager
		let isFront = camera.currentPosition == .front
		boxCenterManager.setFrontCamera(isFront)
		
		setStage(.waitingForStability, message: "切换镜头，等待稳定")
		
		// 切换动画完成后重置标志
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			self.isSwitchingCamera = false
		}
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
	
	func toggleAutoCapture() {
		isAutoCaptureEnabled.toggle()
	}
	
	func setCaptureDelay(_ delay: Double) {
		captureDelay = delay
	}
	
	// MARK: - Bindings
	
	private func bindMotion() {
		motion.$deviceMotion
			.receive(on: DispatchQueue.main)
			.sink { [weak self] motion in
				guard let self else { return }
				self.boxCenterManager.updateCenter(with: motion)
				
				self.distanceToCenter = self.boxCenterManager.distanceToCenter()
				
				if let adjusted = self.adjustedCropRectInView {
					self.cropRectInView = adjusted
				}
				
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
				if !stable && !self.detectionReady {
					self.setStage(.waitingForStability, message: "等待设备稳定...")
				}
			}
			.store(in: &cancellables)
		
		motion.$largeMotionDetected
			.receive(on: DispatchQueue.main)
			.sink { [weak self] detected in
				guard let self, detected, self.detectionReady else { return }
				// 检测到大幅度运动时自动重置状态
				HapticManager.shared.warning()
				self.resetDetectionState()
			}
			.store(in: &cancellables)
	}
	
	private func bindCamera() {
		camera.$lastPhotoSaved
			.receive(on: DispatchQueue.main)
			.sink { [weak self] saved in
				guard let self, saved else { return }
				HapticManager.shared.success()
				self.setStage(.savingPhoto, message: "照片已保存到相册")
				// 3秒后自动重置到等待稳定状态
				DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
					if self.pipelineStage == .savingPhoto {
						self.resetDetectionState()
					}
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
		
		guard let compositionPixel = makeCompositionPixelBuffer(from: rawPixel, orientation: orientation) else {
			DispatchQueue.main.async {
				self.setStage(.error, message: "无法处理画面")
			}
			return
		}
		
		if !detectionReady && !detectionInProgress {
			DispatchQueue.main.async {
				self.setStage(.detectingRegion, message: "设备已稳定，开始识别目标区域...")
				self.detectionInProgress = true
			}
			detectCropRegion(using: compositionPixel, orientation: orientation)
		}
	}
	
	private func detectCropRegion(using pixel: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
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
						with: self.motion.deviceMotion?.attitude
					)
					self.motion.lockReferenceAttitude()
					
					self.detectionReady = true
					HapticManager.shared.success()
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
	
	private func scheduleAutoCapture() {
		guard isAutoCaptureEnabled else { return }
		
		autoCaptureWorkItem?.cancel()
		setStage(.readyToCapture, message: "对准成功，准备拍照...")
		
		let work = DispatchWorkItem { [weak self] in
			guard let self, self.isAligned else { return }
			self.setStage(.capturingPhoto, message: "正在拍照")
			
			DispatchQueue.main.async {
				self.onCaptureTriggered?()
			}
			
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
				self.capturePhoto()
			}
		}
		autoCaptureWorkItem = work
		DispatchQueue.main.asyncAfter(deadline: .now() + captureDelay, execute: work)
	}
	
	private func cancelAutoCapture() {
		autoCaptureWorkItem?.cancel()
		autoCaptureWorkItem = nil
	}
	
	// MARK: - Alignment Detection
	
	private func checkAlignmentByDistance() {
		let alignedNow = boxCenterManager.isAlignedWithCenter(tolerance: alignmentTolerance)
		
		if alignedNow && !isAligned {
			HapticManager.shared.focusLock()
			scheduleAutoCapture()
		} else if !alignedNow && isAligned {
			HapticManager.shared.warning()
			cancelAutoCapture()
			setStage(.templateReady, message: "请重新对准中心点")
		}
		
		isAligned = alignedNow
	}
	
	private func setStage(_ stage: PipelineStage, message: String? = nil) {
		let applyChange = {
			self.pipelineStage = stage
			if let message {
				self.debugMessage = message
			}
			self.userGuidanceText = stage.guidanceText
		}
		if Thread.isMainThread {
			applyChange()
		} else {
			DispatchQueue.main.async(execute: applyChange)
		}
	}
	
	// MARK: - Geometry Helpers
	
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
		
		CaptureViewModel.ciContext.render(croppedImage, to: buffer)
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

// MARK: - Pipeline Stage

extension CaptureViewModel {
	enum PipelineStage: Equatable {
		case idle
		case startingCamera
		case waitingForStability
		case detectingRegion
		case templateReady
		case readyToCapture
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
			case .readyToCapture: return 0.92
			case .capturingPhoto: return 0.95
			case .savingPhoto: return 1.0
			case .error: return 0.2
			}
		}
		
		var guidanceText: String {
			switch self {
			case .idle:
				return ""
			case .startingCamera:
				return "正在启动相机"
			case .waitingForStability:
				return "请保持稳定"
			case .detectingRegion:
				return "正在识别最佳构图..."
			case .templateReady:
				return "请将圆点移动到画面中心"
			case .readyToCapture:
				return "即将拍照，请保持稳定"
			case .capturingPhoto:
				return "正在拍照..."
			case .savingPhoto:
				return "照片已保存"
			case .error:
				return "发生错误，请重试"
			}
		}
	}
}

#endif
