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
                            
                            Text("传感器: \(motion.debugInfo)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .font(.caption2)
                        
                        Text("对准: \(isAligned ? "已对准" : "未对准")")
                            .font(.caption2)
                            .foregroundColor(isAligned ? .green : .primary)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)
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

            if self.cropRectInView == nil {
                // Run Adacrop once when stable
                DispatchQueue.main.async {
                    self.debugMessage = "设备已稳定，开始识别目标区域..."
                }
                self.adacrop.predictCropBox(pixelBuffer: pixel) { (crop: CropBox?) in
                    guard let crop else { 
                        DispatchQueue.main.async {
                            self.debugMessage = "目标识别失败，等待重试..."
                        }
                        return 
                    }
                    DispatchQueue.main.async {
                        self.debugMessage = "识别成功：\(crop.detectionType)"
                        self.startTracking(with: crop, pixelBuffer: pixel)
                    }
                }
            } else {
                // Update tracking every frame
                self.tracker.track(pixelBuffer: pixel)
            }
        }

        self.tracker.onUpdate = { (box: CGRect, confidence: Float) in
            DispatchQueue.main.async {
                guard let layer = self.findPreviewLayer(),
                      let rectInView = self.convertNormalizedRect(box, in: layer) else {
                    self.cropRectInView = nil
                    self.trackedCenter = nil
                    self.isAligned = false
                    self.debugMessage = "跟踪数据转换失败"
                    return
                }
                self.cropRectInView = rectInView
                self.trackedCenter = CGPoint(x: rectInView.midX, y: rectInView.midY)
                self.debugMessage = "跟踪目标，置信度: \(String(format: "%.2f", confidence))"
                self.evaluateAlignment()
            }
        }
        
        // 处理跟踪丢失的情况
        self.tracker.onTrackingLost = {
            DispatchQueue.main.async {
                self.cropRectInView = nil
                self.trackedCenter = nil
                self.isAligned = false
                self.debugMessage = "跟踪丢失，清除状态并准备重新识别..."
                // 重置tracker以便重新开始跟踪
                self.tracker.reset()
            }
        }
    }

    private func findPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        previewProvider.layer
    }

    private func convertNormalizedRect(_ rect: CGRect, in layer: AVCaptureVideoPreviewLayer) -> CGRect? {
        layer.layerRectConverted(fromMetadataOutputRect: rect)
    }

    private func startTracking(with crop: CropBox, pixelBuffer: CVPixelBuffer) {
        DispatchQueue.main.async {
            self.debugMessage = "启动跟踪器 (\(crop.detectionType))..."
        }
        self.tracker.startTracking(from: crop.rectInNormalizedImage, pixelBuffer: pixelBuffer)
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
