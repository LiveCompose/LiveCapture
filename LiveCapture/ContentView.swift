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

#if os(iOS) || os(tvOS)

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var motion = MotionStabilityMonitor()
    @StateObject private var previewProvider = PreviewLayerProvider()
    private let adacrop = AdacropModel()
    private let tracker = TrackingManager()
    @State private var cropRectInView: CGRect? = nil
    @State private var trackedCenter: CGPoint? = nil
    @State private var isAligned: Bool = false
    @State private var showSaveToast = false

    // 模板匹配追踪
    private let templateMatcher = TemplateMatcher()
    private let templateThreshold: Float = 0.88
    @State private var lastSimilarity: Float? = nil
    @State private var templateReady: Bool = false
    
    // 调试状态变量
    @State private var debugMessage = "等待相机启动..."
    @State private var showDebugInfo = true

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session, provider: previewProvider)
                .ignoresSafeArea()

            // Center crosshair
            CrosshairView().tint(isAligned ? .green : .white)

            OverlayView(cropRectInView: cropRectInView, trackedCenter: trackedCenter)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { camera.capturePhoto() }) {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 6)
                            .frame(width: 72, height: 72)
                            .overlay(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .padding(.bottom, 32)
                    Spacer()
                }
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
                                if let center = trackedCenter {
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
                        if let sampleBuffer = camera.lastSampleBuffer, let pixel = CMSampleBufferGetImageBuffer(sampleBuffer), let centerImg = self.templateMatcher.centerUIImage(from: pixel) {
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
                } else {
                    Button("显示调试") { showDebugInfo = true }
                        .font(.caption2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
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

private struct CrosshairView: View {
    var color: Color = .white
    func tint(_ c: Color) -> some View { var v = self; v.color = c; return v }
    var body: some View {
        GeometryReader { geo in
            let size: CGFloat = 24
            let line: CGFloat = 2
            Path { path in
                let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
                // horizontal
                path.move(to: CGPoint(x: center.x - size, y: center.y))
                path.addLine(to: CGPoint(x: center.x + size, y: center.y))
                // vertical
                path.move(to: CGPoint(x: center.x, y: center.y - size))
                path.addLine(to: CGPoint(x: center.x, y: center.y + size))
            }
            .strokedPath(.init(lineWidth: line, lineCap: .round))
            .foregroundStyle(color.opacity(0.95))
            .ignoresSafeArea()
        }
    }
}

extension ContentView {
    private func setupCallbacks() {
        camera.onSampleBuffer = { (sample: CMSampleBuffer) in
            guard self.motion.isStable,
                  let pixel: CVPixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
                DispatchQueue.main.async {
                    self.debugMessage = "等待设备稳定..."
                }
                return
            }

            if !self.templateReady {
                // 仅在模板未就绪时运行一次 Adacrop
                DispatchQueue.main.async { self.debugMessage = "设备已稳定，开始识别目标区域..." }
                self.adacrop.predictCropBox(pixelBuffer: pixel) { (crop: CropBox?) in
                    guard let crop else {
                        DispatchQueue.main.async { self.debugMessage = "目标识别失败，等待重试..." }
                        return
                    }
                    // 生成模板：取检测框中心小块
                    self.templateMatcher.setTemplate(from: pixel, normalizedRegion: crop.rectInNormalizedImage)
                    DispatchQueue.main.async {
                        self.templateReady = true
                        self.debugMessage = "模板已生成：\(crop.detectionType)，开始相似度匹配..."
                        // 可选：清除旧的跟踪可视化
                        self.cropRectInView = nil
                        self.trackedCenter = nil
                    }
                }
            } else {
                // 模板已就绪：实时计算中心块相似度
                if let sim = self.templateMatcher.similarityWithCenter(of: pixel) {
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
        }

        // 保留 tracker 回调但在模板模式下不会触发
        self.tracker.onUpdate = { (box: CGRect, confidence: Float) in
            DispatchQueue.main.async {
                guard let layer = self.findPreviewLayer(), let rectInView = self.convertNormalizedRect(box, in: layer) else {
                    self.cropRectInView = nil
                    self.trackedCenter = nil
                    return
                }
                self.cropRectInView = rectInView
                self.trackedCenter = CGPoint(x: rectInView.midX, y: rectInView.midY)
            }
        }

        self.tracker.onTrackingLost = {
            DispatchQueue.main.async {
                self.cropRectInView = nil
                self.trackedCenter = nil
            }
        }
    }

    private func findPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        previewProvider.layer
    }

    private func convertNormalizedRect(_ rect: CGRect, in layer: AVCaptureVideoPreviewLayer) -> CGRect? {
        // Vision 的归一化坐标以左下为原点，需要先转换为 AVCaptureMetadataOutput 所使用的左上为原点的归一化坐标
        let metadataRect = CGRect(
            x: rect.origin.x,
            y: 1.0 - rect.origin.y - rect.size.height,
            width: rect.size.width,
            height: rect.size.height
        )
        return layer.layerRectConverted(fromMetadataOutputRect: metadataRect)
    }

    private func startTracking(with crop: CropBox, pixelBuffer: CVPixelBuffer) {
        // 旧的基于 Vision 的跟踪入口：改为生成模板
        self.templateMatcher.setTemplate(from: pixelBuffer, normalizedRegion: crop.rectInNormalizedImage)
        self.templateReady = true
        self.debugMessage = "模板已生成：\(crop.detectionType)，开始相似度匹配..."
    }

    private func evaluateAlignment() {
        guard let center = self.trackedCenter else { 
            self.isAligned = false
            return 
        }
        
        #if canImport(UIKit)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.keyWindow else { 
            self.isAligned = false
            return 
        }
        let screenCenter = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
        let distance = hypot(center.x - screenCenter.x, center.y - screenCenter.y)
        #else
        let distance: CGFloat = .infinity
        #endif
        
        let threshold: CGFloat = 10
        let alignedNow = distance < threshold
        
        // 更新调试信息显示距离
        if alignedNow {
            debugMessage = "目标已对准！准备拍照..."
        } else {
            debugMessage = "正在跟踪目标，距离中心: \(Int(distance))px"
        }
        
        if alignedNow && !isAligned {
            // small debounce
            debugMessage = "对准成功！0.2秒后自动拍照..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if self.isAligned == false {
                    self.isAligned = true
                    self.debugMessage = "正在拍照..."
                    self.camera.capturePhoto()
                }
            }
        }
        self.isAligned = alignedNow
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
