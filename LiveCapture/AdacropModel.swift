//
//  AdacropModel.swift
//  LiveCapture
//

import Foundation
import Vision
import CoreML
import AVFoundation
import ImageIO

#if os(iOS)

struct CropBox {
    let rectInNormalizedImage: CGRect // origin at bottom-left in Vision coordinates
    let detectionType: String         // 用于调试，说明使用了哪种检测方法
}

final class UniformRectSmoother {
    private let response: CGFloat
    private var lastRect: CGRect?

    init(response: CGFloat) {
        self.response = response
        self.lastRect = nil
    }

    func filter(_ rect: CGRect) -> CGRect {
        guard let last = lastRect else {
            lastRect = rect
            return rect
        }
        let smoothed = CGRect(
            x: last.origin.x + response * (rect.origin.x - last.origin.x),
            y: last.origin.y + response * (rect.origin.y - last.origin.y),
            width: last.size.width + response * (rect.size.width - last.size.width),
            height: last.size.height + response * (rect.size.height - last.size.height)
        )
        lastRect = smoothed
        return smoothed
    }

    func reset() {
        lastRect = nil
    }
}

final class AdacropModel {
    private let handlerQueue = DispatchQueue(label: "livecapture.adacrop.queue")
    private var rectSmoother = UniformRectSmoother(response: 0.25)
    private var lastRawRect: CGRect? = nil

    init() {
        // 简化初始化，不再需要模型文件
    }

    func resetSmoothing() {
        handlerQueue.async {
            self.rectSmoother.reset()
            self.lastRawRect = nil
        }
    }

    func predictCropBox(pixelBuffer: CVPixelBuffer,
                        orientation: CGImagePropertyOrientation,
                        completion: @escaping (CropBox?) -> Void) {
        // orientation 用于保证 VNRequest 的坐标系与 UI 显示保持一致
        handlerQueue.async {
            let context = self.makeVisionContext(pixelBuffer: pixelBuffer, orientation: orientation)
            if let best = self.selectBestCandidate(in: context) {
                self.lastRawRect = best.rect
                let smoothed = self.rectSmoother.filter(best.rect)
                let detail = String(format: "美学%.2f-%@", Double(best.score), best.reason)
                completion(CropBox(rectInNormalizedImage: smoothed, detectionType: detail))
                return
            }
            let fallback = self.rectSmoother.filter(self.centerRect3x4())
            completion(CropBox(rectInNormalizedImage: fallback, detectionType: "默认中心(3:4)"))
        }
    }
    
    private struct WeightedRect {
        let rect: CGRect
        let weight: CGFloat
    }

    private struct VisionContext {
        let faces: [WeightedRect]
        let humans: [WeightedRect]
        let saliencyRects: [WeightedRect]
        let saliencyObservation: VNSaliencyImageObservation?

        var hasDetections: Bool {
            !faces.isEmpty || !humans.isEmpty || !saliencyRects.isEmpty
        }
    }

    private struct Candidate {
        let rect: CGRect
        let reason: String
    }

    private struct EvaluatedCandidate {
        let rect: CGRect
        let reason: String
        let score: CGFloat
    }

    private func makeVisionContext(pixelBuffer: CVPixelBuffer,
                                   orientation: CGImagePropertyOrientation) -> VisionContext {
        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        do {
            try handler.perform([faceRequest, humanRequest, saliencyRequest])
        } catch {
            return VisionContext(faces: [], humans: [], saliencyRects: [], saliencyObservation: nil)
        }
        let faces = (faceRequest.results as? [VNFaceObservation]) ?? []
        let humans = (humanRequest.results as? [VNHumanObservation]) ?? []
        let saliencyObservation = saliencyRequest.results?.first as? VNSaliencyImageObservation
        let faceRects = faces.map { WeightedRect(rect: $0.boundingBox.standardized, weight: CGFloat($0.confidence)) }
        let humanRects = humans.map { WeightedRect(rect: $0.boundingBox.standardized, weight: CGFloat($0.confidence)) }
        let salientRects = (saliencyObservation?.salientObjects ?? []).map { WeightedRect(rect: $0.boundingBox.standardized, weight: CGFloat($0.confidence)) }
        return VisionContext(faces: faceRects,
                             humans: humanRects,
                             saliencyRects: salientRects,
                             saliencyObservation: saliencyObservation)
    }

    private func selectBestCandidate(in context: VisionContext) -> EvaluatedCandidate? {
        let candidates = generateCandidates(for: context)
        guard !candidates.isEmpty else { return nil }
        var best: EvaluatedCandidate? = nil
        for candidate in candidates {
            let rect = candidate.rect
            let subject = subjectScore(for: rect, context: context)
            let saliency = saliencyScore(for: rect, context: context)
            let thirds = thirdsFit(of: rect)
            let breathing = breathingScore(of: rect)
            let continuity = continuityScore(for: rect)
            let score = 0.45 * subject + 0.3 * saliency + 0.15 * thirds + 0.05 * breathing + 0.05 * continuity
            if let current = best {
                if score > current.score {
                    best = EvaluatedCandidate(rect: rect, reason: candidate.reason, score: score)
                }
            } else {
                best = EvaluatedCandidate(rect: rect, reason: candidate.reason, score: score)
            }
        }
        return best
    }

    private func generateCandidates(for context: VisionContext) -> [Candidate] {
        var seeds: [(CGRect, String)] = []

        for (index, face) in context.faces.enumerated() {
            let expanded = expandNormalized(face.rect, margin: 0.18)
            seeds.append((expanded, "人脸#\(index + 1)"))
        }
        if let facesUnion = unionRect(context.faces.map { $0.rect }) {
            seeds.append((expandNormalized(facesUnion, margin: 0.12), "人脸集合"))
        }

        for (index, human) in context.humans.enumerated() {
            let expanded = expandNormalized(human.rect, margin: 0.14)
            seeds.append((expanded, "人体#\(index + 1)"))
        }
        if let humansUnion = unionRect(context.humans.map { $0.rect }) {
            seeds.append((expandNormalized(humansUnion, margin: 0.10), "人体集合"))
        }

        if !context.saliencyRects.isEmpty {
            for (index, sal) in context.saliencyRects.enumerated() {
                let expanded = expandNormalized(sal.rect, margin: 0.08)
                seeds.append((expanded, "显著性#\(index + 1)"))
            }
            if let saliencyUnion = unionRect(context.saliencyRects.map { $0.rect }) {
                seeds.append((expandNormalized(saliencyUnion, margin: 0.06), "显著性集合"))
            }
        }

        if let last = lastRawRect {
            seeds.append((expandNormalized(last, margin: 0.04), "历史延续"))
        }

        if seeds.isEmpty {
            seeds.append((CGRect(x: 0.2, y: 0.1, width: 0.6, height: 0.7), "默认种子"))
        }

        let thirdsPoints = [CGPoint(x: 1.0/3.0, y: 1.0/3.0),
                            CGPoint(x: 2.0/3.0, y: 1.0/3.0),
                            CGPoint(x: 1.0/3.0, y: 2.0/3.0),
                            CGPoint(x: 2.0/3.0, y: 2.0/3.0)]
        var result: [Candidate] = []
        var dedupe = Set<String>()

        func appendCandidate(_ rect: CGRect, reason: String) {
            let key = [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
                .map { Int(round($0 * 1000)) }
                .map(String.init)
                .joined(separator: ":")
            if dedupe.insert(key).inserted {
                result.append(Candidate(rect: rect, reason: reason))
            }
        }

        for (seedRect, seedReason) in seeds {
            let base = expandToAspect3x4(covering: seedRect)
            appendCandidate(base, reason: seedReason)
            for point in thirdsPoints {
                let moved = moveRect(base, centerToward: point, maxShift: 0.07)
                appendCandidate(moved, reason: seedReason + "+三分漂移")
            }
            for scale in [0.92, 0.98, 1.0, 1.04] as [CGFloat] {
                let scaled = scaleRect(base, scale: scale)
                appendCandidate(scaled, reason: seedReason + String(format: "+scale%.2f", Double(scale)))
            }
        }

        appendCandidate(centerRect3x4(), reason: "中心参考")

        return result
    }

    private func subjectScore(for rect: CGRect, context: VisionContext) -> CGFloat {
        let faceScore = weightedCoverage(of: rect, with: context.faces)
        let humanScore = weightedCoverage(of: rect, with: context.humans)
        if faceScore == 0 && humanScore == 0 {
            return context.saliencyRects.isEmpty ? 0 : 0.15
        }
        let combined = max(faceScore, humanScore)
        let secondary = min(faceScore, humanScore)
        return min(1.0, combined + 0.4 * secondary)
    }

    private func saliencyScore(for rect: CGRect, context: VisionContext) -> CGFloat {
        if context.saliencyRects.isEmpty {
            return context.hasDetections ? 0.35 : 0.5
        }
        return min(1.0, weightedCoverage(of: rect, with: context.saliencyRects))
    }

    private func breathingScore(of rect: CGRect) -> CGFloat {
        let left = rect.minX
        let right = 1.0 - rect.maxX
        let bottom = rect.minY
        let top = 1.0 - rect.maxY
        let minMargin = max(0, min(left, right, bottom, top))
        return min(1.0, minMargin / 0.12)
    }

    private func continuityScore(for rect: CGRect) -> CGFloat {
        guard let previous = lastRawRect else { return 0.6 }
        let deltaCenter = hypot(rect.midX - previous.midX, rect.midY - previous.midY)
        let deltaSize = hypot(rect.width - previous.width, rect.height - previous.height)
        let centerScore = max(0, 1.0 - deltaCenter / 0.3)
        let sizeScore = max(0, 1.0 - deltaSize / 0.3)
        return 0.5 * (centerScore + sizeScore)
    }

    private func weightedCoverage(of rect: CGRect, with items: [WeightedRect]) -> CGFloat {
        guard !items.isEmpty else { return 0 }
        let rectArea = rect.width * rect.height
        guard rectArea > 0 else { return 0 }
        var sum: CGFloat = 0
        for item in items {
            let inter = rect.intersection(item.rect)
            if inter.isNull || inter.isEmpty { continue }
            let coverage = (inter.width * inter.height) / rectArea
            sum += coverage * item.weight
        }
        return min(1.0, sum)
    }

    private func expandNormalized(_ rect: CGRect, margin: CGFloat) -> CGRect {
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        let expandX = rect.width * margin
        let expandY = rect.height * margin
        var expanded = CGRect(x: rect.origin.x - expandX,
                              y: rect.origin.y - expandY,
                              width: rect.width + expandX * 2,
                              height: rect.height + expandY * 2)
        expanded = expanded.standardized
        expanded = expanded.intersection(unit)
        if expanded.isNull {
            return unit
        }
        return expanded
    }

    private func unionRect(_ rects: [CGRect]) -> CGRect? {
        guard var union = rects.first else { return nil }
        for rect in rects.dropFirst() {
            union = union.union(rect)
        }
        return union.standardized
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

#endif