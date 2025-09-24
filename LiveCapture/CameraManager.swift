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

    // Called on videoOutputQueue
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    override init() {
        super.init()
        session.sessionPreset = .high
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
        savePhotoDataToLibrary(data)
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onSampleBuffer?(sampleBuffer)
    }
}


