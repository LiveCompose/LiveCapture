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

final class TemplateMatcher {
    private let context: CIContext = CIContext()
    private let queue: DispatchQueue = DispatchQueue(label: "livecapture.template.queue")

    // Template as normalized float vector
    private var templateVector: [Float]? = nil
    private var targetSize: Int = 64 // template width and height (square)

    // Cache for debug preview
    private var lastTemplateCGImage: CGImage? = nil

    // Public config
    // 模板方块（来自裁切框中心）的边长比例（相对裁切框 min(width,height)）——较大更稳健
    var templateScaleInRegion: CGFloat = 0.35
    // 探测方块（来自画面中心 3:4 区域）的边长比例（相对 3:4 矩形 min(width,height)）——较小更容易匹配
    var probeScaleInComp: CGFloat = 0.12

    var hasTemplate: Bool { queue.sync { templateVector != nil } }

    func resetTemplate() {
        queue.async {
            self.templateVector = nil
            self.lastTemplateCGImage = nil
        }
    }

    // Convenience wrapper
    func setTemplate(from pixelBuffer: CVPixelBuffer, normalizedRegion: CGRect) {
        setTemplate(from: pixelBuffer, normalizedRegion: normalizedRegion, completion: nil)
    }

    // Completion-capable setup; completion invoked on main queue
    func setTemplate(from pixelBuffer: CVPixelBuffer, normalizedRegion: CGRect, completion: ((Bool) -> Void)?) {
        queue.async {
            let crop = self.centerSquare(in: normalizedRegion, pixelBuffer: pixelBuffer, scale: self.templateScaleInRegion)
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
    func templateCGImage() -> CGImage? {
        queue.sync { lastTemplateCGImage }
    }

    func centerCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        queue.sync {
            let rect = self.centerSquareInFullFrame(pixelBuffer: pixelBuffer)
            return self.extractCGImage(from: pixelBuffer, cropping: rect)
        }
    }

    #if canImport(UIKit)
    func templateUIImage() -> UIImage? {
        guard let cg = templateCGImage() else { return nil }
        return UIImage(cgImage: cg)
    }

    func centerUIImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        guard let cg = centerCGImage(from: pixelBuffer) else { return nil }
        return UIImage(cgImage: cg)
    }
    #endif

    // MARK: - Helpers

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

    private func centerSquare(in normalizedRegion: CGRect, pixelBuffer: CVPixelBuffer, scale: CGFloat) -> CGRect {
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

        let side = min(targetRect.width, targetRect.height) * max(0.02, min(0.9, scale))
        let cx = min(max(targetRect.midX, comp.minX), comp.maxX)
        let cy = min(max(targetRect.midY, comp.minY), comp.maxY)
        var square = CGRect(x: cx - side/2, y: cy - side/2, width: side, height: side)
        square = square.intersection(comp)
        return square
    }

    private func centerSquareInFullFrame(pixelBuffer: CVPixelBuffer) -> CGRect {
        // Use center inside 3:4 composition rect to match still photo field of view
        let comp = compositionRect3x4InPixels(pixelBuffer: pixelBuffer)
        let side = min(comp.width, comp.height) * max(0.02, min(0.9, probeScaleInComp))
        let square = CGRect(x: comp.midX - side/2, y: comp.midY - side/2, width: side, height: side)
        return square
    }

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
