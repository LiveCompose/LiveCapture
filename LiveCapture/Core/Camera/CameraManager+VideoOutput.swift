//
//  CameraManager+VideoOutput.swift
//  LiveCapture
//
//  Created by GitHub Copilot on 2025/10/13.
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
