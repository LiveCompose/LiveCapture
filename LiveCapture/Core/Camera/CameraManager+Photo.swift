//
//  CameraManager+Photo.swift
//  LiveCapture
//
//  照片捕获和保存扩展
//
//  ## 文件作用
//  实现静态照片的拍摄、处理和保存到相册功能
//  处理照片质量设置、闪光灯配置和防抖选项
//
//  ## 协议实现
//  - AVCapturePhotoCaptureDelegate: 处理照片捕获回调
//
//  ## 主要方法
//
//  ### 照片捕获
//  - capturePhoto(): 触发一次静态照片拍摄
//    功能:
//      - 配置闪光灯模式（自动）
//      - 启用高分辨率照片
//      - 启用静态照片防抖（如果支持）
//      - 设置最佳照片质量优先级
//
//  ### 照片保存
//  - savePhotoDataToLibrary(_:): 将 JPEG 数据保存到照片库
//    参数: data - Data JPEG 格式的照片数据
//    功能:
//      - 请求照片库添加权限
//      - 使用 PHAssetCreationRequest 创建资源
//      - 更新 lastPhotoSaved 状态通知 UI
//
//  ### 代理回调
//  - photoOutput(_:didFinishProcessingPhoto:error:): 照片处理完成回调
//    参数:
//      - output: AVCapturePhotoOutput
//      - photo: AVCapturePhoto 捕获的照片对象
//      - error: Error? 可能的错误
//    功能:
//      - 获取照片的 JPEG 数据
//      - 调用保存方法写入相册
//      - 错误处理和日志记录
//
//  ## 照片处理流程
//  1. capturePhoto() 发起拍摄请求
//  2. 系统处理并回调 photoOutput(_:didFinishProcessingPhoto:error:)
//  3. 提取 JPEG 数据
//  4. savePhotoDataToLibrary() 保存到相册
//  5. 更新 @Published lastPhotoSaved 状态
//
//  ## 权限处理
//  - 使用 PHPhotoLibrary.requestAuthorization 请求相册访问权限
//  - 支持 .authorized 和 .limited 权限状态
//  - 权限拒绝时更新状态为 false
//

import Foundation
import AVFoundation
import Photos
import CoreImage
import ImageIO

#if os(iOS)

extension CameraManager: AVCapturePhotoCaptureDelegate {
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
