//
//  CameraManager+Session.swift
//  LiveCapture
//
//  相机会话管理扩展
//
//  ## 文件作用
//  负责 AVCaptureSession 的配置、启动、停止和摄像头切换
//  处理相机权限检查和设备选择逻辑
//
//  ## 主要方法
//
//  ### 会话配置
//  - checkAndConfigure(completion:): 检查相机权限并配置会话
//    参数: completion - 配置结果回调
//    返回: Result<Void, Error>
//
//  - configureSessionAsync(completion:): 在后台队列异步配置会话
//    参数: completion - 配置结果回调
//
//  - configureSession(): 同步配置会话，设置输入输出和稳定参数
//    抛出: CameraError 如果配置失败
//
//  ### 会话控制
//  - startSession(): 启动相机会话
//  - stopSession(): 停止相机会话
//
//  ### 摄像头切换
//  - toggleCameraPosition(): 在前后摄像头之间切换
//    自动更新输入、配置变焦和旋转
//
//  ### 设备选择
//  - selectInitialDevice(for:): 根据位置选择初始摄像头设备
//    参数: position - AVCaptureDevice.Position (.back/.front)
//    返回: AVCaptureDevice
//    抛出: CameraError.noDeviceFound 如果找不到设备
//
//  - refreshBackCameraCatalog(): 刷新后置摄像头的镜头目录
//    建立不同焦距镜头（超广角、广角、长焦）的映射
//
//  ### 辅助方法
//  - configureStabilization(for:): 配置视频稳定模式
//    参数: connection - AVCaptureConnection
//
//  ## 依赖关系
//  - 依赖 CameraManager 主类的属性和方法
//  - 使用 sessionQueue 确保线程安全
//  - 调用 configureZoomCapabilities 配置变焦能力
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
