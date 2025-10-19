//
//  CameraManager+Session.swift
//  LiveCapture
//
//  Created by GitHub Copilot on 2025/10/13.
//

import Foundation
import AVFoundation

#if os(iOS)

extension CameraManager {
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
    func configureSessionAsync(completion: @escaping (Result<Void, Error>) -> Void) {
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
    func configureSession() throws {
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
}

#endif
