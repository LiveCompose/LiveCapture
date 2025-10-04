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

/// iOS 主取景界面与功能入口，仅在 iOS 平台编译。
#if os(iOS)

/// iOS 主取景界面，负责相机预览、模板匹配以及提示反馈。
struct ContentView: View {
    /// 相机控制器（保持为 Observed 对象）。
    @StateObject private var camera = CameraManager()
    /// 设备运动监控（用于稳定性与方向转换）。
    @StateObject private var motion = MotionStabilityMonitor()
    /// Adacrop 推理模型。
    private let adacrop = AdacropModel()
    /// CoreImage 上下文，用于像素裁剪（3:4）。
    private static let ciContext = CIContext()

    /// 当前 3:4 裁切框在界面中的坐标。
    @State private var cropRectInView: CGRect? = nil
    /// 初次检测得到的框中心（作为运动偏移的基准）。
    @State private var baseBoxCenterInView: CGPoint? = nil
    /// 实时显示的实心圆位置。
    @State private var boxCenterInView: CGPoint? = nil
    /// 记录当前界面中的 3:4 构图窗口。
    @State private var compositionRectInView: CGRect = .zero
    /// 缓存最近一次 3:4 裁剪后的像素缓冲，供调试使用。
    @State private var lastCroppedPixelBuffer: CVPixelBuffer? = nil
    /// 是否满足模板匹配阈值，用于对准提示。
    @State private var isAligned: Bool = false
    /// 是否展示保存成功的提示气泡。
    @State private var showSaveToast = false

    // 模板匹配追踪
    /// 模板匹配器，实现相似度评估。
    private let templateMatcher = TemplateMatcher()
    /// 相似度阈值，超过后触发对准状态。
    private let templateThreshold: Float = 0.84
    /// 最近一次匹配的相似度。
    @State private var lastSimilarity: Float? = nil
    /// 模板是否已经准备就绪。
    @State private var templateReady: Bool = false
    /// 是否正在进行 Adacrop 推理，防止重复调用。
    @State private var detectionInProgress: Bool = false
    
    // 调试状态变量
    /// 调试信息展示文案。
    @State private var debugMessage = "等待相机启动..."
    /// 默认隐藏调试栏，由按钮控制。
    @State private var showDebugInfo = false

    /// 主视图内容，包含相机预览、覆盖层以及底部控制栏。
    var body: some View {
        GeometryReader { geo in
            let compositionRect = ContentView.compositionRect(in: geo.size)
            let _ = updateCompositionRectIfNeeded(compositionRect) // 记录当前窗口对应的 3:4 区域，供运动偏移换算使用

            ZStack {
                Color.black
                    .ignoresSafeArea()

                CameraPreviewView(session: camera.session)
                    .frame(width: compositionRect.width, height: compositionRect.height)
                    .position(x: compositionRect.midX, y: compositionRect.midY)
                    .clipped()

                overlayLayer(for: compositionRect,
                              canvasRect: CGRect(origin: .zero, size: geo.size))

                // 用户模式底部控制条
                VStack {
                    Spacer()
                    HStack(spacing: 25) {
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
                                .strokeBorder(Color.white, lineWidth: 10)
                                .frame(width: 78, height: 78)
                                .overlay(Circle().fill(Color.white.opacity(0.15)))
                        }
                        Spacer()
                        Button(action: { resetDetectionState() }) {
                            Image(systemName: "gobackward")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(.white)
                                .opacity(0.9)
                        } // 重新检测按钮：允许用户手动恢复 Adacrop 与模板状态
                        Button(action: {}) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(.white)
                                .opacity(0.9)
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 75)
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
                        
                        Text("状: \(debugMessage)")
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
    /// 绘制遮罩、构图辅助线、模板框与追踪标记的覆盖层。
    @ViewBuilder
    private func overlayLayer(for compositionRect: CGRect, canvasRect: CGRect) -> some View {
        let focusColor: Color = isAligned ? .green : .white

        // 将传入的 compositionRect 转换为相对于 canvasRect 的本地坐标系，
        // 以避免父视图的 padding / safeArea 导致的坐标偏移不一致。
        let localComposition = CGRect(x: compositionRect.minX - canvasRect.minX,
                                      y: compositionRect.minY - canvasRect.minY,
                                      width: compositionRect.width,
                                      height: compositionRect.height)

        ZStack(alignment: .topLeading) {
            Canvas { ctx, _ in
                var mask = Path()
                mask.addRect(CGRect(origin: .zero, size: canvasRect.size))
                mask.addRect(localComposition)
                ctx.fill(mask,
                         with: .color(Color.black.opacity(0.35)),
                         style: FillStyle(eoFill: true))
                ctx.stroke(Path(localComposition),
                           with: .color(Color.white.opacity(0.45)),
                           lineWidth: 1)
            }

            // 三分线显示（在 canvas 的本地坐标系绘制）
            Path { path in
                let thirdWidth = localComposition.width / 3
                let thirdHeight = localComposition.height / 3

                for i in 1..<3 {
                    let x = localComposition.minX + CGFloat(i) * thirdWidth
                    path.move(to: CGPoint(x: x, y: localComposition.minY))
                    path.addLine(to: CGPoint(x: x, y: localComposition.maxY))
                }
                for i in 1..<3 {
                    let y = localComposition.minY + CGFloat(i) * thirdHeight
                    path.move(to: CGPoint(x: localComposition.minX, y: y))
                    path.addLine(to: CGPoint(x: localComposition.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1)

            // 中心空心圆（使用本地坐标）
            Circle()
                .strokeBorder(focusColor.opacity(1), lineWidth: 4)
                .frame(width: 32, height: 32)
                .position(x: localComposition.midX, y: localComposition.midY)

            // 裁切框临时显示逻辑（将全局 cropRectInView 转换为本地坐标）
            if let rectGlobal = cropRectInView?.intersection(compositionRect),
               !rectGlobal.isNull, !rectGlobal.isEmpty {
                let rect = CGRect(x: rectGlobal.minX - canvasRect.minX,
                                  y: rectGlobal.minY - canvasRect.minY,
                                  width: rectGlobal.width,
                                  height: rectGlobal.height)
                let rounded = Path(roundedRect: rect, cornerRadius: 3)
                rounded
                    .fill(Color.green.opacity(0.18))
                    .overlay(rounded.stroke(Color.green.opacity(0.85), lineWidth: 2))
                    .animation(.easeInOut(duration: 0.18), value: rect)
            }

            // 追踪的空心圆（将 boxCenterInView 从全局坐标转换为本地坐标并限制在 localComposition）
            if let pointGlobal = boxCenterInView {
                let pointLocal = CGPoint(x: pointGlobal.x - canvasRect.minX,
                                         y: pointGlobal.y - canvasRect.minY)
                let clamped = clamp(point: pointLocal, to: localComposition)
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .position(clamped)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                    .animation(.linear(duration: 0.05), value: clamped)
            }
        }
        .frame(width: canvasRect.width, height: canvasRect.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
    /// 绑定摄像头图像流回调，串联裁剪、模板匹配与状态更新。
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
    /// 启动一次 Adacrop 推理，成功后锁定基准框并生成模板。
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
                    self.adacrop.resetSmoothing()
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
    /// 根据模板匹配相似度判断是否触发拍照，并实时更新提示。
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

    /// 将不同方向下的归一化矩形统一转换到预览坐标系。
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
    /// 在构图窗口尺寸变化时刷新记录，并同步追踪点坐标。
    private func updateCompositionRectIfNeeded(_ rect: CGRect) {
        guard compositionRectInView != rect else { return }
        DispatchQueue.main.async {
            self.compositionRectInView = rect
            self.updateBoxCenter(withNormalizedOffset: self.motion.screenOffsetNormalized)
        }
    }

    // 将 MotionStabilityMonitor 提供的归一化偏移映射为界面像素
    /// 将陀螺仪归一化偏移映射为界面像素，得到追踪点位置。
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

    /// 将点限制在指定矩形范围内。
    private func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, rect.minX), rect.maxX),
                y: min(max(point.y, rect.minY), rect.maxY))
    }

    /// 将输入像素缓冲旋正并裁剪为 3:4 区域，返回新的像素缓冲。
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

    /// 根据像素缓冲的宽高关系推断当前的图像朝向。
    private func pixelOrientation(for pixelBuffer: CVPixelBuffer) -> CGImagePropertyOrientation {
        // 根据宽高判断传感器当前的原始朝向，默认认为横向图像代表竖屏拍摄（右旋 90°）
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        return width > height ? .right : .up
    }

    /// 重置模板匹配相关状态，等待下一轮检测。
    private func resetDetectionState() {
        templateReady = false
        isAligned = false
        lastSimilarity = nil
        cropRectInView = nil
        baseBoxCenterInView = nil
        boxCenterInView = nil
        lastCroppedPixelBuffer = nil
        motion.resetReferenceAttitude() // 恢复陀螺仪偏移参考
        adacrop.resetSmoothing()
        detectionInProgress = false
        debugMessage = "已重置检测，等待稳定..."
    }

    /// 将归一化矩形按当前屏幕方向映射到构图窗口坐标系。
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

    /// 在给定屏幕尺寸下计算竖屏的 3:4 构图窗口区域。
    private static func compositionRect(in size: CGSize) -> CGRect {
        // 根据屏幕宽度计算 3:4 的可视窗口，并在竖直方向居中
        let width = size.width
        let targetHeight = width * 4.0 / 3.0
        let height = min(size.height, targetHeight)
        let originY = (size.height - height) * 0.5
        return CGRect(x: 0, y: originY, width: width, height: height)
    }
}

#endif
