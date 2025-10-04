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
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
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
