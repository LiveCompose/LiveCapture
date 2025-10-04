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

struct UniformPointSmoother {
    private let response: Double
    private var previous: SIMD2<Double>?

    init(response: Double) {
        self.response = UniformPointSmoother.clamped(response)
    }

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

    mutating func reset(to point: CGPoint? = nil) {
        if let point {
            previous = SIMD2<Double>(Double(point.x), Double(point.y))
        } else {
            previous = nil
        }
    }

    private static func clamped(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}

struct UniformRectSmoother {
    private let response: Double
    private var previous: SIMD4<Double>?

    init(response: Double) {
        self.response = UniformRectSmoother.clamped(response)
    }

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

    private static func clamped(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}
