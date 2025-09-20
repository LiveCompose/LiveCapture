//
//  ContentView.swift
//  LiveCapture
//
//  Created by JettyCoffee on 2025/9/20.
//

import SwiftUI
import AVFoundation
import Vision

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var motion = MotionStabilityMonitor()
    private let adacrop = AdacropModel(mlModelURL: URL(fileURLWithPath: "/Users/jettycoffee/Desktop/LiveCapture/Adacrop.mlmodel"))
    private let tracker = TrackingManager()
    @State private var cropRectInView: CGRect? = nil
    @State private var trackedCenter: CGPoint? = nil
    @State private var isAligned: Bool = false
    @State private var showSaveToast = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
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
        .onAppear {
            camera.checkAndConfigure { result in
                switch result {
                case .success:
                    camera.startSession()
                case .failure:
                    break
                }
            }
            motion.start()
            setupCallbacks()
        }
        .onChange(of: camera.lastPhotoSaved) { _, saved in
            if saved {
                showSaveToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showSaveToast = false
                }
            }
        }
        .overlay(alignment: .top) {
            if showSaveToast {
                Text("已保存")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 24)
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
        camera.onSampleBuffer = { sample in
            guard self.motion.isStable,
                  let pixel = CMSampleBufferGetImageBuffer(sample) else { return }

            if self.cropRectInView == nil {
                // Run Adacrop once when stable
                self.adacrop?.predictCropBox(pixelBuffer: pixel) { crop in
                    guard let crop else { return }
                    DispatchQueue.main.async {
                        self.startTracking(with: crop, pixelBuffer: pixel)
                    }
                }
            } else {
                // Update tracking every frame
                self.tracker.track(pixelBuffer: pixel)
            }
        }

        self.tracker.onUpdate = { box, confidence in
            DispatchQueue.main.async {
                guard confidence > 0.3,
                      let layer = findPreviewLayer(),
                      let rectInView = convertNormalizedRect(box, in: layer) else {
                    self.cropRectInView = nil
                    self.trackedCenter = nil
                    self.isAligned = false
                    return
                }
                self.cropRectInView = rectInView
                self.trackedCenter = CGPoint(x: rectInView.midX, y: rectInView.midY)
                self.evaluateAlignment()
            }
        }
    }

    private func findPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        // Traverse key window to find preview layer
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.keyWindow,
              let root = window.rootViewController?.view else { return nil }
        return root.layer.sublayers?.compactMap { $0 as? AVCaptureVideoPreviewLayer }.first
    }

    private func convertNormalizedRect(_ rect: CGRect, in layer: AVCaptureVideoPreviewLayer) -> CGRect? {
        layer.layerRectConverted(fromMetadataOutputRect: rect)
    }

    private func startTracking(with crop: CropBox, pixelBuffer: CVPixelBuffer) {
        self.tracker.startTracking(from: crop.rectInNormalizedImage, pixelBuffer: pixelBuffer)
    }

    private func evaluateAlignment() {
        guard let center = self.trackedCenter,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.keyWindow else { self.isAligned = false; return }
        let screenCenter = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
        let distance = hypot(center.x - screenCenter.x, center.y - screenCenter.y)
        let threshold: CGFloat = 10
        let alignedNow = distance < threshold
        if alignedNow && !isAligned {
            // small debounce
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if self.isAligned == false {
                    self.isAligned = true
                    self.camera.capturePhoto()
                }
            }
        }
        self.isAligned = alignedNow
    }
}

#Preview {
    ContentView()
}
