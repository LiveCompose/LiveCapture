//
//  OverlayView.swift
//  LiveCapture
//

import SwiftUI

/// 汇总所有与 3:4 构图相关的可视元素，确保它们共用同一套坐标与遮罩。
struct CompositionOverlayView: View {
    let compositionRect: CGRect
    let cropRect: CGRect?
    let trackedPoint: CGPoint?
    let isAligned: Bool

    private var focusColor: Color { isAligned ? .green : .white }

    var body: some View {
        GeometryReader { geo in
            let canvasRect = CGRect(origin: .zero, size: geo.size)
            ZStack(alignment: .topLeading) {
                // 灰色遮罩，仅保留 3:4 区域透明
                Canvas { ctx, _ in
                    var mask = Path()
                    mask.addRect(canvasRect)
                    mask.addRect(compositionRect)
                    ctx.fill(mask,
                             with: .color(Color.black.opacity(0.35)),
                             style: FillStyle(eoFill: true))
                    ctx.stroke(Path(compositionRect),
                               with: .color(Color.white.opacity(0.45)),
                               lineWidth: 1)
                }

                // 三分线，仅在 3:4 窗口内部绘制
                Path { path in
                    let thirdWidth = compositionRect.width / 3
                    let thirdHeight = compositionRect.height / 3

                    // vertical
                    for i in 1..<3 {
                        let x = compositionRect.minX + CGFloat(i) * thirdWidth
                        path.move(to: CGPoint(x: x, y: compositionRect.minY))
                        path.addLine(to: CGPoint(x: x, y: compositionRect.maxY))
                    }
                    // horizontal
                    for i in 1..<3 {
                        let y = compositionRect.minY + CGFloat(i) * thirdHeight
                        path.move(to: CGPoint(x: compositionRect.minX, y: y))
                        path.addLine(to: CGPoint(x: compositionRect.maxX, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.22), lineWidth: 1)

                // 中心十字线与对准圆环
                Path { path in
                    let center = CGPoint(x: compositionRect.midX, y: compositionRect.midY)
                    let arm: CGFloat = 24
                    path.move(to: CGPoint(x: center.x - arm, y: center.y))
                    path.addLine(to: CGPoint(x: center.x + arm, y: center.y))
                    path.move(to: CGPoint(x: center.x, y: center.y - arm))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + arm))
                }
                .stroke(focusColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                Circle()
                    .strokeBorder(focusColor.opacity(0.95), lineWidth: 2)
                    .frame(width: 32, height: 32)
                    .position(x: compositionRect.midX, y: compositionRect.midY)

                // 模型输出的 3:4 框，限制在窗口内部
                if let rect = cropRect?.intersection(compositionRect), !rect.isNull, !rect.isEmpty {
                    let rounded = Path(roundedRect: rect, cornerRadius: 3)
                    rounded
                        .fill(Color.green.opacity(0.18))
                        .overlay(
                            rounded.stroke(Color.green.opacity(0.85), lineWidth: 2)
                        )
                        .animation(.easeInOut(duration: 0.18), value: rect)
                }

                // 陀螺仪偏移后的跟踪点
                if let point = clampedPoint(trackedPoint, in: compositionRect) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .position(point)
                        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                        .animation(.linear(duration: 0.05), value: point)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func clampedPoint(_ point: CGPoint?, in rect: CGRect) -> CGPoint? {
        guard let point else { return nil }
        let x = min(max(point.x, rect.minX), rect.maxX)
        let y = min(max(point.y, rect.minY), rect.maxY)
        return CGPoint(x: x, y: y)
    }
}
