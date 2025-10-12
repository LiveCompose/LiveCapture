//
//  UniformSmoother.swift
//  LiveCapture
//
//  Provides reusable low-pass smoothing for points and rects so camera UI elements
//  share the same temporal response.
//

import Foundation
import CoreGraphics
import simd

/// 针对二维点的统一响应低通滤波器。
struct UniformPointSmoother {
    private let response: Double
    private var previous: SIMD2<Double>?

    /// 使用指定的响应系数初始化平滑器。
    init(response: Double) {
        self.response = UniformPointSmoother.clamped(response)
    }

    /// 对输入点应用指数平滑，返回滤波后的结果。
    mutating func filter(_ point: CGPoint) -> CGPoint {
        let current = SIMD2<Double>(Double(point.x), Double(point.y))
        guard let prev = previous else {
            previous = current
            return point
        }
        let t = SIMD2<Double>(repeating: response)
        let filtered = simd_mix(prev, current, t)
        previous = filtered
        return CGPoint(x: CGFloat(filtered.x), y: CGFloat(filtered.y))
    }

    /// 重置内部状态，可选地指定初始值。
    mutating func reset(to point: CGPoint? = nil) {
        if let point {
            previous = SIMD2<Double>(Double(point.x), Double(point.y))
        } else {
            previous = nil
        }
    }

    /// 将响应值约束在 [0,1] 范围内。
    private static func clamped(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}

/// 针对矩形的统一响应低通滤波器。
struct UniformRectSmoother {
    private let response: Double
    private var previous: SIMD4<Double>?

    /// 使用指定响应参数初始化矩形平滑器。
    init(response: Double) {
        self.response = UniformRectSmoother.clamped(response)
    }

    /// 对输入矩形执行平滑，分别滤波位置与尺寸。
    mutating func filter(_ rect: CGRect) -> CGRect {
        let current = SIMD4<Double>(Double(rect.origin.x),
                                    Double(rect.origin.y),
                                    Double(rect.size.width),
                                    Double(rect.size.height))
        guard let prev = previous else {
            previous = current
            return rect
        }
        let t = SIMD4<Double>(repeating: response)
        let filtered = simd_mix(prev, current, t)
        previous = filtered
        return CGRect(x: CGFloat(filtered.x),
                      y: CGFloat(filtered.y),
                      width: CGFloat(filtered.z),
                      height: CGFloat(filtered.w))
    }

    /// 重置缓存矩形，可选给定初始值。
    mutating func reset(to rect: CGRect? = nil) {
        if let rect {
            previous = SIMD4<Double>(Double(rect.origin.x),
                                     Double(rect.origin.y),
                                     Double(rect.size.width),
                                     Double(rect.size.height))
        } else {
            previous = nil
        }
    }

    /// 将响应参数限制在有效区间。
    private static func clamped(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}
