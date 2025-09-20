//
//  OverlayView.swift
//  LiveCapture
//

import SwiftUI

struct OverlayView: View {
    let cropRectInView: CGRect?
    let trackedCenter: CGPoint?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let rect = cropRectInView {
                    Path { path in
                        path.addRect(rect)
                    }
                    .fill(Color.green.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.green, lineWidth: 2)
                    )
                }

                if let c = trackedCenter {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 12, height: 12)
                        .position(c)
                        .shadow(radius: 2)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: cropRectInView)
            .animation(.linear(duration: 0.05), value: trackedCenter)
        }
        .allowsHitTesting(false)
    }
}


