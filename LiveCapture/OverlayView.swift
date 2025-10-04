//
//  OverlayView.swift
//  LiveCapture
//

import SwiftUI

struct OverlayView: View {
    let cropRectInView: CGRect?
    let boxCenter: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let frameCenter = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
            ZStack {

                if let rect: CGRect = cropRectInView {
                    Path { path in
                        path.addRect(rect)
                    }
                    .fill(Color.green.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.green, lineWidth: 2)
                    )
                }

                if let c: CGPoint = boxCenter {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .position(c)
                        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                }

                Circle()
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                    .frame(width: 32, height: 32)
                    .position(frameCenter)
            }
            .animation(.easeInOut(duration: 0.15), value: cropRectInView)
            .animation(.linear(duration: 0.05), value: boxCenter)
        }
        .allowsHitTesting(false)
    }
}
