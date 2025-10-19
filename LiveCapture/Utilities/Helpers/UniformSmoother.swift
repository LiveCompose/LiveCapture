//
//  UniformSmoother.swift
//  LiveCapture
//
//  统一响应平滑器
//
//  ## 文件作用
//  提供可复用的低通滤波器用于平滑数据
//  统一各种UI元素的时间响应特性
//  减少抖动和突变，提供流畅的视觉体验
//
//  ## 主要类型
//
//  ### UniformRectSmoother 结构体
//  矩形平滑器
//
//  用途:
//  - 平滑检测框位置和大小变化
//  - 减少矩形抖动
//
//  属性:
//  - response: Double - 响应系数 [0,1]
//    - 0: 完全不响应（静止）
//    - 1: 立即响应（无平滑）
//    - 0.2-0.3: 推荐值（平衡）
//
//  方法:
//  - init(response:): 初始化平滑器
//    参数: response - Double 响应系数
//
//  - filter(_:): 对输入矩形执行平滑
//    参数: rect - CGRect 输入矩形
//    返回: CGRect 平滑后的矩形
//    算法: 指数加权移动平均（EWMA）
//      filtered = mix(previous, current, response)
//
//  - reset(to:): 重置内部状态
//    参数: rect - CGRect? 可选初始值
//
//  内部实现:
//  - 使用 SIMD4<Double> 存储 (x, y, width, height)
//  - 使用 simd_mix 高效计算插值
//
//  ## 滤波算法
//  指数平滑（Exponential Smoothing）:
//  ```
//  y[n] = α * x[n] + (1 - α) * y[n-1]
//  ```
//  其中 α = response
//
//  特性:
//  - 一阶低通滤波器
//  - 减少高频噪声
//  - 引入延迟（response 越小延迟越大）
//  - 简单高效
//
//  ## 使用示例
//  ```swift
//  var smoother = UniformRectSmoother(response: 0.25)
//  
//  func updateRect(_ newRect: CGRect) {
//      let smoothed = smoother.filter(newRect)
//      // 使用 smoothed 更新 UI
//  }
//  ```
//
//  ## 参数调优
//  - response = 0.1: 非常平滑，明显延迟
//  - response = 0.2-0.3: 平衡，推荐值
//  - response = 0.5: 快速响应，轻微平滑
//  - response = 1.0: 无平滑，直接跟随
//
//  ## 性能
//  - 使用 SIMD 向量化计算
//  - O(1) 时间复杂度
//  - 内存占用极小
//  - 适合实时应用
//

import Foundation
import CoreGraphics
import simd

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
