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

final class CameraManager: NSObject, ObservableObject {
    let objectWillChange: PassthroughSubject<Void, Never> = PassthroughSubject<Void, Never>()
    enum CameraError: Error {
        case cameraUnavailable
        case cannotAddInput
        case cannotAddOutput
        case photoDataMissing
        case saveFailed
        case notAuthorized
    }

    @Published var isSessionRunning: Bool = false
    @Published var lastPhotoSaved: Bool = false

    let session: AVCaptureSession = AVCaptureSession()
    private let sessionQueue: DispatchQueue = DispatchQueue(label: "livecapture.camera.session")
    private let videoOutputQueue: DispatchQueue = DispatchQueue(label: "livecapture.camera.videoOutput")

    private let photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()
    private let videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    private let photoContext = CIContext() // 用于将原始照片裁剪为 3:4，并重新编码为 JPEG

    // Called on videoOutputQueue
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    // Latest pixel buffer for debug previews (not published)
    private(set) var lastPixelBuffer: CVPixelBuffer? = nil

    override init() {
        super.init()
        session.sessionPreset = .photo
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
    }

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

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Input
        guard let device: AVCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
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
                connection.applyBestVideoStabilizationMode()
            }
        } else {
            throw CameraError.cannotAddOutput
        }
    }

    func startSession() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isSessionRunning = true }
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

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
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) {
            self.lastPixelBuffer = pixel
        }
        onSampleBuffer?(sampleBuffer)
    }
}

private extension CameraManager {
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

    func jpegData(from pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return photoContext.jpegRepresentation(of: ciImage, colorSpace: colorSpace, options: [:])
    }

    func photoOrientation(from photo: AVCapturePhoto) -> CGImagePropertyOrientation {
        // 如果 metadata 中缺失方向，则默认按照竖屏进行处理
        if let value = photo.metadata[kCGImagePropertyOrientation as String] as? UInt32,
           let orientation = CGImagePropertyOrientation(rawValue: value) {
            return orientation
        }
        return .right
    }
}
