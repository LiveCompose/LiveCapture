//
//  CameraPreviewView.swift
//  LiveCapture
//
//  SwiftUI wrapper for AVCaptureVideoPreviewLayer
//

import SwiftUI
import AVFoundation

#if os(iOS) || os(tvOS)
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        applyStabilizationIfAvailable(on: view.videoPreviewLayer.connection)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.videoPreviewLayer.session = session
        applyStabilizationIfAvailable(on: uiView.videoPreviewLayer.connection)
    }
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private func applyStabilizationIfAvailable(on connection: AVCaptureConnection?) {
    guard let connection, connection.isVideoStabilizationSupported else { return }
    #if os(iOS)
    if #available(iOS 13.0, *), connection.isVideoStabilizationModeSupported(.cinematicExtended) {
        connection.preferredVideoStabilizationMode = .cinematicExtended
        return
    }
    if #available(iOS 13.0, *), connection.isVideoStabilizationModeSupported(.cinematic) {
        connection.preferredVideoStabilizationMode = .cinematic
        return
    }
    #endif
    if connection.isVideoStabilizationModeSupported(.auto) {
        connection.preferredVideoStabilizationMode = .auto
        return
    }
    if connection.isVideoStabilizationModeSupported(.standard) {
        connection.preferredVideoStabilizationMode = .standard
    }
}

#else

struct CameraPreviewView: View {
    let session: AVCaptureSession

    var body: some View {
        Color.black
            .overlay(
                Text("Preview Unavailable")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.4), in: Capsule())
            )
    }
}

#endif
