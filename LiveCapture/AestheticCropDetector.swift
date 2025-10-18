//
//  AestheticCropDetector.swift
//  LiveCapture
//
//  基于 Vision 框架的美学裁切检测器

import Foundation
import Vision
import AVFoundation
import CoreGraphics

#if os(iOS)

/// 美学裁切结果
struct AestheticCrop {
	let rect: CGRect           // 归一化坐标 [0,1]
	let confidence: Float      // 置信度
	let detectionType: String  // 检测类型描述
}

/// 基于 Vision 的美学裁切检测器
final class AestheticCropDetector {
	private let queue = DispatchQueue(label: "livecapture.aesthetic.queue")
	
	/// 检测最佳裁切区域
	/// - Parameters:
	///   - pixelBuffer: 输入图像
	///   - orientation: 图像方向
	///   - targetAspectRatio: 目标宽高比 (width/height)
	///   - completion: 完成回调
	func detectBestCrop(
		in pixelBuffer: CVPixelBuffer,
		orientation: CGImagePropertyOrientation,
		targetAspectRatio: CGFloat,
		completion: @escaping (AestheticCrop?) -> Void
	) {
		queue.async {
			// 执行 Vision 检测
			let detections = self.performVisionDetection(
				pixelBuffer: pixelBuffer,
				orientation: orientation
			)
			
			// 生成候选裁切框
			let candidates = self.generateCandidates(
				from: detections,
				targetAspectRatio: targetAspectRatio
			)
			
			// 评分并选择最佳候选
			if let best = self.selectBestCandidate(candidates, detections: detections) {
				completion(best)
			} else {
				// 返回默认中心裁切
				let centerCrop = self.createCenterCrop(aspectRatio: targetAspectRatio)
				completion(centerCrop)
			}
		}
	}
	
	// MARK: - Vision 检测
	
	private struct VisionDetections {
		let faces: [VNFaceObservation]
		let bodies: [VNHumanObservation]
		let saliency: VNSaliencyImageObservation?
	}
	
	private func performVisionDetection(
		pixelBuffer: CVPixelBuffer,
		orientation: CGImagePropertyOrientation
	) -> VisionDetections {
		let faceRequest = VNDetectFaceRectanglesRequest()
		let bodyRequest = VNDetectHumanRectanglesRequest()
		let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
		
		let handler = VNImageRequestHandler(
			cvPixelBuffer: pixelBuffer,
			orientation: orientation,
			options: [:]
		)
		
		try? handler.perform([faceRequest, bodyRequest, saliencyRequest])
		
		let faces = faceRequest.results ?? []
		let bodies = bodyRequest.results ?? []
		let saliency = saliencyRequest.results?.first
		
		return VisionDetections(faces: faces, bodies: bodies, saliency: saliency)
	}
	
	// MARK: - 候选生成
	
	private func generateCandidates(
		from detections: VisionDetections,
		targetAspectRatio: CGFloat
	) -> [AestheticCrop] {
		var candidates: [AestheticCrop] = []
		
		// 1. 基于人脸的候选
		for (index, face) in detections.faces.enumerated() {
			let expandedRect = expandRect(face.boundingBox, by: 0.3)
			let cropRect = fitToAspectRatio(expandedRect, target: targetAspectRatio)
			candidates.append(AestheticCrop(
				rect: cropRect,
				confidence: face.confidence,
				detectionType: "人脸#\(index + 1)"
			))
		}
		
		// 2. 基于人体姿态的候选
		for (index, body) in detections.bodies.enumerated() {
			let expandedRect = expandRect(body.boundingBox, by: 0.2)
			let cropRect = fitToAspectRatio(expandedRect, target: targetAspectRatio)
			candidates.append(AestheticCrop(
				rect: cropRect,
				confidence: body.confidence,
				detectionType: "人体#\(index + 1)"
			))
		}
		
		// 3. 基于显著性的候选
		if let saliency = detections.saliency,
		   let salientObjects = saliency.salientObjects, !salientObjects.isEmpty {
			for (index, obj) in salientObjects.enumerated() {
				let expandedRect = expandRect(obj.boundingBox, by: 0.15)
				let cropRect = fitToAspectRatio(expandedRect, target: targetAspectRatio)
				candidates.append(AestheticCrop(
					rect: cropRect,
					confidence: Float(saliency.confidence),
					detectionType: "显著性#\(index + 1)"
				))
			}
		}
		
		return candidates
	}
	
	// MARK: - 候选评分与选择
	
	private func selectBestCandidate(
		_ candidates: [AestheticCrop],
		detections: VisionDetections
	) -> AestheticCrop? {
		guard !candidates.isEmpty else { return nil }
		
		// 评分各个候选
		let scored = candidates.map { candidate -> (crop: AestheticCrop, score: Float) in
			var score: Float = 0.0
			
			// 1. 基础置信度 (40%)
			score += candidate.confidence * 0.4
			
			// 2. 人脸覆盖度 (30%)
			let faceCoverage = calculateCoverage(
				of: candidate.rect,
				for: detections.faces.map { $0.boundingBox }
			)
			score += faceCoverage * 0.3
			
			// 3. 三分法构图 (20%)
			let compositionScore = calculateCompositionScore(candidate.rect)
			score += compositionScore * 0.2
			
			// 4. 边缘距离 (10%) - 避免过于贴边
			let marginScore = calculateMarginScore(candidate.rect)
			score += marginScore * 0.1
			
			return (candidate, score)
		}
		
		// 返回得分最高的候选
		return scored.max(by: { $0.score < $1.score })?.crop
	}
	
	// MARK: - 辅助方法
	
	/// 扩展矩形
	private func expandRect(_ rect: CGRect, by factor: CGFloat) -> CGRect {
		let dx = rect.width * factor / 2
		let dy = rect.height * factor / 2
		return CGRect(
			x: max(0, rect.minX - dx),
			y: max(0, rect.minY - dy),
			width: min(1.0, rect.width + dx * 2),
			height: min(1.0, rect.height + dy * 2)
		).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
	}
	
	/// 将矩形调整为目标宽高比
	private func fitToAspectRatio(_ rect: CGRect, target: CGFloat) -> CGRect {
		let center = CGPoint(x: rect.midX, y: rect.midY)
		var width = rect.width
		var height = rect.height
		
		let currentRatio = width / height
		if currentRatio > target {
			// 太宽，增加高度
			height = width / target
		} else {
			// 太高，增加宽度
			width = height * target
		}
		
		// 居中并限制在 [0,1] 范围内
		var result = CGRect(
			x: center.x - width / 2,
			y: center.y - height / 2,
			width: width,
			height: height
		)
		
		// 如果超出边界，则缩小
		if result.minX < 0 { result.origin.x = 0 }
		if result.minY < 0 { result.origin.y = 0 }
		if result.maxX > 1 { result.origin.x = 1 - result.width }
		if result.maxY > 1 { result.origin.y = 1 - result.height }
		
		// 如果还是太大，按比例缩小
		if result.width > 1 || result.height > 1 {
			let scale = min(1.0 / result.width, 1.0 / result.height)
			result.size.width *= scale
			result.size.height *= scale
			result.origin.x = center.x - result.width / 2
			result.origin.y = center.y - result.height / 2
		}
		
		return result
	}
	
	/// 计算覆盖度
	private func calculateCoverage(of cropRect: CGRect, for targets: [CGRect]) -> Float {
		guard !targets.isEmpty else { return 0 }
		
		let cropArea = cropRect.width * cropRect.height
		guard cropArea > 0 else { return 0 }
		
		var totalCoverage: CGFloat = 0
		for target in targets {
			let intersection = cropRect.intersection(target)
			if !intersection.isNull {
				let intersectionArea = intersection.width * intersection.height
				totalCoverage += intersectionArea / cropArea
			}
		}
		
		return Float(min(1.0, totalCoverage))
	}
	
	/// 计算三分法构图得分
	private func calculateCompositionScore(_ rect: CGRect) -> Float {
		let center = CGPoint(x: rect.midX, y: rect.midY)
		
		// 三分点
		let thirdPoints = [
			CGPoint(x: 1.0/3.0, y: 1.0/3.0),
			CGPoint(x: 2.0/3.0, y: 1.0/3.0),
			CGPoint(x: 1.0/3.0, y: 2.0/3.0),
			CGPoint(x: 2.0/3.0, y: 2.0/3.0)
		]
		
		// 计算到最近三分点的距离
		let minDistance = thirdPoints.map { point in
			let dx = center.x - point.x
			let dy = center.y - point.y
			return sqrt(dx * dx + dy * dy)
		}.min() ?? 1.0
		
		// 距离越近得分越高
		return Float(max(0, 1.0 - minDistance / 0.5))
	}
	
	/// 计算边缘距离得分
	private func calculateMarginScore(_ rect: CGRect) -> Float {
		let margins = [
			rect.minX,           // 左边距
			rect.minY,           // 下边距
			1.0 - rect.maxX,     // 右边距
			1.0 - rect.maxY      // 上边距
		]
		
		let minMargin = margins.min() ?? 0
		// 边距大于 0.05 得满分，否则按比例
		return Float(min(1.0, minMargin / 0.05))
	}
	
	/// 创建默认中心裁切
	private func createCenterCrop(aspectRatio: CGFloat) -> AestheticCrop {
		let maxSize: CGFloat = 0.75
		var width: CGFloat
		var height: CGFloat
		
		if aspectRatio >= 1.0 {
			width = min(maxSize, maxSize * aspectRatio)
			height = width / aspectRatio
		} else {
			height = min(maxSize, maxSize / aspectRatio)
			width = height * aspectRatio
		}
		
		let rect = CGRect(
			x: 0.3 - width / 2,
			y: 0.3 - height / 2,
			width: width,
			height: height
		)
		
		return AestheticCrop(
			rect: rect,
			confidence: 0.5,
			detectionType: "默认中心"
		)
	}
}

#endif
