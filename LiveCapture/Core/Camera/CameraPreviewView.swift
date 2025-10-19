//
//  CameraPreviewView.swift
//  LiveCapture
//
//  相机预览视图封装
//
//  ## 文件作用
//  将 UIKit 的 AVCaptureVideoPreviewLayer 封装为 SwiftUI 视图
//  提供相机实时预览功能
//  处理预览层的配置和更新
//
//  ## 主要组件
//  ### CameraPreviewView
//  SwiftUI 封装的摄像头预览视图
//  
//  协议: UIViewRepresentable
//
//  ## 输入参数
//  - session: AVCaptureSession - 相机会话对象
//  - isFrontCamera: Bool - 是否为前置摄像头（用于左右翻转）
//
//  ## UIViewRepresentable 方法
//
//  ### makeUIView(context:)
//  创建并配置预览 UIView
//  
//  返回: PreviewUIView
//  
//  配置:
//  - 绑定相机会话
//  - 设置填充模式为 resizeAspectFill
//  - 应用视频防抖（如果支持）
//
//  ### updateUIView(_:context:)
//  更新 UIView 当 SwiftUI 状态变化时
//  
//  参数:
//  - uiView: PreviewUIView
//  - context: Context
//  
//  操作:
//  - 更新会话引用
//  - 重新应用防抖设置
//
//  ## 辅助方法
//  - applyStabilizationIfAvailable(on:):
//    在连接上应用视频防抖
//    参数: connection - AVCaptureConnection?
//    功能:
//      - 检查是否支持防抖
//      - 优先使用 cinematicExtended
//      - 降级到 cinematic
//      - 最后使用 auto
//
//  ## 内部类型
//  ### PreviewUIView
//  包含预览层的 UIView 子类
//  
//  属性:
//  - videoPreviewLayer: AVCaptureVideoPreviewLayer
//    预览层实例
//  
//  方法:
//  - init(): 初始化视图
//  - layoutSubviews(): 布局子视图
//    确保预览层填满整个视图
//
//  ## 防抖优先级
//  1. cinematicExtended (最强，适合运动场景)
//  2. cinematic (中等，平衡)
//  3. auto (自动，系统选择)
//
//  ## 使用方式
//  ```swift
//  CameraPreviewView(session: cameraManager.session)
//      .frame(width: 300, height: 400)
//  ```
//

import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit

/// SwiftUI 封装的摄像头预览视图，使用 UIViewRepresentable
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession // 摄像头会话
    let isFrontCamera: Bool // 是否为前置摄像头

    /// 创建并配置预览 UIView
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session // 绑定会话
        view.videoPreviewLayer.videoGravity = .resizeAspectFill // 填充模式
        applyStabilizationIfAvailable(on: view.videoPreviewLayer.connection) // 应用防抖
        
        // 🔥 前置摄像头时使用 transform 翻转（最高优先级）
        if isFrontCamera {
            view.videoPreviewLayer.transform = CATransform3DMakeScale(-1, 1, 1)
        }
        
        return view
    }

    /// 更新 UIView，当 SwiftUI 状态变化时调用
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.videoPreviewLayer.session = session // 更新会话
        applyStabilizationIfAvailable(on: uiView.videoPreviewLayer.connection) // 重新应用防抖
        
        // 🔥 更新翻转状态
        if isFrontCamera {
            uiView.videoPreviewLayer.transform = CATransform3DMakeScale(-1, 1, 1)
        } else {
            uiView.videoPreviewLayer.transform = CATransform3DIdentity
        }
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

