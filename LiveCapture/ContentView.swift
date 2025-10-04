//
//  ContentView.swift
//  LiveCapture
//
//  Created by JettyCoffee on 2025/9/20.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import AVFoundation
import Vision
import CoreImage
import ImageIO

/// A description
#if os(iOS) || os(tvOS)

struct ContentView: View {
    @StateObject private var camera = CameraManager() // 相机控制器（保持为 Observed 对象）
    @StateObject private var motion = MotionStabilityMonitor() // 设备运动监控（用于稳定性与方向转换）
    private let adacrop = AdacropModel() // Adacrop 推理模型
    private static let ciContext = CIContext() // CoreImage 上下文，用于像素裁剪（3:4）

    @State private var cropRectInView: CGRect? = nil // 当前 3:4 裁切框在界面中的坐标
    @State private var baseBoxCenterInView: CGPoint? = nil // 初次检测得到的框中心（作为运动偏移的基准）
    @State private var boxCenterInView: CGPoint? = nil // 实时显示的实心圆位置
    @State private var compositionRectInView: CGRect = .zero // 记录当前界面中的 3:4 构图窗口
    @State private var lastCroppedPixelBuffer: CVPixelBuffer? = nil // 缓存最近一次 3:4 裁剪后的像素缓冲，供调试显示
    @State private var isAligned: Bool = false // 是否满足模板匹配阈值，用于对准提示
    @State private var showSaveToast = false

    // 模板匹配追踪
    private let templateMatcher = TemplateMatcher()
    private let templateThreshold: Float = 0.84
    @State private var lastSimilarity: Float? = nil
    @State private var templateReady: Bool = false
    @State private var detectionInProgress: Bool = false // 防止重复触发 Adacrop 推理
    
    // 调试状态变量
    @State private var debugMessage = "等待相机启动..."
    @State private var showDebugInfo = false // 默认隐藏调试栏，由按钮控制

    var body: some View {
        GeometryReader { geo in
            let compositionRect = ContentView.compositionRect(in: geo.size)
            let _ = updateCompositionRectIfNeeded(compositionRect) // 记录当前窗口对应的 3:4 区域，供运动偏移换算使用

            ZStack {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()

                CompositionOverlayView(compositionRect: compositionRect,
                                       cropRect: cropRectInView,
                                       trackedPoint: boxCenterInView,
                                       isAligned: isAligned)

                // 用户模式底部控制条（参考系统相机）
                VStack {
                    Spacer()
                    HStack(spacing: 24) {
                        Button(action: {}) {
                            Image(systemName: "bolt.circle")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(.white)
                                .opacity(0.9)
                        }
                        Button(action: { showDebugInfo.toggle() }) {
                            Image(systemName: showDebugInfo ? "eye.slash.circle" : "eye.circle")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(.white)
                                .opacity(0.9)
                        } // 调试信息开关按钮
                        Spacer()
                        Button(action: { camera.capturePhoto() }) {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 6)
                                .frame(width: 78, height: 78)
                                .overlay(Circle().fill(Color.white.opacity(0.15)))
                        }
                        Button(action: { resetDetectionState() }) {
                            Image(systemName: "gobackward")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(.white)
                                .opacity(0.9)
                        } // 重新检测按钮：允许用户手动恢复 Adacrop 与模板状态
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(.white)
                                .opacity(0.9)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 26)
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                // 调试信息显示
                if showDebugInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("调试信息")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                            Button("隐藏") { showDebugInfo = false }
                                .font(.caption2)
                        }
                        
                        Text("状态: \(debugMessage)")
                            .font(.caption2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("稳定性: \(motion.isStable ? "稳定" : "不稳定")")
                                Spacer()
                                if let center = boxCenterInView {
                                    Text("跟踪: (\(Int(center.x)), \(Int(center.y)))")
                                } else {
                                    Text("跟踪: 无")
                                }
                            }
                            HStack {
                                if let sim = lastSimilarity {
                                    Text("相似度: \(String(format: "%.2f", sim)) / \(String(format: "%.2f", templateThreshold))")
                                } else {
                                    Text("相似度: --")
                                }
                                Spacer()
                                Text(templateReady ? "模板: 已就绪" : "模板: 未就绪")
                            }
                        }
                        .font(.caption2)
                        
                        Text("对准: \(isAligned ? "已对准" : "未对准")")
                            .font(.caption2)
                            .foregroundColor(isAligned ? .green : .primary)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)

                    // 缩略图：模板与中心小方块
                    #if canImport(UIKit)
                    HStack(spacing: 8) {
                        if let img = self.templateMatcher.templateUIImage() {
                            Image(uiImage: img)
                                .resizable()
                                .interpolation(.none)
                                .antialiased(false)
                                .frame(width: 64, height: 64)
                                .border(Color.white.opacity(0.8), width: 1)
                                .overlay(Text("T").font(.caption2).padding(2), alignment: .topLeading)
                        }
                        if let pixel = lastCroppedPixelBuffer,
                           let centerImg = self.templateMatcher.centerUIImage(from: pixel) {
                            Image(uiImage: centerImg)
                                .resizable()
                                .interpolation(.none)
                                .antialiased(false)
                                .frame(width: 64, height: 64)
                                .border(Color.white.opacity(0.8), width: 1)
                                .overlay(Text("C").font(.caption2).padding(2), alignment: .topLeading)
                        }
                    }
                    .padding(.horizontal, 16)
                    #endif
                }

                // 保存成功提示
                if showSaveToast {
                    Text("已保存")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.top, 24)
        }
        .onReceive(motion.$screenOffsetNormalized) { offset in
            updateBoxCenter(withNormalizedOffset: offset) // 将 3D 陀螺仪偏移转换为 2D 像素偏移
        }
        .onAppear {
            debugMessage = "正在启动相机..."
            camera.checkAndConfigure { result in
                switch result {
                case .success:
                    camera.startSession()
                    DispatchQueue.main.async {
                        debugMessage = "相机启动成功，等待稳定..."
                    }
                case .failure:
                    DispatchQueue.main.async {
                        debugMessage = "相机启动失败"
                    }
                }
            }
            motion.start()
            setupCallbacks()
        }
        .onChange(of: camera.lastPhotoSaved) { (_: Bool, saved: Bool) in
            if saved {
                showSaveToast = true
                debugMessage = "照片已保存到相册"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showSaveToast = false
                }
            }
        }
        .onDisappear {
            motion.stop()
            camera.stopSession()
        }
    }
}

} // <-- Add this closing brace to end the struct ContentView for iOS/tvOS

extension ContentView {
    private func setupCallbacks() {
        camera.onSampleBuffer = { (sample: CMSampleBuffer) in
            guard let rawPixel: CVPixelBuffer = CMSampleBufferGetImageBuffer(sample) else { return }
            let orientation = self.pixelOrientation(for: rawPixel) // 依据像素缓冲尺寸推导当前方向

            guard self.motion.isStable else {
                DispatchQueue.main.async {
                    self.debugMessage = "等待设备稳定..."
                }
                return
            }

            guard let compositionPixel = self.makeThreeByFourPixelBuffer(from: rawPixel, orientation: orientation) else {
                DispatchQueue.main.async {
                    self.debugMessage = "无法裁剪 3:4 画面"
                }
                return
            }

            if !self.templateReady && !self.detectionInProgress {
                DispatchQueue.main.async {
                    self.debugMessage = "设备已稳定，开始识别目标区域..."
                    self.lastCroppedPixelBuffer = compositionPixel
                    self.detectionInProgress = true
                }
                self.detectCropOnce(using: compositionPixel, orientation: orientation)
            } else if self.templateReady {
                self.evaluateTemplateSimilarity(with: compositionPixel)
                DispatchQueue.main.async {
                    self.lastCroppedPixelBuffer = compositionPixel
                }
            }
        }
    }

    // 执行一次 Adacrop 推理，并在成功后锁定基准中心
    private func detectCropOnce(using pixel: CVPixelBuffer,
                                orientation: CGImagePropertyOrientation) {
        adacrop.predictCropBox(pixelBuffer: pixel, orientation: orientation) { crop in
            guard let crop else {
                DispatchQueue.main.async {
                    self.debugMessage = "目标识别失败，等待重试..."
                    self.cropRectInView = nil
                    self.baseBoxCenterInView = nil
                    self.boxCenterInView = nil
                    self.templateReady = false
                    self.motion.resetReferenceAttitude() // 重置参考姿态，避免历史偏移污染下一次检测
                    self.detectionInProgress = false
                }
                return
            }

            DispatchQueue.main.async {
                if let rectInView = self.rectInCompositionSpace(from: crop.rectInNormalizedImage,
                                                                orientation: orientation) {
                    self.cropRectInView = rectInView
                    let center = CGPoint(x: rectInView.midX, y: rectInView.midY)
                    self.baseBoxCenterInView = center
                    self.boxCenterInView = center
                    self.motion.lockReferenceAttitude() // 将当前陀螺仪姿态锁定为 2D 偏移的零点
                    self.updateBoxCenter(withNormalizedOffset: self.motion.screenOffsetNormalized)
                } else {
                    self.cropRectInView = nil
                    self.baseBoxCenterInView = nil
                    self.boxCenterInView = nil
                }
            }

            self.templateMatcher.setTemplate(from: pixel, normalizedRegion: crop.rectInNormalizedImage) { ok in
                DispatchQueue.main.async {
                    if ok {
                        self.templateReady = true
                        self.debugMessage = "模板已生成：\(crop.detectionType)，开始相似度匹配..."
                        self.lastSimilarity = nil
                        self.isAligned = false
                        self.detectionInProgress = false
                    } else {
                        self.templateReady = false
                        self.debugMessage = "模板生成失败，等待重试..."
                        self.baseBoxCenterInView = nil
                        self.boxCenterInView = nil
                        self.motion.resetReferenceAttitude()
                        self.detectionInProgress = false
                    }
                }
            }
        }
    }

    // 将模板匹配的相似度转换为拍照触发逻辑
    private func evaluateTemplateSimilarity(with pixel: CVPixelBuffer) {
        if let sim = templateMatcher.similarityWithCenter(of: pixel) {
            DispatchQueue.main.async {
                self.lastSimilarity = sim
                let alignedNow = sim >= self.templateThreshold
                if alignedNow && !self.isAligned {
                    self.debugMessage = "对准成功（相似度）！0.2秒后自动拍照..."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if self.isAligned == false {
                            self.isAligned = true
                            self.debugMessage = "正在拍照..."
                            self.camera.capturePhoto()
                        }
                    }
                } else if alignedNow {
                    self.debugMessage = "保持对准（相似度）: \(String(format: "%.2f", sim))"
                } else {
                    self.debugMessage = "移动中，相似度: \(String(format: "%.2f", sim))"
                }
                self.isAligned = alignedNow
            }
        } else {
            DispatchQueue.main.async {
                self.debugMessage = "相似度计算失败"
                self.isAligned = false
            }
        }
    }

    private func rotateNormalizedRect(_ rect: CGRect,
                                      for orientation: CGImagePropertyOrientation) -> CGRect {
        // 将不同拍摄方向的归一化坐标统一到预览层使用的“左上角为原点”的坐标系
        switch orientation {
        case .up, .upMirrored:
            return rect
        case .right, .rightMirrored:
            return CGRect(x: 1.0 - rect.origin.y - rect.size.height,
                          y: rect.origin.x,
                          width: rect.size.height,
                          height: rect.size.width)
        case .down, .downMirrored:
            return CGRect(x: 1.0 - rect.origin.x - rect.size.width,
                          y: 1.0 - rect.origin.y - rect.size.height,
                          width: rect.size.width,
                          height: rect.size.height)
        case .left, .leftMirrored:
            return CGRect(x: rect.origin.y,
                          y: 1.0 - rect.origin.x - rect.size.width,
                          width: rect.size.height,
                          height: rect.size.width)
        @unknown default:
            return rect
        }
    }

    // 监听几何变化，保证 3:4 窗口变化时重新换算陀螺仪偏移
    private func updateCompositionRectIfNeeded(_ rect: CGRect) {
        guard compositionRectInView != rect else { return }
        DispatchQueue.main.async {
            self.compositionRectInView = rect
            self.updateBoxCenter(withNormalizedOffset: self.motion.screenOffsetNormalized)
        }
    }

    // 将 MotionStabilityMonitor 提供的归一化偏移映射为界面像素
    private func updateBoxCenter(withNormalizedOffset offset: CGPoint) {
        guard let base = baseBoxCenterInView, compositionRectInView != .zero else { return }
        // 将归一化偏移量映射到实际像素：横向取构图宽度的 40%，纵向同理（并限制在窗口内）
        let maxOffsetX = compositionRectInView.width * 0.4
        let maxOffsetY = compositionRectInView.height * 0.4
        // Y 轴保持同向：陀螺仪正偏移（抬头）时实心圆向上移动
        let target = CGPoint(x: base.x + offset.x * maxOffsetX,
                             y: base.y + offset.y * maxOffsetY)
        let clamped = clamp(point: target, to: compositionRectInView)
        DispatchQueue.main.async {
            self.boxCenterInView = clamped
        }
    }

    private func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, rect.minX), rect.maxX),
                y: min(max(point.y, rect.minY), rect.maxY))
    }

    private func makeThreeByFourPixelBuffer(from pixelBuffer: CVPixelBuffer,
                                            orientation: CGImagePropertyOrientation) -> CVPixelBuffer? {
        // 先将原始图像旋转到“竖屏向上”的方向，保证后续 3:4 裁剪稳定
        let orientedImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        let extent = orientedImage.extent
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

        let croppedImage = orientedImage.cropped(to: cropRect)

        var outputBuffer: CVPixelBuffer?
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
                                         &outputBuffer)
        guard status == kCVReturnSuccess, let buffer = outputBuffer else { return nil }

        ContentView.ciContext.render(croppedImage, to: buffer)
        return buffer
    }

    private func pixelOrientation(for pixelBuffer: CVPixelBuffer) -> CGImagePropertyOrientation {
        // 根据宽高判断传感器当前的原始朝向，默认认为横向图像代表竖屏拍摄（右旋 90°）
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        return width > height ? .right : .up
    }

    private func resetDetectionState() {
        templateReady = false
        isAligned = false
        lastSimilarity = nil
        cropRectInView = nil
        baseBoxCenterInView = nil
        boxCenterInView = nil
        lastCroppedPixelBuffer = nil
        motion.resetReferenceAttitude() // 恢复陀螺仪偏移参考
        detectionInProgress = false
        debugMessage = "已重置检测，等待稳定..."
    }

    private func rectInCompositionSpace(from rect: CGRect,
                                        orientation: CGImagePropertyOrientation) -> CGRect? {
        guard compositionRectInView != .zero else { return nil }
        let composition = compositionRectInView
        let rotated = rotateNormalizedRect(rect, for: orientation)
        let x = composition.minX + rotated.origin.x * composition.width
        let y = composition.minY + (1.0 - rotated.origin.y - rotated.size.height) * composition.height
        let width = rotated.size.width * composition.width
        let height = rotated.size.height * composition.height
        let mapped = CGRect(x: x, y: y, width: width, height: height)
        guard mapped.intersects(composition) else { return nil }
        return mapped.intersection(composition)
    }

    private static func compositionRect(in size: CGSize) -> CGRect {
        // 根据屏幕宽度计算 3:4 的可视窗口，并在竖直方向居中
        let width = size.width
        let targetHeight = width * 4.0 / 3.0
        let height = min(size.height, targetHeight)
        let originY = (size.height - height) * 0.5
        return CGRect(x: 0, y: originY, width: width, height: height)
    }
}

#if DEBUG
#Preview {
    ContentView()
}
#endif

#else

struct ContentView: View {
    var body: some View {
        Text("Unsupported Platform")
    }
}

#endif
