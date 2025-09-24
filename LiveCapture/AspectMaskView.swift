//
//  AspectMaskView.swift
//  LiveCapture
//

import SwiftUI

#if os(iOS) || os(tvOS)

struct AspectMaskView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // target 3:4 portrait window inside full view
            let targetHeight = w * 4.0 / 3.0
            let window = CGRect(x: 0, y: max(0, (h - targetHeight)/2), width: w, height: min(h, targetHeight))
            Canvas { ctx, size in
                let full = CGRect(origin: .zero, size: size)
                var path = Path()
                path.addRect(full)
                let windowPath = Path(CGRect(x: window.minX, y: window.minY, width: window.width, height: window.height))
                path.addPath(windowPath)
                ctx.fill(path, with: .color(Color.black.opacity(0.35)), style: FillStyle(eoFill: true))
                ctx.stroke(windowPath, with: .color(Color.white.opacity(0.5)), lineWidth: 1.0)
            }
        }
        .allowsHitTesting(false)
    }
}

#endif
