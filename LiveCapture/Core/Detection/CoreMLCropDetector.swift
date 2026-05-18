import Foundation
import CoreML
import AVFoundation
import CoreGraphics
import CoreImage
import Accelerate

#if os(iOS)

final class CoreMLCropDetector {
    private let mode: DetectionMode
    private let queue = DispatchQueue(label: "livecapture.coreml.queue", qos: .userInitiated)
    private let ciContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

    private enum ModelLoadError: Error {
        case modelNotFound
        case compilationFailed
    }

    init(mode: DetectionMode) {
        self.mode = mode
    }

    // MARK: - Model Loading

    private func loadBBoxModel() throws -> MLModel {
        let config = MLModelConfiguration()
        switch mode {
        case .student:
            return try AdacropStudentBBox(configuration: config).model
        case .teacher:
            return try AdacropTeacherBBox(configuration: config).model
        case .vision:
            throw ModelLoadError.modelNotFound
        }
    }

    private func loadActorModel() throws -> MLModel {
        let config = MLModelConfiguration()
        switch mode {
        case .student:
            return try AdacropStudentActor(configuration: config).model
        case .teacher:
            return try AdacropTeacherActor(configuration: config).model
        case .vision:
            throw ModelLoadError.modelNotFound
        }
    }

    // MARK: - Image Preprocessing

    private func pixelBufferToMLMultiArray(_ pixelBuffer: CVPixelBuffer) -> MLMultiArray? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let targetSize = 224

        // Render scaled version to intermediate buffer
        var outBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, targetSize, targetSize,
                                         kCVPixelFormatType_32BGRA, nil, &outBuffer)
        guard status == kCVReturnSuccess, let outBuffer else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scaleX = CGFloat(targetSize) / CGFloat(width)
        let scaleY = CGFloat(targetSize) / CGFloat(height)
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        let scaled = ciImage.transformed(by: transform)
        ciContext.render(scaled, to: outBuffer)

        // Create MLMultiArray [1, 3, 224, 224] float16
        guard let array = try? MLMultiArray(shape: [1, 3, NSNumber(value: targetSize), NSNumber(value: targetSize)],
                                            dataType: .float16) else { return nil }

        CVPixelBufferLockBaseAddress(outBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(outBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(outBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(outBuffer)
        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)

        let floatPtr = array.dataPointer.assumingMemoryBound(to: Float16.self)
        let stride = targetSize * targetSize

        for y in 0..<targetSize {
            for x in 0..<targetSize {
                let pixelOffset = y * bytesPerRow + x * 4
                let b = Float(ptr[pixelOffset]) / 255.0
                let g = Float(ptr[pixelOffset + 1]) / 255.0
                let r = Float(ptr[pixelOffset + 2]) / 255.0

                // CHW format
                floatPtr[0 * stride + y * targetSize + x] = Float16(r)
                floatPtr[1 * stride + y * targetSize + x] = Float16(g)
                floatPtr[2 * stride + y * targetSize + x] = Float16(b)
            }
        }

        return array
    }

    private func cropPixelBuffer(_ pixelBuffer: CVPixelBuffer, bbox: [Float]) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let imageWidth = ciImage.extent.width
        let imageHeight = ciImage.extent.height

        // bbox 为归一化的 [cx, cy, w, h]
        let cx = CGFloat(bbox[0]) * imageWidth
        let cy = CGFloat(bbox[1]) * imageHeight
        let bw = CGFloat(bbox[2]) * imageWidth
        let bh = CGFloat(bbox[3]) * imageHeight

        let cropRect = CGRect(x: cx - bw / 2, y: cy - bh / 2, width: bw, height: bh)
            .intersection(ciImage.extent)

        guard cropRect.width > 0, cropRect.height > 0 else { return nil }

        let cropped = ciImage.cropped(to: cropRect)

        var outBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 224, 224, kCVPixelFormatType_32BGRA, nil, &outBuffer)
        guard let outBuffer else { return nil }

        // Scale cropped region to 224x224
        let targetRect = CGRect(x: 0, y: 0, width: 224, height: 224)
        let scaleX = targetRect.width / cropRect.width
        let scaleY = targetRect.height / cropRect.height
        let scale = min(scaleX, scaleY)
        let scaledWidth = cropRect.width * scale
        let scaledHeight = cropRect.height * scale
        let centeredRect = CGRect(x: (224 - scaledWidth) / 2, y: (224 - scaledHeight) / 2,
                                  width: scaledWidth, height: scaledHeight)
        let transformed = cropped.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: centeredRect.origin.x, y: centeredRect.origin.y))

        ciContext.render(transformed, to: outBuffer)
        return outBuffer
    }

    // MARK: - Detection

    func detectBestCrop(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        targetAspectRatio: CGFloat,
        completion: @escaping (AestheticCrop?) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            do {
                let bboxModel = try self.loadBBoxModel()
                let actorModel = try self.loadActorModel()

                // Step 1: 预处理图像并运行 BBox 模型
                guard let inputArray = self.pixelBufferToMLMultiArray(pixelBuffer) else {
                    self.fallbackResult(targetAspectRatio: targetAspectRatio, completion: completion)
                    return
                }

                let bboxInput = try MLDictionaryFeatureProvider(dictionary: ["full_img": inputArray])
                let bboxOutput = try bboxModel.prediction(from: bboxInput)

                guard let bboxArray = bboxOutput.featureValue(for: "bbox")?.multiArrayValue else {
                    self.fallbackResult(targetAspectRatio: targetAspectRatio, completion: completion)
                    return
                }

                let bbox = (0..<4).map { Float(truncating: bboxArray[$0]) }

                // Step 2: 裁切并运行 Actor 模型
                guard let cropBuffer = self.cropPixelBuffer(pixelBuffer, bbox: bbox),
                      let cropArray = self.pixelBufferToMLMultiArray(cropBuffer) else {
                    self.fallbackResult(targetAspectRatio: targetAspectRatio, completion: completion)
                    return
                }

                guard let stateArray = try? MLMultiArray(shape: [1, 4], dataType: .float16) else {
                    self.fallbackResult(targetAspectRatio: targetAspectRatio, completion: completion)
                    return
                }
                for i in 0..<4 { stateArray[i] = NSNumber(value: bbox[i]) }

                let actorInput = try MLDictionaryFeatureProvider(dictionary: [
                    "crop_img": cropArray,
                    "state_workaround": stateArray
                ])
                let actorOutput = try actorModel.prediction(from: actorInput)

                guard let actionArray = actorOutput.featureValue(for: "action_probs")?.multiArrayValue else {
                    self.fallbackResult(targetAspectRatio: targetAspectRatio, completion: completion)
                    return
                }

                let actionProbs = (0..<7).map { Float(truncating: actionArray[$0]) }

                // Step 3: 选择最佳动作并映射到裁切调整
                guard let maxIndex = actionProbs.indices.max(by: { actionProbs[$0] < actionProbs[$1] }) else {
                    self.fallbackResult(targetAspectRatio: targetAspectRatio, completion: completion)
                    return
                }

                let refinedBBox = self.applyAction(maxIndex, to: bbox)
                let rect = self.bboxToCGRect(refinedBBox)

                // 调整到目标宽高比
                let finalRect = self.fitToAspectRatio(rect, target: targetAspectRatio)

                let detectionType = "Adacrop\(self.mode == .student ? "Student" : "Teacher")"
                completion(AestheticCrop(rect: finalRect, confidence: actionProbs[maxIndex], detectionType: detectionType))

            } catch {
                self.fallbackResult(targetAspectRatio: targetAspectRatio, completion: completion)
            }
        }
    }

    // MARK: - Action Mapping

    /// 将 7 个动作映射到 bbox 调整。
    /// 0: no-op, 1: left, 2: right, 3: up, 4: down, 5: zoom out, 6: zoom in
    private func applyAction(_ action: Int, to bbox: [Float]) -> [Float] {
        let step: Float = 0.05
        let zoomStep: Float = 0.08
        var result = bbox

        switch action {
        case 1: result[0] = max(0, bbox[0] - step)          // left
        case 2: result[0] = min(1, bbox[0] + step)          // right
        case 3: result[1] = max(0, bbox[1] - step)          // up
        case 4: result[1] = min(1, bbox[1] + step)          // down
        case 5:                                              // zoom out
            result[2] = min(1, bbox[2] + zoomStep)
            result[3] = min(1, bbox[3] + zoomStep)
        case 6:                                              // zoom in
            result[2] = max(0.1, bbox[2] - zoomStep)
            result[3] = max(0.1, bbox[3] - zoomStep)
        default: break                                       // no-op
        }

        return result
    }

    /// 将归一化 [cx, cy, w, h] bbox 转换为归一化 CGRect
    private func bboxToCGRect(_ bbox: [Float]) -> CGRect {
        let cx = CGFloat(bbox[0])
        let cy = CGFloat(bbox[1])
        let w = CGFloat(bbox[2])
        let h = CGFloat(bbox[3])
        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    /// 将矩形调整为目标宽高比
    private func fitToAspectRatio(_ rect: CGRect, target: CGFloat) -> CGRect {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var width = rect.width
        var height = rect.height

        let currentRatio = width / height
        if currentRatio > target {
            height = width / target
        } else {
            width = height * target
        }

        var result = CGRect(x: center.x - width / 2, y: center.y - height / 2,
                            width: width, height: height)
        result.origin.x = max(0, min(result.origin.x, 1 - result.width))
        result.origin.y = max(0, min(result.origin.y, 1 - result.height))

        if result.width > 1 || result.height > 1 {
            let scale = min(1.0 / result.width, 1.0 / result.height)
            result.size.width *= scale
            result.size.height *= scale
            result.origin.x = center.x - result.width / 2
            result.origin.y = center.y - result.height / 2
        }

        return result
    }

    /// 模型加载或推理失败时返回中心裁切
    private func fallbackResult(targetAspectRatio: CGFloat, completion: @escaping (AestheticCrop?) -> Void) {
        let maxSize: CGFloat = 0.75
        var width: CGFloat = maxSize
        var height: CGFloat = maxSize
        if targetAspectRatio >= 1 {
            height = width / targetAspectRatio
        } else {
            width = height * targetAspectRatio
        }
        let rect = CGRect(x: 0.5 - width / 2, y: 0.5 - height / 2, width: width, height: height)
        completion(AestheticCrop(rect: rect, confidence: 0.3, detectionType: "CoreML-回退"))
    }
}

// MARK: - CropDetectionStrategy

extension CoreMLCropDetector: CropDetectionStrategy {}

#endif
