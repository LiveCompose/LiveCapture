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
        guard let device: AVCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
            throw CameraError.cameraUnavailable
        }
        let input: AVCaptureDeviceInput = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
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
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: nextPosition) else { return }
            do {
                let newInput = try AVCaptureDeviceInput(device: device)
                self.session.beginConfiguration()
                let videoInputs = self.session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
                for input in videoInputs where input.device.hasMediaType(.video) {
                    self.session.removeInput(input)
                }
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.currentPosition = nextPosition
                } else {
                    for input in videoInputs {
                        self.session.addInput(input)
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
