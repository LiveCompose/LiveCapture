//
//  CameraManager.swift
//  LiveCapture
//
//  Manages AVCaptureSession, video frames, and still photo capture.
//

import Foundation
import Combine
import AVFoundation
import Photos
import CoreImage
import ImageIO

#if os(iOS)

/// 管理相机会话、帧输出与照片写入相册的核心控制器。
final class CameraManager: NSObject, ObservableObject {
    /// 明确控制对象更新的信号，便于手动触发 UI 刷新。
    let objectWillChange: PassthroughSubject<Void, Never> = PassthroughSubject<Void, Never>()

    /// 枚举当前可用的镜头类型，便于描述 UI 与硬件的映射关系。
    enum LensKind: String, CaseIterable, Identifiable {
        case ultraWide
        case wide
        case telephoto
        case front

        var id: String { rawValue }

        /// 以 iOS 默认焦段为参考给出大致焦距，用于 UI 展示。
        var approximateFocalLength: Int {
            switch self {
            case .ultraWide: return 13
            case .wide: return 24
            case .telephoto: return 77
            case .front: return 24
            }
        }

        /// 对应的默认变焦倍率。
        var opticalZoomFactor: CGFloat {
            switch self {
            case .ultraWide: return 0.5
            case .wide: return 1.0
            case .telephoto: return 3.0
            case .front: return 1.0
            }
        }

        var displayName: String {
            switch self {
            case .ultraWide: return "0.5×"
            case .wide: return "1×"
            case .telephoto: return "3×"
            case .front: return "1×"
            }
        }
    }

    /// 变焦环所需的离散预设点描述。
    struct ZoomPreset: Identifiable, Hashable {
        enum Style {
            case primary // 用于突出当前镜头（例如 1×）
            case secondary
        }

        let id = UUID()
        let lens: LensKind
        let zoomFactor: CGFloat
        let focalLength: Int
        let style: Style

        var label: String {
            let rounded = (zoomFactor * 10).rounded() / 10
            if abs(Double(rounded) - Double(Int(rounded))) < 0.001 {
                return "\(Int(rounded))×"
            } else {
                return String(format: "%.1f×", rounded)
            }
        }
        var focalLengthLabel: String { "\(focalLength)mm" }
    }

    /// 保持实时变焦状态，供 UI 绑定。
    struct ZoomState: Equatable {
        var currentFactor: CGFloat
        var displayedFactor: CGFloat
        var focalLength: Int
        var activeLens: LensKind
        var isContinuous: Bool
    }
    /// 相机可抛出的错误类型，用于向上层反馈具体失败原因。
    enum CameraError: Error {
        case cameraUnavailable
        case cannotAddInput
        case cannotAddOutput
        case photoDataMissing
        case saveFailed
        case notAuthorized
    }

    /// 会话是否正在运行，用于驱动 UI 状态。
    @Published var isSessionRunning: Bool = false
    /// 最近一次拍照是否保存成功。
    @Published var lastPhotoSaved: Bool = false
    /// 当前相机变焦状态。
    @Published private(set) var zoomState: ZoomState = ZoomState(currentFactor: 1.0,
                                                                 displayedFactor: 1.0,
                                                                 focalLength: LensKind.wide.approximateFocalLength,
                                                                 activeLens: .wide,
                                                                 isContinuous: false)
    /// 当前可用的离散预设列表。
    @Published private(set) var zoomPresets: [ZoomPreset] = []
    /// 当前设备支持的连续变焦范围。
    @Published private(set) var zoomRange: ClosedRange<CGFloat> = 1.0...1.0
    /// 面向 UI 的镜头切换提示（例如 0.5×→广角）。
    @Published private(set) var availableLenses: [LensKind] = []

    /// 负责捕获视频与照片的 AVCapture 会话对象。
    let session: AVCaptureSession = AVCaptureSession()
    /// 配置会话所使用的串行队列，避免阻塞主线程。
    private let sessionQueue: DispatchQueue = DispatchQueue(label: "livecapture.camera.session")
    /// 处理视频帧输出的队列。
    private let videoOutputQueue: DispatchQueue = DispatchQueue(label: "livecapture.camera.videoOutput")

    private let photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()
    private let videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    /// Core Image 上下文，用于执行 3:4 裁剪与编码。
    private let photoContext = CIContext() // 用于将原始照片裁剪为 3:4，并重新编码为 JPEG
    private var currentPosition: AVCaptureDevice.Position = .back
    private var activeVideoDevice: AVCaptureDevice?
    private var activeVideoInput: AVCaptureDeviceInput?
    private var backCameraCatalog: [LensKind: AVCaptureDevice] = [:]
    private var virtualDeviceSwitchPoints: [CGFloat] = []

    /// 视频帧到达时的回调，运行在 `videoOutputQueue` 上。
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    /// 最新的像素缓冲，仅用于调试预览。
    private(set) var lastPixelBuffer: CVPixelBuffer? = nil

    /// 初始化会话预设与视频输出 delegate。
    override init() {
        super.init()
        session.sessionPreset = .photo
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
    }

    /// 检查权限并在授权后配置会话。
    func checkAndConfigure(completion: @escaping (Result<Void, Error>) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSessionAsync(completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.configureSessionAsync(completion: completion)
                } else {
                    completion(.failure(CameraError.notAuthorized))
                }
            }
        default:
            completion(.failure(CameraError.notAuthorized))
        }
    }

    /// 异步串行地配置会话，避免阻塞调用线程。
    private func configureSessionAsync(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            do {
                try self.configureSession()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// 设置会话输入输出与稳定参数，失败时抛出自定义错误。
    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Input
        let device: AVCaptureDevice = try selectInitialDevice(for: currentPosition)
        let input: AVCaptureDeviceInput = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
            activeVideoDevice = device
            activeVideoInput = input
            configureZoomCapabilities(for: device, position: currentPosition)
        } else {
            throw CameraError.cannotAddInput
        }

        // Photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            if photoOutput.isHighResolutionCaptureEnabled == false {
                photoOutput.isHighResolutionCaptureEnabled = true
            }
        } else {
            throw CameraError.cannotAddOutput
        }

        // Video output for AI/tracking
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            if let connection: AVCaptureConnection = videoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                configureStabilization(for: connection)
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = currentPosition == .front
                }
            }
        } else {
            throw CameraError.cannotAddOutput
        }
    }

    /// 启动捕获会话，如果已运行则忽略。
    func startSession() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isSessionRunning = true }
        }
    }

    /// 停止捕获会话，并回写运行状态。
    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

    /// 在前后摄像头之间切换。
    func toggleCameraPosition() {
        sessionQueue.async {
            let nextPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            do {
                let device = try self.selectInitialDevice(for: nextPosition)
                let newInput = try AVCaptureDeviceInput(device: device)
                self.session.beginConfiguration()
                if let active = self.activeVideoInput {
                    self.session.removeInput(active)
                } else {
                    let existingInputs = self.session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
                    for input in existingInputs where input.device.hasMediaType(.video) {
                        self.session.removeInput(input)
                    }
                }
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.activeVideoInput = newInput
                    self.activeVideoDevice = device
                    self.currentPosition = nextPosition
                    self.configureZoomCapabilities(for: device, position: nextPosition)
                    let baseFactor = nextPosition == .front ? 1.0 : max(CGFloat(device.minAvailableVideoZoomFactor), 0.5)
                    self.refreshZoomState(with: baseFactor, isContinuous: false)
                } else {
                    if let active = self.activeVideoInput {
                        self.session.addInput(active)
                    }
                    self.session.commitConfiguration()
                    return
                }
                self.session.commitConfiguration()
                if let connection = self.videoOutput.connection(with: .video) {
                    if connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }
                    self.configureStabilization(for: connection)
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = nextPosition == .front
                    }
                }
            } catch {
                return
            }
        }
    }

    /// 点按预设快捷按钮触发的变焦请求。
    func selectZoomPreset(_ preset: ZoomPreset) {
        sessionQueue.async {
            self.applyZoomFactor(preset.zoomFactor, animated: true, isContinuous: false)
        }
    }

    /// 拖动过程中实时更新变焦倍率。
    func updateInteractiveZoom(to factor: CGFloat) {
        sessionQueue.async {
            self.applyZoomFactor(factor, animated: false, isContinuous: true)
        }
    }

    /// 拖动结束后锁定最终倍率，可选平滑过渡。
    func finalizeInteractiveZoom(at factor: CGFloat, smooth: Bool) {
        sessionQueue.async {
            self.applyZoomFactor(factor, animated: smooth, isContinuous: false)
        }
    }

    /// 触发一次静态照片捕获，并根据硬件能力配置参数。
    func capturePhoto() {
        let settings: AVCapturePhotoSettings = AVCapturePhotoSettings()
        if self.photoOutput.supportedFlashModes.contains(.auto) {
            settings.flashMode = .auto
        }
        settings.isHighResolutionPhotoEnabled = true
        if photoOutput.isStillImageStabilizationSupported {
            settings.isAutoStillImageStabilizationEnabled = true
        }
        if #available(iOS 16.0, tvOS 16.0, *) {
            // 将优先级设为设备支持的最大值，避免超范围导致崩溃
            settings.photoQualityPrioritization = self.photoOutput.maxPhotoQualityPrioritization
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    /// 将 JPEG 数据写入照片图库，授权失败时更新发布状态。
    private func savePhotoDataToLibrary(_ data: Data) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { self.lastPhotoSaved = false }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let creationRequest: PHAssetCreationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: data, options: nil)
            }) { success, _ in
                DispatchQueue.main.async { self.lastPhotoSaved = success }
            }
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    /// 处理拍照结果，将数据转换为 JPEG 并保存相册。
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error: any Error = error {
            print("Photo processing error: \(error)")
            DispatchQueue.main.async { self.lastPhotoSaved = false }
            return
        }
        guard let data: Data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { self.lastPhotoSaved = false }
            return
        }
        // 优先生成 3:4 裁剪后的 JPEG，失败时退回原始数据
        if let processed = processPhotoData(photo: photo, originalData: data) {
            savePhotoDataToLibrary(processed)
        } else {
            savePhotoDataToLibrary(data)
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// 接收连续视频帧，缓存最新像素缓冲并触发回调。
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) {
            self.lastPixelBuffer = pixel
        }
        onSampleBuffer?(sampleBuffer)
    }
}

private extension CameraManager {
    /// 根据相机位置挑选适合的物理摄像头设备。
    func selectInitialDevice(for position: AVCaptureDevice.Position) throws -> AVCaptureDevice {
        switch position {
        case .back:
            refreshBackCameraCatalog()
            if let multi = backCameraCatalog[.wide] {
                return multi
            }
            if let fallback = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                backCameraCatalog[.wide] = fallback
                return fallback
            }
            throw CameraError.cameraUnavailable
        case .front:
            // 优先选择 TrueDepth，其次普通前置。
            if let depth = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) {
                return depth
            }
            if let standard = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                return standard
            }
            throw CameraError.cameraUnavailable
        default:
            throw CameraError.cameraUnavailable
        }
    }

    /// 更新后置摄像头目录缓存，识别可用镜头类别。
    func refreshBackCameraCatalog() {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes,
                                                         mediaType: .video,
                                                         position: .back)
        var catalog: [LensKind: AVCaptureDevice] = [:]
        for device in discovery.devices {
            switch device.deviceType {
            case .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera:
                catalog[.wide] = device
            case .builtInUltraWideCamera:
                catalog[.ultraWide] = device
            case .builtInTelephotoCamera:
                catalog[.telephoto] = device
            case .builtInWideAngleCamera:
                if catalog[.wide] == nil {
                    catalog[.wide] = device
                }
            default:
                continue
            }
        }
        backCameraCatalog = catalog
    }

    /// 读取硬件变焦能力并刷新预设、镜头列表与状态。
    func configureZoomCapabilities(for device: AVCaptureDevice, position: AVCaptureDevice.Position) {
        let minFactor = max(CGFloat(device.minAvailableVideoZoomFactor), 0.35)
        let maxFactor = CGFloat(device.maxAvailableVideoZoomFactor)
        let switchPoints = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }.sorted()
        virtualDeviceSwitchPoints = switchPoints

        let lenses: [LensKind]
        if position == .front {
            lenses = [.front]
        } else {
            let constituents = device.constituentDevices
            var kinds: Set<LensKind> = []
            for sub in constituents {
                switch sub.deviceType {
                case .builtInUltraWideCamera:
                    kinds.insert(.ultraWide)
                case .builtInTelephotoCamera:
                    kinds.insert(.telephoto)
                default:
                    kinds.insert(.wide)
                }
            }
            if kinds.isEmpty {
                kinds.insert(.wide)
            }
            lenses = kinds.sorted { lensOrder(lhs: $0, rhs: $1) }
        }

        let presets = buildZoomPresets(range: minFactor...maxFactor, lenses: lenses)
        DispatchQueue.main.async {
            self.zoomRange = minFactor...maxFactor
            self.availableLenses = lenses
            self.zoomPresets = presets
            self.refreshZoomState(with: max(minFactor, self.zoomState.currentFactor),
                                  isContinuous: false)
        }
    }

    /// 基于支持范围与镜头集合构建变焦预设列表。
    func buildZoomPresets(range: ClosedRange<CGFloat>, lenses: [LensKind]) -> [ZoomPreset] {
        guard !lenses.isEmpty else { return [] }

        var presets: [ZoomPreset] = []
        /// 将符合条件的变焦预设加入结果集合。
        func append(lens: LensKind, factor: CGFloat, style: ZoomPreset.Style) {
            guard range.contains(factor) else { return }
            let focal = estimateFocalLength(for: factor, lens: lens)
            let preset = ZoomPreset(lens: lens,
                                    zoomFactor: factor,
                                    focalLength: focal,
                                    style: style)
            if !presets.contains(where: { abs($0.zoomFactor - factor) < 0.01 }) {
                presets.append(preset)
            }
        }

        if lenses.contains(.ultraWide) {
            append(lens: .ultraWide, factor: 0.5, style: .secondary)
        }
        let primaryLens: LensKind = lenses.contains(.front) ? .front : .wide
        append(lens: primaryLens, factor: 1.0, style: .primary)
        if range.contains(1.5) && !lenses.contains(.telephoto) && primaryLens != .front {
            append(lens: primaryLens, factor: 1.5, style: .secondary)
        }
        if lenses.contains(.telephoto) {
            append(lens: .telephoto, factor: 3.0, style: .secondary)
            if range.contains(5.0) {
                append(lens: .telephoto, factor: 5.0, style: .secondary)
            }
        } else if range.contains(2.0) && primaryLens != .front {
            append(lens: primaryLens, factor: 2.0, style: .secondary)
        }

        return presets.sorted { $0.zoomFactor < $1.zoomFactor }
    }

    /// 为镜头类型提供排序规则，便于稳定展示。
    func lensOrder(lhs: LensKind, rhs: LensKind) -> Bool {
        let ranking: [LensKind] = [.ultraWide, .wide, .telephoto, .front]
        return ranking.firstIndex(of: lhs) ?? 0 < ranking.firstIndex(of: rhs) ?? 0
    }

    /// 估算给定变焦倍率与镜头对应的等效焦距。
    func estimateFocalLength(for factor: CGFloat, lens: LensKind) -> Int {
        let base: Double = 24.0
        let precise = Double(factor) * base
        switch lens {
        case .ultraWide, .front:
            return max(10, Int(round(precise)))
        case .wide:
            return Int(round(precise))
        case .telephoto:
            // 使用更接近长焦原生焦段的预设
            let optical = Double(lens.approximateFocalLength)
            if abs(precise - optical) < 8 {
                return Int(round(optical))
            }
            return Int(round(precise))
        }
    }

    /// 根据最新变焦结果刷新发布的状态模型。
    func refreshZoomState(with factor: CGFloat, isContinuous: Bool) {
        let clamped = clampZoom(factor)
        let lens = currentLensKind(for: clamped)
        let focal = estimateFocalLength(for: clamped, lens: lens)
        let display = (clamped * 100).rounded() / 100
        let state = ZoomState(currentFactor: clamped,
                              displayedFactor: display,
                              focalLength: focal,
                              activeLens: lens,
                              isContinuous: isContinuous)
        if Thread.isMainThread {
            zoomState = state
        } else {
            DispatchQueue.main.async { self.zoomState = state }
        }
    }

    /// 将目标变焦倍率限制在硬件支持的区间内。
    func clampZoom(_ factor: CGFloat) -> CGFloat {
        let lower = zoomRange.lowerBound
        let upper = 10.0
        return min(max(factor, lower), upper)
    }

    /// 根据变焦倍率推断当前使用的镜头类型。
    func currentLensKind(for factor: CGFloat) -> LensKind {
        if currentPosition == .front {
            return .front
        }
        let sortedLenses = availableLenses.sorted { lensOrder(lhs: $0, rhs: $1) }
        guard sortedLenses.count > 1 else {
            return sortedLenses.first ?? .wide
        }
        if virtualDeviceSwitchPoints.count == sortedLenses.count - 1 {
            for (idx, point) in virtualDeviceSwitchPoints.enumerated() {
                if factor < point {
                    return sortedLenses[idx]
                }
            }
            return sortedLenses.last ?? .wide
        } else {
            if sortedLenses.contains(.ultraWide) && factor < 0.9 {
                return .ultraWide
            }
            if sortedLenses.contains(.telephoto) && factor > 2.4 {
                return .telephoto
            }
            return .wide
        }
    }

    /// 根据目标倍率挑选平滑过渡的变焦速率。
    func optimalRampRate(for factor: CGFloat) -> Float {
        if factor < 1.0 {
            return 5.0
        } else if factor > 3.0 {
            return 10.0
        } else {
            return 8.0
        }
    }

    /// 执行变焦倍率的应用逻辑，支持动画与状态回写。
    func applyZoomFactor(_ factor: CGFloat, animated: Bool, isContinuous: Bool) {
        let target = clampZoom(factor)
        guard let device = activeVideoDevice else {
            refreshZoomState(with: target, isContinuous: isContinuous)
            return
        }

        do {
            try device.lockForConfiguration()
            if animated {
                let rate = optimalRampRate(for: target)
                device.ramp(toVideoZoomFactor: target, withRate: rate)
            } else {
                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }
                device.videoZoomFactor = target
            }
            device.unlockForConfiguration()
        } catch {
            DispatchQueue.main.async {
                self.zoomState = ZoomState(currentFactor: target,
                                            displayedFactor: (target * 100).rounded() / 100,
                                            focalLength: self.estimateFocalLength(for: target, lens: self.currentLensKind(for: target)),
                                            activeLens: self.currentLensKind(for: target),
                                            isContinuous: isContinuous)
            }
            return
        }

        refreshZoomState(with: target, isContinuous: isContinuous)
    }

    /// 根据平台能力启用视频防抖。
    func configureStabilization(for connection: AVCaptureConnection) {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard connection.isVideoStabilizationSupported else { return }
        guard #available(iOS 13.0, *) else {
            connection.preferredVideoStabilizationMode = .auto
            return
        }
        #endif
    }

    /// 将原始像素缓冲裁剪到 3:4，并返回 JPEG 数据。
    func processPhotoData(photo: AVCapturePhoto, originalData: Data) -> Data? {
        // 使用原始 pixelBuffer 进行居中裁剪，保证最终照片为 3:4
        guard let pixelBuffer = photo.pixelBuffer,
              let croppedBuffer = cropPixelBufferToThreeByFour(pixelBuffer,
                                                               orientation: photoOrientation(from: photo)),
              let jpegData = jpegData(from: croppedBuffer) else {
            return nil
        }
        return jpegData
    }

    /// 将像素缓冲旋正后裁剪成 3:4，保持中心内容。
    func cropPixelBufferToThreeByFour(_ pixelBuffer: CVPixelBuffer,
                                      orientation: CGImagePropertyOrientation) -> CVPixelBuffer? {
        // 先旋正，再按照 3:4 长宽比从中心裁剪
        let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        let extent = oriented.extent
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

        let cropped = oriented.cropped(to: cropRect)

        var output: CVPixelBuffer?
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
                                         &output)
        guard status == kCVReturnSuccess, let buffer = output else { return nil }

        photoContext.render(cropped, to: buffer)
        return buffer
    }

    /// 使用 Core Image 将像素缓冲编码为 JPEG 数据。
    func jpegData(from pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return photoContext.jpegRepresentation(of: ciImage, colorSpace: colorSpace, options: [:])
    }

    /// 从照片元数据推断图像方向，缺失时默认竖屏。
    func photoOrientation(from photo: AVCapturePhoto) -> CGImagePropertyOrientation {
        // 如果 metadata 中缺失方向，则默认按照竖屏进行处理
        if let value = photo.metadata[kCGImagePropertyOrientation as String] as? UInt32,
           let orientation = CGImagePropertyOrientation(rawValue: value) {
            return orientation
        }
        return .right
    }
}

#endif
