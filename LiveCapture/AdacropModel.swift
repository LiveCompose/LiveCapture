//
//  AdacropModel.swift
//  LiveCapture
//

import Foundation
import Vision
import CoreML
import AVFoundation
import ImageIO

struct CropBox {
    let rectInNormalizedImage: CGRect // origin at bottom-left in Vision coordinates
    let detectionType: String         // 用于调试，说明使用了哪种检测方法
}

final class AdacropModel {
    private let handlerQueue = DispatchQueue(label: "livecapture.adacrop.queue")

    init() {
        // 简化初始化，不再需要模型文件
    }

    func predictCropBox(pixelBuffer: CVPixelBuffer,
                        orientation: CGImagePropertyOrientation,
                        completion: @escaping (CropBox?) -> Void) {
        // orientation 用于保证 VNRequest 的坐标系与 UI 显示保持一致
        handlerQueue.async {
            if let faceRect = self.findLargestFaceRect(in: pixelBuffer, orientation: orientation) {
                let rect3x4 = self.expandToAspect3x4(covering: faceRect)
                completion(CropBox(rectInNormalizedImage: rect3x4, detectionType: "人脸优先(3:4)"))
                return
            }
            if let saliency = self.generateAttentionSaliency(in: pixelBuffer, orientation: orientation) {
                let rect3x4 = self.bestRectFromSaliency3x4(saliency)
                completion(CropBox(rectInNormalizedImage: rect3x4, detectionType: "显著性(3:4)"))
                return
            }
            // 回退：居中 3:4 框
            let fallback = self.centerRect3x4()
            completion(CropBox(rectInNormalizedImage: fallback, detectionType: "默认中心(3:4)"))
        }
    }
    
    // MARK: - Face first
    private func findLargestFaceRect(in pixelBuffer: CVPixelBuffer,
                                     orientation: CGImagePropertyOrientation) -> CGRect? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation) // 保持与外部裁剪后的图像方向一致
        do {
            try handler.perform([request])
            if let faces = request.results, !faces.isEmpty {
                let best = faces.max { a, b in a.boundingBox.size.width * a.boundingBox.size.height < b.boundingBox.size.width * b.boundingBox.size.height }
                // 适度扩展，保持在[0,1]
                if let bb = best?.boundingBox {
                    let margin: CGFloat = 0.08
                    let expanded = CGRect(
                        x: max(0, bb.origin.x - bb.size.width * margin),
                        y: max(0, bb.origin.y - bb.size.height * margin),
                        width: min(1 - bb.origin.x, bb.size.width * (1 + 2*margin)),
                        height: min(1 - bb.origin.y, bb.size.height * (1 + 2*margin))
                    )
                    return expanded
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    // MARK: - Saliency
    private func generateAttentionSaliency(in pixelBuffer: CVPixelBuffer,
                                           orientation: CGImagePropertyOrientation) -> VNSaliencyImageObservation? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation) // 显著性检测同样需要正确的方向信息
        do {
            try handler.perform([request])
            return request.results?.first as? VNSaliencyImageObservation
        } catch {
            return nil
        }
    }

    private func bestRectFromSaliency3x4(_ saliency: VNSaliencyImageObservation) -> CGRect {
        // 聚合显著性区域
        let salientRects: [CGRect]
        if let objects = saliency.salientObjects, !objects.isEmpty {
            salientRects = objects.map { $0.boundingBox }
        } else {
            salientRects = [CGRect(x: 0, y: 0, width: 1, height: 1)]
        }
        let unionRect = salientRects.reduce(CGRect.null) { $0.union($1) }.standardized
        let base = expandToAspect3x4(covering: unionRect)
        // 生成候选：围绕规则三分交点微移
        let thirdsXs: [CGFloat] = [1/3, 2/3]
        let thirdsYs: [CGFloat] = [1/3, 2/3]
        var candidates: [CGRect] = [base]
        let baseSideMove: CGFloat = 0.05
        for tx in thirdsXs { for ty in thirdsYs {
            let c = CGPoint(x: tx, y: ty)
            let moved = moveRect(base, centerToward: c, maxShift: baseSideMove)
            candidates.append(moved)
        }}
        // 多尺度轻微变化
        for scale in [0.9, 1.0, 1.1] as [CGFloat] {
            candidates.append(scaleRect(base, scale: scale))
        }
        // 评分：0.7 覆盖显著性 + 0.3 三分贴合
        func score(_ r: CGRect) -> CGFloat {
            let cover = coverage(of: r, over: unionRect)
            let thirdsScore = thirdsFit(of: r)
            return 0.7 * cover + 0.3 * thirdsScore
        }
        let best = candidates.max { score($0) < score($1) } ?? base
        return best
    }

    // MARK: - Geometry helpers (normalized [0,1], origin bottom-left)
    private func expandToAspect3x4(covering rect: CGRect) -> CGRect {
        let aspectW: CGFloat = 3
        let aspectH: CGFloat = 4
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        let cx = rect.midX
        let cy = rect.midY
        var width = rect.width
        var height = rect.height
        let currentAspect = width / height
        if currentAspect > aspectW / aspectH {
            // too wide, increase height
            height = width * aspectH / aspectW
        } else {
            // too tall, increase width
            width = height * aspectW / aspectH
        }
        var out = CGRect(x: cx - width/2, y: cy - height/2, width: width, height: height)
        // 若溢出，整体平移裁剪；若仍溢出，按比例缩小以适配
        out = clampToUnit(out, inside: unit)
        if !unit.contains(out) {
            let scale = min(unit.width / out.width, unit.height / out.height)
            let newSize = CGSize(width: out.width * scale, height: out.height * scale)
            out = CGRect(x: cx - newSize.width/2, y: cy - newSize.height/2, width: newSize.width, height: newSize.height)
            out = clampToUnit(out, inside: unit)
        }
        return out
    }

    private func clampToUnit(_ r: CGRect, inside unit: CGRect) -> CGRect {
        var out = r
        if out.minX < unit.minX { out.origin.x = unit.minX }
        if out.minY < unit.minY { out.origin.y = unit.minY }
        if out.maxX > unit.maxX { out.origin.x = unit.maxX - out.width }
        if out.maxY > unit.maxY { out.origin.y = unit.maxY - out.height }
        return out
    }

    private func moveRect(_ r: CGRect, centerToward target: CGPoint, maxShift: CGFloat) -> CGRect {
        let cx = r.midX
        let cy = r.midY
        let dx = (target.x - cx)
        let dy = (target.y - cy)
        let len = max(1e-6, sqrt(dx*dx + dy*dy))
        let ux = dx / len
        let uy = dy / len
        let shift = min(maxShift, len)
        var moved = r.offsetBy(dx: ux * shift, dy: uy * shift)
        moved = clampToUnit(moved, inside: CGRect(x: 0, y: 0, width: 1, height: 1))
        return moved
    }

    private func scaleRect(_ r: CGRect, scale: CGFloat) -> CGRect {
        let cx = r.midX
        let cy = r.midY
        let w = r.width * scale
        let h = r.height * scale
        var out = CGRect(x: cx - w/2, y: cy - h/2, width: w, height: h)
        // 保持 3:4，不裁断；若超界则回缩
        out = clampToUnit(out, inside: CGRect(x: 0, y: 0, width: 1, height: 1))
        return out
    }

    private func coverage(of a: CGRect, over b: CGRect) -> CGFloat {
        let inter = a.intersection(b)
        if inter.isNull || inter.isEmpty { return 0 }
        return inter.width * inter.height / max(1e-6, b.width * b.height)
    }

    private func thirdsFit(of r: CGRect) -> CGFloat {
        let center = CGPoint(x: r.midX, y: r.midY)
        let points = [CGPoint(x: 1/3, y: 1/3), CGPoint(x: 2/3, y: 1/3), CGPoint(x: 1/3, y: 2/3), CGPoint(x: 2/3, y: 2/3)]
        let dists = points.map { hypot(center.x - $0.x, center.y - $0.y) }
        let minDist = dists.min() ?? 1
        // 归一化：0 距离 -> 1 分数，最大考虑距离 ~0.5
        let score = max(0, 1 - minDist / 0.5)
        return score
    }

    private func centerRect3x4() -> CGRect {
        let w: CGFloat = 0.6
        let h: CGFloat = w * 4.0 / 3.0
        return CGRect(x: 0.5 - w/2, y: 0.5 - h/2, width: w, height: h)
    }
}
