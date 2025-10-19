//
//  CameraManager+VideoOutput.swift
//  LiveCapture
//
//  视频帧输出处理扩展
//
//  ## 文件作用
//  实现视频帧的实时捕获和处理
//  将相机预览帧传递给 AI 检测和追踪管线
//
//  ## 协议实现
//  - AVCaptureVideoDataOutputSampleBufferDelegate: 处理视频帧输出回调
//
//  ## 主要方法
//
//  ### 视频帧回调
//  - captureOutput(_:didOutput:from:): 视频帧输出成功回调
//    参数:
//      - output: AVCaptureOutput 输出对象
//      - sampleBuffer: CMSampleBuffer 包含像素缓冲的样本
//      - connection: AVCaptureConnection 连接对象
//    功能:
//      - 验证输出源为 videoOutput
//      - 提取 CVPixelBuffer 用于调试
//      - 通过 onSampleBuffer 回调传递给上层
//      - 运行在 videoOutputQueue 队列上
//
//  - captureOutput(_:didDrop:from:): 视频帧丢弃回调
//    参数:
//      - output: AVCaptureOutput 输出对象
//      - sampleBuffer: CMSampleBuffer 被丢弃的样本
//      - connection: AVCaptureConnection 连接对象
//    功能:
//      - DEBUG 模式下打印丢帧时间戳
//      - 用于性能调试和优化
//
//  ## 数据流
//  相机设备 → AVCaptureVideoDataOutput → captureOutput 回调 → 
//  onSampleBuffer 闭包 → CaptureViewModel → AI 检测管线
//
//  ## 性能优化
//  - alwaysDiscardsLateVideoFrames = true (在 CameraManager.init)
//  - 使用专用的 videoOutputQueue 处理帧数据
//  - 避免阻塞主线程
//
//  ## 调试支持
//  - lastPixelBuffer 保存最新帧用于调试预览
//  - DEBUG 模式下记录丢帧日志
//

import Foundation
import AVFoundation

#if os(iOS)

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// 视频帧输出回调，将稳定后的画面传递给上层管线。
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard output === videoOutput else { return }
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            lastPixelBuffer = pixelBuffer
        }
        onSampleBuffer?(sampleBuffer)
    }

    /// 处理捕获失败的情况，打印日志便于调试。
    func captureOutput(_ output: AVCaptureOutput,
                       didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        #if DEBUG
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        print("视频帧丢弃: t=\(String(format: "%.3f", time))")
        #endif
    }
}

#endif
