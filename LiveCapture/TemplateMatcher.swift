//
//  TemplateMatcher.swift
//  LiveCapture
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// 使用模板匹配衡量构图对齐情况的辅助类。
final class TemplateMatcher {
    private let context: CIContext = CIContext()
    private let queue: DispatchQueue = DispatchQueue(label: "livecapture.template.queue")

    // Template as normalized float vector
    private var templateVector: [Float]? = nil
    private var targetSize: Int = 64 // template width and height (square)
    private var matchScale: CGFloat = 0.3 // shared side proportion for template and probe squares

    // Cache for debug preview
    private var lastTemplateCGImage: CGImage? = nil

    // Public config
    // 模板方块和探测方块共用的边长比例（相对 3:4 矩形 min(width,height)）——只影响尺寸，不改变中心逻辑
    var templateScaleInRegion: CGFloat {
        get { matchScale }
        set { matchScale = newValue }
    }
    var probeScaleInComp: CGFloat {
        get { matchScale }
        set { matchScale = newValue }
    }

    /// 是否已生成模板向量，可作为匹配前置条件。
    var hasTemplate: Bool { queue.sync { templateVector != nil } }

    /// 清除模板缓存与调试图像。
    func resetTemplate() {
        queue.async {
            self.templateVector = nil
            self.lastTemplateCGImage = nil
        }
    }

    // Convenience wrapper
    /// 同步生成模板的便捷入口。
    func setTemplate(from pixelBuffer: CVPixelBuffer, normalizedRegion: CGRect) {
        setTemplate(from: pixelBuffer, normalizedRegion: normalizedRegion, completion: nil)
    }

    // Completion-capable setup; completion invoked on main queue
    /// 异步提取模板方块并转换为向量，完成后回调主线程。
    func setTemplate(from pixelBuffer: CVPixelBuffer, normalizedRegion: CGRect, completion: ((Bool) -> Void)?) {
        queue.async {
            let side = self.matchSquareSide(in: pixelBuffer)
            let crop = self.centerSquare(in: normalizedRegion, pixelBuffer: pixelBuffer, side: side)
            guard let cg = self.extractCGImage(from: pixelBuffer, cropping: crop),
                  let vec = self.imageToVector(cg) else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            self.lastTemplateCGImage = cg
            self.templateVector = self.normalizeVector(vec)
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // Returns similarity in [0, 1] using cosine similarity mapped from [-1,1] to [0,1]
    /// 计算模板与当前帧中心区域的相似度，范围 [0,1]。
    func similarityWithCenter(of pixelBuffer: CVPixelBuffer) -> Float? {
        queue.sync {
            guard let tpl: [Float] = self.templateVector else { return nil }
            // Center square of whole frame using same physical scale as template center logic
            let centerRect = self.centerSquareInFullFrame(pixelBuffer: pixelBuffer)
            guard let cg = self.extractCGImage(from: pixelBuffer, cropping: centerRect),
                  let vec = self.imageToVector(cg) else { return nil }
            let probe = self.normalizeVector(vec)
            let sim = self.cosineSimilarity(tpl, probe)
            // map from [-1,1] -> [0,1]
            return max(0, min(1, (sim + 1.0) * 0.5))
        }
    }

    // MARK: - Debug preview helpers
    /// 获取缓存的模板 CGImage，用于调试展示。
    func templateCGImage() -> CGImage? {
        queue.sync { lastTemplateCGImage }
    }

    /// 裁剪当前帧中心方块的 CGImage。
    func centerCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        queue.sync {
            let rect = self.centerSquareInFullFrame(pixelBuffer: pixelBuffer)
            return self.extractCGImage(from: pixelBuffer, cropping: rect)
        }
    }

    #if canImport(UIKit)
    /// 以 UIImage 形式返回模板调试视图。
    func templateUIImage() -> UIImage? {
        guard let cg = templateCGImage() else { return nil }
        return UIImage(cgImage: cg)
    }

    /// 返回当前帧中心区域的 UIImage，用于调试。
    func centerUIImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        guard let cg = centerCGImage(from: pixelBuffer) else { return nil }
        return UIImage(cgImage: cg)
    }
    #endif

    // MARK: - Helpers

    /// 获取像素空间中居中的 3:4 构图区域。
    private func compositionRect3x4InPixels(pixelBuffer: CVPixelBuffer) -> CGRect {
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
    let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        // Fit 3:4 inside the full pixel buffer (portrait composition)
        // width:height = 3:4 => width = height * 0.75
        let targetWidth = min(width, height * 0.75)
        let targetHeight = targetWidth * 4.0 / 3.0
        let originX = (width - targetWidth) / 2.0
        let originY = (height - targetHeight) / 2.0
        return CGRect(x: originX, y: originY, width: targetWidth, height: targetHeight)
    }

    /// 将归一化区域映射到像素空间并约束在 3:4 构图内。
    private func centerSquare(in normalizedRegion: CGRect, pixelBuffer: CVPixelBuffer, side: CGFloat) -> CGRect {
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
    let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        // Vision normalized (origin bottom-left) -> pixel coords (origin top-left for our crop)
        let px = normalizedRegion.origin.x * width
        let pyTopLeft = (1.0 - normalizedRegion.origin.y - normalizedRegion.size.height) * height
        let pw = normalizedRegion.size.width * width
        let ph = normalizedRegion.size.height * height
        let rect = CGRect(x: px, y: pyTopLeft, width: pw, height: ph)

        // Constrain to 3:4 composition rect to match still photo FOV
        let comp = compositionRect3x4InPixels(pixelBuffer: pixelBuffer)
        let targetRect = rect.intersection(comp).isNull ? comp : rect.intersection(comp)
        let halfSide = side / 2.0
        let clampedCx = min(max(targetRect.midX, comp.minX + halfSide), comp.maxX - halfSide)
        let clampedCy = min(max(targetRect.midY, comp.minY + halfSide), comp.maxY - halfSide)
        return CGRect(x: clampedCx - halfSide, y: clampedCy - halfSide, width: side, height: side)
    }

    /// 计算整帧中心的正方形区域，用于探测窗口。
    private func centerSquareInFullFrame(pixelBuffer: CVPixelBuffer) -> CGRect {
        // Use center inside 3:4 composition rect to match still photo field of view
        let comp = compositionRect3x4InPixels(pixelBuffer: pixelBuffer)
        let side = matchSquareSide(in: pixelBuffer)
        let square = CGRect(x: comp.midX - side/2, y: comp.midY - side/2, width: side, height: side)
        return square
    }

    /// 根据构图窗口尺寸与比例确定模板边长。
    private func matchSquareSide(in pixelBuffer: CVPixelBuffer) -> CGFloat {
        let comp = compositionRect3x4InPixels(pixelBuffer: pixelBuffer)
        let sideRatio = max(0.02, min(0.9, matchScale))
        return min(comp.width, comp.height) * sideRatio
    }

    /// 裁剪并缩放像素缓冲中的区域为固定大小 CGImage。
    private func extractCGImage(from pixelBuffer: CVPixelBuffer, cropping cropRect: CGRect) -> CGImage? {
        let imgH = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // Convert top-left origin pixel rect to Core Image bottom-left origin
        let ciCrop = CGRect(
            x: cropRect.origin.x,
            y: imgH - cropRect.origin.y - cropRect.height,
            width: cropRect.width,
            height: cropRect.height
        )
        guard let src = context.createCGImage(ciImage, from: ciCrop) else { return nil }
        // Scale to targetSize x targetSize using CoreGraphics for deterministic sizing
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = targetSize * 4
        guard let ctx = CGContext(data: nil,
                                  width: targetSize,
                                  height: targetSize,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .none
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))
        return ctx.makeImage()
    }

    /// 将灰度化后的图像像素转换为浮点向量。
    private func imageToVector(_ image: CGImage) -> [Float]? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let ctx = CGContext(data: &data,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var vec = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Float(data[offset + 0])
                let g = Float(data[offset + 1])
                let b = Float(data[offset + 2])
                // Luma approximation
                let luma = 0.299 * r + 0.587 * g + 0.114 * b
                vec[y * width + x] = Float(luma) / 255.0
            }
        }
        return vec
    }

    /// 对向量执行零均值单位方差的归一化。
    private func normalizeVector(_ v: [Float]) -> [Float] {
        let n = v.count
        guard n > 0 else { return v }
        let mean = v.reduce(0, +) / Float(n)
        var centered = v.map { $0 - mean }
        let variance = centered.reduce(0) { $0 + $1*$1 } / Float(n)
        let std = max(1e-6, sqrt(variance))
        for i in 0..<n { centered[i] /= std }
        return centered
    }

    /// 计算两个向量的余弦相似度。
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var na: Float = 0
        var nb: Float = 0
        for i in 0..<a.count {
            let va = a[i]
            let vb = b[i]
            dot += va * vb
            na += va * va
            nb += vb * vb
        }
        let denom = max(1e-6, sqrt(na) * sqrt(nb))
        return dot / denom
    }
}
