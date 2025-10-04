//
//  CameraPreviewView.swift
//  LiveCapture
//
//  SwiftUI wrapper for AVCaptureVideoPreviewLayer
//

import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit

/// SwiftUI 封装的摄像头预览视图，使用 UIViewRepresentable
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession // 摄像头会话

    /// 创建并配置预览 UIView
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session // 绑定会话
        view.videoPreviewLayer.videoGravity = .resizeAspectFill // 填充模式
        applyStabilizationIfAvailable(on: view.videoPreviewLayer.connection) // 应用防抖
        return view
    }

    /// 更新 UIView，当 SwiftUI 状态变化时调用
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.videoPreviewLayer.session = session // 更新会话
        applyStabilizationIfAvailable(on: uiView.videoPreviewLayer.connection) // 重新应用防抖
    }
}

/// 用于显示 AVCaptureVideoPreviewLayer 的 UIView 子类
final class PreviewUIView: UIView {
    /// 指定使用 AVCaptureVideoPreviewLayer 作为底层 layer
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    /// 方便访问底层的 AVCaptureVideoPreviewLayer
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

/// 如果支持，应用视频防抖模式
private func applyStabilizationIfAvailable(on connection: AVCaptureConnection?) {
#if os(iOS) && !targetEnvironment(macCatalyst)
    guard let connection, connection.isVideoStabilizationSupported else { return }
    guard #available(iOS 13.0, *) else {
        connection.preferredVideoStabilizationMode = .auto
        return
    }
#endif
}

#endif

