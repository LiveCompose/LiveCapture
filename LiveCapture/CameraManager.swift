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
    let sessionQueue: DispatchQueue = DispatchQueue(label: "livecapture.camera.session")
    /// 处理视频帧输出的队列。
    let videoOutputQueue: DispatchQueue = DispatchQueue(label: "livecapture.camera.videoOutput")

    let photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()
    let videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    /// Core Image 上下文，用于执行 3:4 裁剪与编码。
    let photoContext = CIContext() // 用于将原始照片裁剪为 3:4，并重新编码为 JPEG
    var currentPosition: AVCaptureDevice.Position = .back
    var activeVideoDevice: AVCaptureDevice?
    var activeVideoInput: AVCaptureDeviceInput?
    var backCameraCatalog: [LensKind: AVCaptureDevice] = [:]
    var virtualDeviceSwitchPoints: [CGFloat] = []

    /// 视频帧到达时的回调，运行在 `videoOutputQueue` 上。
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    /// 最新的像素缓冲，仅用于调试预览。
    internal(set) var lastPixelBuffer: CVPixelBuffer? = nil

    /// 初始化会话预设与视频输出 delegate。
    override init() {
        super.init()
        session.sessionPreset = .photo
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
    }

    /// 在主线程上更新变焦相关的发布属性，供扩展统一调用。
    func applyZoomConfiguration(range: ClosedRange<CGFloat>,
                                 lenses: [LensKind],
                                 presets: [ZoomPreset],
                                 targetFactor: CGFloat,
                                 isContinuous: Bool) {
        let updateBlock = {
            self.zoomRange = range
            self.availableLenses = lenses
            self.zoomPresets = presets
            self.refreshZoomState(with: targetFactor, isContinuous: isContinuous)
        }

        if Thread.isMainThread {
            updateBlock()
        } else {
            DispatchQueue.main.async(execute: updateBlock)
        }
    }

    /// 更新变焦状态模型，确保 setter 在类作用域内访问。
    func updateZoomState(_ state: ZoomState) {
        if Thread.isMainThread {
            zoomState = state
        } else {
            DispatchQueue.main.async {
                self.zoomState = state
            }
        }
    }
}

#endif
