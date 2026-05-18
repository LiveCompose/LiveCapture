import Foundation
import Vision
import AVFoundation
import CoreGraphics

/// 美学裁切检测协议，允许 Vision / CoreML 等多种后端共存。
protocol CropDetectionStrategy: AnyObject {
    func detectBestCrop(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        targetAspectRatio: CGFloat,
        completion: @escaping (AestheticCrop?) -> Void
    )
}

/// 检测模式
enum DetectionMode: String, CaseIterable, Identifiable {
    case vision
    case fast
    case pro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vision: return "None"
        case .fast:   return "Fast"
        case .pro:    return "Pro"
        }
    }

    var description: String {
        switch self {
        case .vision:
            return "使用 iPhone 原生框架进行人脸、人体和显著性检测，无额外模型"
        case .fast:
            return "使用轻量级 Adacrop Student 模型，在速度和精度之间取得平衡，适合日常拍摄。"
        case .pro:
            return "使用全量专业级 Adacrop Teacher 模型，提供最高精度的构图建议，适合专业场景。"
        }
    }
}
