//
//  OverlayView.swift
//  LiveCapture
//

import SwiftUI

struct OverlayView: View {
    let cropRectInView: CGRect? // 转换到预览层坐标后的裁切框
    let boxCenter: CGPoint?     // 实心圆在界面中的位置
    let compositionRect: CGRect // 当前 3:4 构图窗口，用于限定所有绘制

    var body: some View {
        GeometryReader { _ in
            ZStack {
                if let rect = cropRectInView?.intersection(compositionRect) {
                    Path { path in
                        path.addRect(rect)
                    }
                    .fill(Color.green.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.green, lineWidth: 2)
                    )
                }

                if let c = boxCenter {
                    let clamped = clamp(point: c, to: compositionRect)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .position(clamped)
                        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                }

                Circle()
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                    .frame(width: 32, height: 32)
                    .position(x: compositionRect.midX, y: compositionRect.midY)
            }
            .animation(.easeInOut(duration: 0.15), value: cropRectInView)
            .animation(.linear(duration: 0.05), value: boxCenter)
        }
        .allowsHitTesting(false)
    }

    private func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
        // 约束点位于 3:4 构图窗口内部，避免偏移导致越界
        CGPoint(x: min(max(point.x, rect.minX), rect.maxX),
                y: min(max(point.y, rect.minY), rect.maxY))
    }
}
