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
    case student
    case teacher

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vision: return "Vision"
        case .student: return "Student"
        case .teacher: return "Teacher"
        }
    }
}
