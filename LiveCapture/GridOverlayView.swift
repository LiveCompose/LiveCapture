//
//  GridOverlayView.swift
//  LiveCapture
//

import SwiftUI

#if os(iOS) || os(tvOS)

struct GridOverlayView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                // vertical lines
                p.move(to: CGPoint(x: w/3, y: 0))
                p.addLine(to: CGPoint(x: w/3, y: h))
                p.move(to: CGPoint(x: 2*w/3, y: 0))
                p.addLine(to: CGPoint(x: 2*w/3, y: h))
                // horizontal lines
                p.move(to: CGPoint(x: 0, y: h/3))
                p.addLine(to: CGPoint(x: w, y: h/3))
                p.move(to: CGPoint(x: 0, y: 2*h/3))
                p.addLine(to: CGPoint(x: w, y: 2*h/3))
            }
            .strokedPath(.init(lineWidth: 1))
            .foregroundStyle(Color.white.opacity(0.25))
        }
        .allowsHitTesting(false)
    }
}

#endif
