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
    var provider: PreviewLayerProvider? = nil

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        provider?.layer = view.videoPreviewLayer
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.videoPreviewLayer.session = session
        provider?.layer = uiView.videoPreviewLayer
    }
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

#else

typealias PreviewLayerProvider = AnyObject

struct CameraPreviewView: View {
    let session: AVCaptureSession
    var provider: PreviewLayerProvider? = nil

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


